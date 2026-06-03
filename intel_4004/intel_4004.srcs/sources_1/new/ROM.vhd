-- ----------------------------------------------------------
-- Intel 4001 ROM - Modelo SÍNCRONO con Soporte de E/S
-- ----------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity ROM is
    port (
        clk          : in    std_logic;
        cm_rom       : in    std_logic;                      -- Chip select (activo alto)
        fase         : in    std_logic_vector(1 downto 0);   -- Fase del bus (desde T&C)
        bus_io       : inout std_logic_vector(3 downto 0);   -- Bus D0-D3 bidireccional
        
        -- Puertos de E/S físicos de las ROMs 4001
        rom0_io_in   : in    std_logic_vector(3 downto 0);   -- Entrada ROM 0 (Operando A)
        rom1_io_in   : in    std_logic_vector(3 downto 0);   -- Entrada ROM 1 (Operando B)
        rom2_io_in   : in    std_logic_vector(3 downto 0);   -- Entrada ROM 2 (Operador)
        rom2_io_out  : out   std_logic_vector(3 downto 0)    -- Salida ROM 2 (Resultado BCD)
    );
end ROM;

architecture Behavioral of ROM is

    type rom_t is array(0 to 4095) of std_logic_vector(7 downto 0);

    -- Programa de Calculadora BCD en Código de Máquina Intel 4004 (4 operaciones)
    constant ROM_DATA : rom_t := (
        -- LECTURA DE OPERANDO A (ROM 0)
        16#000# => x"D0",   -- LDM 0
        16#001# => x"B4",   -- XCH R4
        16#002# => x"D0",   -- LDM 0
        16#003# => x"B5",   -- XCH R5
        16#004# => x"25",   -- SRC R4
        16#005# => x"EA",   -- RDR (lee Operando A)
        16#006# => x"B0",   -- XCH R0 (Guarda A en R0)

        -- LECTURA DE OPERANDO B (ROM 1)
        16#007# => x"D1",   -- LDM 1
        16#008# => x"B4",   -- XCH R4
        16#009# => x"D0",   -- LDM 0
        16#00A# => x"B5",   -- XCH R5
        16#00B# => x"25",   -- SRC R4
        16#00C# => x"EA",   -- RDR (lee Operando B)
        16#00D# => x"B1",   -- XCH R1 (Guarda B en R1)

        -- LECTURA DE OPERADOR (ROM 2)
        16#00E# => x"D2",   -- LDM 2
        16#00F# => x"B4",   -- XCH R4
        16#010# => x"D0",   -- LDM 0
        16#011# => x"B5",   -- XCH R5
        16#012# => x"25",   -- SRC R4
        16#013# => x"EA",   -- RDR (lee Operador)
        16#014# => x"B2",   -- XCH R2 (Guarda Op en R2)

        -- ARBOL SELECTOR DE OPERACIÓN
        16#015# => x"DF",   -- LDM 15 (para restar 1)
        16#016# => x"B3",   -- XCH R3 (Guarda 15 en R3)
        16#017# => x"A2",   -- LD R2 (Carga Op)
        16#018# => x"14",   -- JCN Z (Salta a SUMA si Op = 0)
        16#019# => x"2A",   -- Dirección SUMA (0x02A)
        16#01A# => x"F1",   -- CLC (Limpia carry antes de sumar)
        16#01B# => x"83",   -- ADD R3 (ACC = Op - 1)
        16#01C# => x"14",   -- JCN Z (Salta a RESTA si Op = 1)
        16#01D# => x"33",   -- Dirección RESTA (0x033)
        16#01E# => x"F1",   -- CLC (Limpia carry antes de sumar)
        16#01F# => x"83",   -- ADD R3 (ACC = Op - 2)
        16#020# => x"14",   -- JCN Z (Salta a COMPARA si Op = 2)
        16#021# => x"40",   -- Dirección COMPARA (0x040)
        16#022# => x"40",   -- JUN (Salta a MULTIPLICA si Op = 3)
        16#023# => x"52",   -- Dirección MULTIPLICA (0x052)

        -- NOPs de alineación
        16#024# => x"00", 16#025# => x"00", 16#026# => x"00", 16#027# => x"00", 16#028# => x"00", 16#029# => x"00",

        -- --- SUMA (0x02A) ---
        16#02A# => x"A0",   -- LD R0
        16#02B# => x"F1",   -- CLC
        16#02C# => x"81",   -- ADD R1
        16#02D# => x"00",   -- NOP (Sin DAA para permitir valores hexadecimales A-F)
        16#02E# => x"B3",   -- XCH R3 (Guarda resultado en R3)
        16#02F# => x"40",   -- JUN (Salta a DISPLAY)
        16#030# => x"6B",   -- Dirección DISPLAY (0x06B)
        16#031# => x"00",   -- NOP
        16#032# => x"00",   -- NOP

        -- --- RESTA (0x033) ---
        16#033# => x"A0",   -- LD R0
        16#034# => x"F1",   -- CLC
        16#035# => x"F3",   -- CMC (Carry = 1)
        16#036# => x"91",   -- SUB R1
        16#037# => x"12",   -- JCN C (Salta a R_OK si no hay préstamo)
        16#038# => x"3D",   -- Dirección R_OK (0x03D)
        16#039# => x"D0",   -- LDM 0 (Satura a 0 si A < B)
        16#03A# => x"B3",   -- XCH R3
        16#03B# => x"40",   -- JUN (Salta a DISPLAY)
        16#03C# => x"6B",   -- Dirección DISPLAY (0x06B)
        16#03D# => x"B3",   -- XCH R3 (R_OK: guarda resultado en R3)
        16#03E# => x"40",   -- JUN (Salta a DISPLAY)
        16#03F# => x"6B",   -- Dirección DISPLAY (0x06B)

        -- --- COMPARA (0x040) ---
        16#040# => x"A0",   -- LD R0
        16#041# => x"F1",   -- CLC
        16#042# => x"F3",   -- CMC
        16#043# => x"91",   -- SUB R1
        16#044# => x"14",   -- JCN Z (Salta a C_EQ si A = B)
        16#045# => x"4E",   -- Dirección C_EQ (0x04E)
        16#046# => x"12",   -- JCN C (Salta a C_GT si A > B)
        16#047# => x"4B",   -- Dirección C_GT (0x04B)
        16#048# => x"D2",   -- LDM 2 (C_LT: devolver 2)
        16#049# => x"40",   -- JUN (Salta a C_FIN)
        16#04A# => x"4F",   -- Dirección C_FIN (0x04F)
        16#04B# => x"D1",   -- LDM 1 (C_GT: devolver 1)
        16#04C# => x"40",   -- JUN (Salta a C_FIN)
        16#04D# => x"4F",   -- Dirección C_FIN (0x04F)
        16#04E# => x"D3",   -- LDM 3 (C_EQ: devolver 3)
        16#04F# => x"B3",   -- XCH R3 (C_FIN: guarda en R3)
        16#050# => x"40",   -- JUN (Salta a DISPLAY)
        16#051# => x"6B",   -- Dirección DISPLAY (0x06B)

        -- --- MULTIPLICA (0x052) ---
        16#052# => x"D0",   -- LDM 0
        16#053# => x"B3",   -- XCH R3 (R3 = 0)
        16#054# => x"A1",   -- LD R1 (Carga B)
        16#055# => x"14",   -- JCN Z (Salta a DISPLAY si B = 0)
        16#056# => x"6B",   -- Dirección DISPLAY (0x06B)
        16#057# => x"A0",   -- LD R0 (Carga A)
        16#058# => x"14",   -- JCN Z (Salta a DISPLAY si A = 0)
        16#059# => x"6B",   -- Dirección DISPLAY (0x06B)
        16#05A# => x"DF",   -- LDM 15
        16#05B# => x"B2",   -- XCH R2 (R2 = 15 para restar 1)
        -- LOOP_MULT (0x05C)
        16#05C# => x"A3",   -- LD R3 (LOOP_MULT: Carga acumulado)
        16#05D# => x"F1",   -- CLC
        16#05E# => x"80",   -- ADD R0 (Suma A)
        16#05F# => x"00",   -- NOP (Sin DAA para permitir valores hexadecimales A-F)
        16#060# => x"B3",   -- XCH R3 (Guarda acumulado)
        16#061# => x"A1",   -- LD R1 (Carga contador B)
        16#062# => x"F1",   -- CLC
        16#063# => x"82",   -- ADD R2 (B = B - 1)
        16#064# => x"B1",   -- XCH R1 (Guarda contador B, Accumulator tiene viejo B)
        16#065# => x"A1",   -- LD R1 (Carga el nuevo B en el Accumulator para el check!)
        16#066# => x"1C",   -- JCN NZ (Salta a LOOP_MULT si B /= 0)
        16#067# => x"5C",   -- Dirección LOOP_MULT (0x05C)
        16#068# => x"40",   -- JUN (Salta a DISPLAY)
        16#069# => x"6B",   -- Dirección DISPLAY (0x06B)
        16#06A# => x"00",   -- NOP

        -- --- DISPLAY (0x06B) ---
        16#06B# => x"D2",   -- LDM 2
        16#06C# => x"B4",   -- XCH R4
        16#06D# => x"D0",   -- LDM 0
        16#06E# => x"B5",   -- XCH R5
        16#06F# => x"25",   -- SRC R4
        16#070# => x"A3",   -- LD R3
        16#071# => x"E2",   -- WRR (Escribe a puerto ROM 2)
        16#072# => x"40",   -- JUN START
        16#073# => x"00",   -- Dirección 0x000

        others  => x"00"    -- NOP
    );

    -- Registro interno de la dirección de 12 bits
    signal addr_reg  : std_logic_vector(11 downto 0) := (others => '0');

    -- Registro del byte de instrucción
    signal data_reg  : std_logic_vector(7 downto 0) := (others => '0');

    -- Flags internos para serialización de instrucción
    signal out_high  : std_logic := '0';  -- '1' -> M1 (nibble alto)
    signal out_low   : std_logic := '0';  -- '1' -> M2 (nibble bajo)
    signal cycle_cnt        : integer range 0 to 7 := 0;
    signal active_rom_port  : integer range 0 to 15 := 0;
    signal rom_driving_io   : std_logic := '0';
    signal rom2_io_out_reg  : std_logic_vector(3 downto 0) := (others => '0'); -- rom2_io_out_reg de 4 bits

    -- Señal concurrente para resolver la concatenación sin ambigüedad y de forma segura para la síntesis
    signal full_addr : std_logic_vector(11 downto 0);

