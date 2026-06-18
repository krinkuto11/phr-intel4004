----------------------------------------------------------------------------------
-- Testbench del sistema completo CPU + ROM
-- Instancia el núcleo Intel 4004 junto con la ROM 4001 y genera el reloj de dos
-- fases y el reset para simular la ejecución del programa completo.
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_cpu_4004 is
end tb_cpu_4004;

architecture sim of tb_cpu_4004 is
    -- Clock & Reset
    signal clk_ph1       : std_logic := '0';
    signal clk_ph2       : std_logic := '0';
    signal reset         : std_logic := '1';
    signal test_pin      : std_logic := '1'; -- Test pin inactivo (1 por defecto en 4004)
    
    -- Bus de datos bidireccional D0-D3
    signal bus_io        : std_logic_vector(3 downto 0) := (others => 'Z');
    
    -- Señales de monitoreo
    signal sync          : std_logic;
    signal cm_rom        : std_logic;
    signal cm_ram        : std_logic_vector(3 downto 0);
    
    constant CLK_PERIOD  : time := 100 ns; -- Reloj base del sistema

    -- Señales para deducir la fase del bus y sincronizar la ROM
    signal t_state       : unsigned(2 downto 0) := "000";
    signal rom_fase      : std_logic_vector(1 downto 0);
    signal bcd_result    : std_logic_vector(3 downto 0);

    -- Señales para los operandos controladas dinámicamente
    signal operando_A : std_logic_vector(3 downto 0) := x"0";
    signal operando_B : std_logic_vector(3 downto 0) := x"0";
    signal operador   : std_logic_vector(3 downto 0) := x"0";

