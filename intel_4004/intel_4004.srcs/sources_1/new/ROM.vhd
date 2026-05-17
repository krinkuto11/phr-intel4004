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
-- Programa de validación lineal (sin saltos).
-- Ejercita cada instrucción implementada con resultados predecibles.
-- Verificar en waveform en flanco X3 (t_state="111").
--
-- Addr  Hex   Mnemónico   ACC  CY  Qué valida
-- ────  ────  ──────────  ───  ──  ──────────────────────────
-- 000   D5    LDM 5        5   0   LDM
-- 001   B0    XCH R0       0   0   XCH (R0←5, ACC←0)
-- 002   D3    LDM 3        3   0   LDM
-- 003   B2    XCH R2       0   0   XCH (R2←3, ACC←0)
-- 004   A0    LD  R0       5   0   LD
-- 005   82    ADD R2       8   0   ADD (5+3=8, CY=0)
-- 006   DF    LDM 15       F   0   LDM
-- 007   82    ADD R2       2   1   ADD overflow (F+3=2, CY=1)
-- 008   A0    LD  R0       5   1   LD
-- 009   92    SUB R2       2   1   SUB (5+NOT3+1=2, CY=1)
-- 00A   F1    CLC          2   0   CLC
-- 00B   DF    LDM 15       F   0   LDM
-- 00C   F2    IAC          0   1   IAC overflow (F+1=0, CY=1)
-- 00D   D0    LDM 0        0   1   LDM
-- 00E   F8    DAC          F   0   DAC borrow (0-1=F, CY=0)
-- 00F   F3    CMC          F   1   CMC (NOT 0 = 1)
-- 010   D5    LDM 5        5   1   LDM
-- 011   F4    CMA          A   1   CMA (NOT 0101=1010)
-- 012   F0    CLB          0   0   CLB (ACC=0, CY=0)
-- 013   FA    STC          0   1   STC
-- 014   F7    TCC          1   0   TCC (ACC←CY=1, CY←0)
-- 015   F5    RAL          2   0   RAL (0001→0010, CY=0)
-- 016   F5    RAL          4   0   RAL (0010→0100, CY=0)
-- 017   F6    RAR          2   0   RAR (0100→0010, CY=0)
-- 018   D8    LDM 8        8   0   LDM (8=1000b)
-- 019   F5    RAL          0   1   RAL (1000→0000, CY=1)
-- 01A   F6    RAR          8   0   RAR (CY=1,0000→1000, CY=0)
-- 01B   A0    LD  R0       5   0   LD final
-- 01C   00    NOP          5   0   NOP
-- 01D   00    NOP          5   0   fin del programa
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
        -- Programa de validación (30 instrucciones lineales)
        16#000# => x"D5",   -- LDM 5
        16#001# => x"B0",   -- XCH R0
        16#002# => x"D3",   -- LDM 3
        16#003# => x"B2",   -- XCH R2
        16#004# => x"A0",   -- LD  R0
        16#005# => x"82",   -- ADD R2
        16#006# => x"DF",   -- LDM 15
        16#007# => x"82",   -- ADD R2
        16#008# => x"A0",   -- LD  R0
        16#009# => x"92",   -- SUB R2
        16#00A# => x"F1",   -- CLC
        16#00B# => x"DF",   -- LDM 15
        16#00C# => x"F2",   -- IAC
        16#00D# => x"D0",   -- LDM 0
        16#00E# => x"F8",   -- DAC
        16#00F# => x"F3",   -- CMC
        16#010# => x"D5",   -- LDM 5
        16#011# => x"F4",   -- CMA
        16#012# => x"F0",   -- CLB
        16#013# => x"FA",   -- STC
        16#014# => x"F7",   -- TCC
        16#015# => x"F5",   -- RAL
        16#016# => x"F5",   -- RAL
        16#017# => x"F6",   -- RAR
        16#018# => x"D8",   -- LDM 8
        16#019# => x"F5",   -- RAL
        16#01A# => x"F6",   -- RAR
        16#01B# => x"A0",   -- LD  R0
        16#01C# => x"00",   -- NOP
        16#01D# => x"00",   -- NOP

        others  => x"00"    -- NOP (posiciones no usadas)
    );

    signal addr_reg       : std_logic_vector(11 downto 0) := (others => '0');
    signal data_reg       : std_logic_vector(7 downto 0)  := (others => '0');
    signal out_high       : std_logic := '0';
    signal out_low        : std_logic := '0';
    -- send_low_next: emitir nibble bajo en el ciclo siguiente al que se activa out_high
    signal send_low_next  : std_logic := '0';

begin

    -- ----------------------------------------------------------
    -- Proceso síncrono: latcha dirección (A1-A3) y decodifica (A3→M1)
    -- ----------------------------------------------------------
    SYNC_ROM : process(clk)
    begin
        if rising_edge(clk) then
            -- Defaults: apagar salidas y pipeline
            out_high      <= '0';
            out_low       <= send_low_next;  -- propagar el flag del ciclo anterior
            send_low_next <= '0';

            if cm_rom = '1' then
                case fase is
                    when "00" =>  -- A1: captura nibble alto de dirección
                        addr_reg(11 downto 8) <= bus_io;

                    when "01" =>  -- A2: captura nibble medio de dirección
                        addr_reg(7 downto 4) <= bus_io;

                    when "10" =>  -- A3: captura nibble bajo, accede ROM
                        addr_reg(3 downto 0) <= bus_io;
                        data_reg <= ROM_DATA(
                            TO_INTEGER(unsigned(addr_reg(11 downto 4) & bus_io))
                        );
                        out_high      <= '1';   -- M1: emite nibble alto
                        send_low_next <= '1';   -- M2: emitirá nibble bajo

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