begin

    -- Enlace de los registros externos de salida
    rom2_io_out <= rom2_io_out_reg;

    -- rom_driving_io de forma combinacional para responder inmediatamente en X1 (cycle_cnt = 4)
    rom_driving_io <= '1' when (data_reg = x"EA" and cycle_cnt = 4) else '0';

    -- Concatenación de dirección completa para indexar ROM_DATA
    full_addr <= bus_io & addr_reg(7 downto 0);

    -- ----------------------------------------------------------
    -- Proceso síncrono principal
    -- ----------------------------------------------------------
    SYNC_ROM : process(clk)
    begin
        if rising_edge(clk) then
            out_high <= '0';
            out_low  <= '0';

            -- Seguimiento del ciclo de estados del procesador (8 estados: 0 a 7)
            if fase = "00" then
                cycle_cnt <= 0;
            else
                if cycle_cnt = 7 then
                    cycle_cnt <= 0;
                else
                    cycle_cnt <= cycle_cnt + 1;
                end if;
            end if;

            -- Lógica de captura de dirección y chip select de la ROM
            case fase is
                when "00" =>  -- A1: captura nibble bajo de dirección (siempre activo para latch)
                    addr_reg(3 downto 0) <= bus_io;

                when "01" =>  -- A2: captura nibble medio de dirección (siempre activo para latch)
                    addr_reg(7 downto 4) <= bus_io;

                when "10" =>  -- A3: captura nibble alto + decodifica (sólo si este chip está seleccionado)
                    if cm_rom = '1' then
                        addr_reg(11 downto 8) <= bus_io;
                        data_reg <= ROM_DATA(
                            TO_INTEGER(unsigned(full_addr))
                        );
                        out_high <= '1';  -- El siguiente ciclo es M1
                    else
                        data_reg <= (others => '0'); -- NOP si no está seleccionado
                    end if;

                when "11" =>  -- Fases M1, M2, X1, X2, X3
                    -- Sólo activamos out_low para la fase M2. Al final de M1, cycle_cnt es 2.
                    if cm_rom = '1' and cycle_cnt = 2 then
                        out_low  <= '1';
                    end if;

                when others => null;
            end case;

            -- Lógica de captura de SRC y Escrituras de E/S
            -- SRC R4 (Opcode x"25")
            if data_reg = x"25" then
                if cycle_cnt = 4 then -- Estado X1: captura el nibble alto de la dirección de ROM (R4)
                    active_rom_port <= TO_INTEGER(unsigned(bus_io));
                end if;
            end if;

            -- WRR (Opcode x"E2")
            if data_reg = x"E2" then
                if cycle_cnt = 4 then -- Estado X1: captura la salida del acumulador al final de la fase
                    if active_rom_port = 2 then
                        rom2_io_out_reg <= bus_io;
                    end if;
                end if;
            end if;

        end if;
    end process SYNC_ROM;

    -- ----------------------------------------------------------
    -- Salida bidireccional triestado hacia el bus D0-D3
    -- ----------------------------------------------------------
    bus_io <= data_reg(7 downto 4) when out_high = '1' else
              data_reg(3 downto 0) when out_low  = '1' else
              rom0_io_in  when (rom_driving_io = '1' and active_rom_port = 0) else
              rom1_io_in  when (rom_driving_io = '1' and active_rom_port = 1) else
              rom2_io_in  when (rom_driving_io = '1' and active_rom_port = 2) else
              (others => 'Z');

end Behavioral;