begin

    -- Generador de relojes de dos fases no solapadas (ph1 y ph2)
    process
    begin
        while true loop
            clk_ph1 <= '1';
            wait for CLK_PERIOD / 4;
            clk_ph1 <= '0';
            wait for CLK_PERIOD / 4;
            clk_ph2 <= '1';
            wait for CLK_PERIOD / 4;
            clk_ph2 <= '0';
            wait for CLK_PERIOD / 4;
        end loop;
    end process;

    -- Proceso de estímulo de Reset
    process
    begin
        reset <= '1';
        wait for 400 ns;
        reset <= '0';
        wait;
    end process;

    -- Instanciación de la CPU Intel 4004
    uut_cpu: entity work.cpu_4004_top
    port map(
        clk_ph1   => clk_ph1,
        clk_ph2   => clk_ph2,
        reset     => reset,
        test_pin  => test_pin,
        D_bus     => bus_io,
        sync      => sync,
        cm_rom    => cm_rom,
        cm_ram    => cm_ram
    );

    -- Deducimos el estado del bus de la CPU a partir de 'sync'
    process(clk_ph1, reset)
    begin
        if reset = '1' then
            t_state <= "000";
        elsif rising_edge(clk_ph1) then
            if sync = '1' then
                t_state <= "001"; -- Siguiente flanco después de sync (A1) es A2
            else
                if t_state = "111" then
                    t_state <= "000";
                else
                    t_state <= t_state + 1;
                end if;
            end if;
        end if;
    end process;

    -- Generación de la fase para la ROM 4001:
    rom_fase <= "00" when sync = '1' else
                "01" when t_state = "001" else
                "10" when t_state = "010" else
                "11";

    -- Instanciación de la ROM externa 4001 con E/S
    uut_rom: entity work.ROM
    port map(
        clk          => clk_ph1,
        cm_rom       => cm_rom,
        fase         => rom_fase,
        bus_io       => bus_io,
        rom0_io_in   => operando_A,
        rom1_io_in   => operando_B,
        rom2_io_in   => operador,
        rom2_io_out  => bcd_result
    );

    -- Secuencia de pruebas dinámicas (Vectores de prueba)
    process
    begin
        -- === SUMA ===
        -- Test 1: 5 + 3 = 8
        operando_A <= x"5"; operando_B <= x"3"; operador <= x"0"; wait for 150 us;
        -- Test 2: 9 + 4 = 13 (Muestra 3)
        operando_A <= x"9"; operando_B <= x"4"; operador <= x"0"; wait for 150 us;
        -- Test 3: 0 + 0 = 0
        operando_A <= x"0"; operando_B <= x"0"; operador <= x"0"; wait for 150 us;
        -- Test 4: 9 + 9 = 18 (Muestra 8)
        operando_A <= x"9"; operando_B <= x"9"; operador <= x"0"; wait for 150 us;
        -- Test 5: 0 + 5 = 5
        operando_A <= x"0"; operando_B <= x"5"; operador <= x"0"; wait for 150 us;

        -- === RESTA ===
        -- Test 6: 8 - 3 = 5
        operando_A <= x"8"; operando_B <= x"3"; operador <= x"1"; wait for 150 us;
        -- Test 7: 3 - 5 = 0 (Saturación)
        operando_A <= x"3"; operando_B <= x"5"; operador <= x"1"; wait for 150 us;
        -- Test 8: 0 - 0 = 0
        operando_A <= x"0"; operando_B <= x"0"; operador <= x"1"; wait for 150 us;
        -- Test 9: 0 - 5 = 0 (Saturación)
        operando_A <= x"0"; operando_B <= x"5"; operador <= x"1"; wait for 150 us;
        -- Test 10: 5 - 0 = 5
        operando_A <= x"5"; operando_B <= x"0"; operador <= x"1"; wait for 150 us;
        -- Test 11: 9 - 9 = 0
        operando_A <= x"9"; operando_B <= x"9"; operador <= x"1"; wait for 150 us;

        -- === COMPARA ===
        -- Test 12: 7 COMPARE 7 = 3 (Iguales)
        operando_A <= x"7"; operando_B <= x"7"; operador <= x"2"; wait for 150 us;
        -- Test 13: 9 COMPARE 4 = 1 (Mayor)
        operando_A <= x"9"; operando_B <= x"4"; operador <= x"2"; wait for 150 us;
        -- Test 14: 2 COMPARE 8 = 2 (Menor)
        operando_A <= x"2"; operando_B <= x"8"; operador <= x"2"; wait for 150 us;
        -- Test 15: 0 COMPARE 0 = 3 (Iguales)
        operando_A <= x"0"; operando_B <= x"0"; operador <= x"2"; wait for 150 us;
        -- Test 16: 0 COMPARE 9 = 2 (Menor)
        operando_A <= x"0"; operando_B <= x"9"; operador <= x"2"; wait for 150 us;
        -- Test 17: 9 COMPARE 0 = 1 (Mayor)
        operando_A <= x"9"; operando_B <= x"0"; operador <= x"2"; wait for 150 us;

        -- === MULTIPLICA ===
        -- Test 18: 3 * 2 = 6
        operando_A <= x"3"; operando_B <= x"2"; operador <= x"3"; wait for 150 us;
        -- Test 19: 4 * 3 = 12 (Muestra 2)
        operando_A <= x"4"; operando_B <= x"3"; operador <= x"3"; wait for 150 us;
        -- Test 20: 0 * 5 = 0
        operando_A <= x"0"; operando_B <= x"5"; operador <= x"3"; wait for 150 us;
        -- Test 21: 5 * 0 = 0
        operando_A <= x"5"; operando_B <= x"0"; operador <= x"3"; wait for 150 us;
        -- Test 22: 0 * 0 = 0
        operando_A <= x"0"; operando_B <= x"0"; operador <= x"3"; wait for 150 us;
        -- Test 23: 9 * 9 = 81 (Muestra 1)
        operando_A <= x"9"; operando_B <= x"9"; operador <= x"3"; wait for 200 us; -- Da un poco mas de tiempo al bucle
        -- Test 24: 1 * 9 = 9
        operando_A <= x"1"; operando_B <= x"9"; operador <= x"3"; wait for 200 us; -- Da un poco mas de tiempo al bucle

        wait;
    end process;

    -- Proceso de monitoreo por consola: solo imprimiremos cuando el resultado cambie
    process(clk_ph1)
        use std.textio.all;
        variable line_out : line;
        variable last_result : std_logic_vector(3 downto 0) := "UUUU";
    begin
        if rising_edge(clk_ph1) then
            if bcd_result /= last_result and bcd_result /= "UUUU" then
                write(line_out, string'("====================================="));
                writeline(output, line_out);
                write(line_out, string'("NUEVO RESULTADO EN DISPLAY detectado a "));
                write(line_out, now);
                writeline(output, line_out);
                write(line_out, string'("Operacion: "));
                write(line_out, to_integer(unsigned(operando_A)));
                if operador = x"0" then
                    write(line_out, string'(" + "));
                elsif operador = x"1" then
                    write(line_out, string'(" - "));
                elsif operador = x"2" then
                    write(line_out, string'(" COMPARE "));
                elsif operador = x"3" then
                    write(line_out, string'(" * "));
                end if;
                write(line_out, to_integer(unsigned(operando_B)));
                write(line_out, string'(" => DISPLAY MUESTRA: "));
                write(line_out, to_integer(unsigned(bcd_result)));
                writeline(output, line_out);
                write(line_out, string'("====================================="));
                writeline(output, line_out);
                last_result := bcd_result;
            end if;
        end if;
    end process;

end sim;
