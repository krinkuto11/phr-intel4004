-- ----------------------------------------------------------
-- Intel 4001 ROM - Modelo SÍNCRONO
--
-- Descripción física:
--   La ROM 4001 es un chip EXTERNO al 4004. Se comunica a través
--   del bus D0-D3 bidireccional de 4 bits.
--
-- Protocolo de bus (ciclo de máquina de 8 T-states):
--   A1 (fase 00): CPU vuelca PC[11:8] al bus. ROM lee y latchea.
--   A2 (fase 01): CPU vuelca PC[7:4]  al bus. ROM lee y latchea.
--   A3 (fase 10): CPU vuelca PC[3:0]  al bus. ROM lee y latchea.
--                 cm_rom='1' activa este chip.
--   ─── flanco A3→M1: ROM decodifica dirección y registra dato ───
--   M1          : ROM pone nibble ALTO  data[7:4] en el bus.
--   M2          : ROM pone nibble BAJO  data[3:0] en el bus.
--   X1-X3       : Bus libre para ejecución.
--
-- Puertos:
--   clk     : reloj del sistema (clk_ph1 del 4004)
--   cm_rom  : chip select activo alto (desde el 4004 pin CM ROM)
--   fase    : fase del bus "00"=A1, "01"=A2, "10"=A3, "11"=M1/M2
--   bus_io  : bus bidireccional de 4 bits (D0-D3)
--
-- Nota: 'fase' se genera desde timing_and_control (fase_reloj).
--       Durante M1 la ROM determina el nibble alto; en M2 el bajo.
--       El CPU distingue M1 de M2 mediante load_ir_high/load_ir_low.
--
-- Programa de ejemplo: suma acumulativa con loop
--
--   Addr  Opcode  Mnemónico         Descripción
--   ────  ──────  ─────────         ───────────────────────────
--   000   D0      LDM  0            ACC ← 0
--   001   F1      CLC               carry ← 0
--   002   B0      XCH  R0           R0 ← 0  (contador)
--   003   D5      LDM  5            ACC ← 5
--   004   B2      XCH  R2           R2 ← 5  (límite)
--   005   D1      LDM  1            ACC ← 1
--   006   B4      XCH  R4           R4 ← 1  (incremento)
--   -- Bucle en 0x007
--   007   A4      LD   R4           ACC ← R4
--   008   60      INC  R0           R0 ← R0 + 1
--   009   A0      LD   R0           ACC ← R0
--   00A   92      SUB  R2           ACC ← ACC - R2
--   00B   1A      JCN  cond=A       salta si ACC != 0 (cond 1010)
--   00C   07        → 0x007         dirección del bucle
--   00D   F0      CLB               limpia ACC y carry
--   00E   40      JUN               salto incondicional
--   00F   00        → 0x000         vuelve al inicio
-- ----------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ROM is
    port (
        clk    : in    std_logic;
        cm_rom : in    std_logic;                      -- Chip select (activo alto)
        fase   : in    std_logic_vector(1 downto 0);   -- Fase del bus (desde T&C)
        bus_io : inout std_logic_vector(3 downto 0)    -- Bus D0-D3 bidireccional
    );
end ROM;

architecture Behavioral of ROM is

    type rom_t is array(0 to 4095) of std_logic_vector(7 downto 0);

    constant ROM_DATA : rom_t := (
        16#000# => x"D0",   -- LDM 0        ACC ← 0
        16#001# => x"F1",   -- CLC          carry ← 0
        16#002# => x"B0",   -- XCH R0       R0 ← 0
        16#003# => x"D5",   -- LDM 5        ACC ← 5
        16#004# => x"B2",   -- XCH R2       R2 ← 5 (límite)
        16#005# => x"D1",   -- LDM 1        ACC ← 1
        16#006# => x"B4",   -- XCH R4       R4 ← 1 (incremento)

        -- Bucle en 0x007
        16#007# => x"A4",   -- LD  R4       ACC ← R4
        16#008# => x"60",   -- INC R0       R0 ← R0 + 1
        16#009# => x"A0",   -- LD  R0       ACC ← R0
        16#00A# => x"92",   -- SUB R2       ACC ← ACC - R2
        16#00B# => x"1A",   -- JCN cond=A   salta si ACC != 0
        16#00C# => x"07",   --   → 0x007
        16#00D# => x"F0",   -- CLB          limpia ACC y carry
        16#00E# => x"40",   -- JUN
        16#00F# => x"00",   --   → 0x000    vuelve al inicio

        others  => x"00"    -- NOP (posiciones no usadas)
    );

    -- Registro interno de la dirección de 12 bits
    -- Latcheada nibble a nibble durante A1, A2, A3
    signal addr_reg  : std_logic_vector(11 downto 0) := (others => '0');

    -- Registro del byte de instrucción (latencia 1 ciclo desde A3→M1)
    signal data_reg  : std_logic_vector(7 downto 0) := (others => '0');

    -- Flag interno para saber si estamos en M1 o M2
    -- Se usa para serializar la salida en dos nibbles
    signal out_high  : std_logic := '0';  -- '1' → M1 (nibble alto)
    signal out_low   : std_logic := '0';  -- '1' → M2 (nibble bajo)

begin

    -- ----------------------------------------------------------
    -- Proceso síncrono: latcha dirección (A1-A3) y decodifica (A3→M1)
    -- ----------------------------------------------------------
    SYNC_ROM : process(clk)
    begin
        if rising_edge(clk) then
            out_high <= '0';
            out_low  <= '0';

            if cm_rom = '1' then
                case fase is
                    when "00" =>  -- A1: captura nibble alto de dirección
                        addr_reg(11 downto 8) <= bus_io;

                    when "01" =>  -- A2: captura nibble medio de dirección
                        addr_reg(7 downto 4) <= bus_io;

                    when "10" =>  -- A3: captura nibble bajo + decodifica
                        addr_reg(3 downto 0) <= bus_io;
                        -- En el flanco siguiente (A3→M1) el dato estará listo
                        data_reg <= ROM_DATA(
                            TO_INTEGER(unsigned(addr_reg(11 downto 4) & bus_io))
                        );
                        out_high <= '1';  -- El siguiente ciclo es M1

                    when "11" =>  -- M2 (fase se reutiliza para segundo nibble)
                        out_low  <= '1';

                    when others => null;
                end case;
            end if;
        end if;
    end process SYNC_ROM;

    -- ----------------------------------------------------------
    -- Salida triestado al bus D0-D3
    -- M1: nibble alto [7:4]
    -- M2: nibble bajo [3:0]
    -- Resto: alta impedancia
    -- ----------------------------------------------------------
    bus_io <= data_reg(7 downto 4) when out_high = '1' else
              data_reg(3 downto 0) when out_low  = '1' else
              (others => 'Z');

end Behavioral;
