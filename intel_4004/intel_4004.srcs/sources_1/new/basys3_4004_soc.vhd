----------------------------------------------------------------------------------
-- SoC envolvente para la placa Digilent Basys 3
-- Integra el núcleo Intel 4004 con la ROM 4001, genera el reloj de dos fases no
-- solapadas a partir del de 100 MHz, debouncea el botón de reset y controla el
-- display de 7 segmentos donde se muestran operandos, operador y resultado.
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity basys3_4004_soc is
    port (
        clk      : in  std_logic;                      -- Reloj de 100 MHz de la placa
        btnC     : in  std_logic;                      -- Botón central (Físico RESET)
        sw       : in  std_logic_vector(9 downto 0);   -- Interruptores:
                                                       -- sw(3..0) = Operando A
                                                       -- sw(7..4) = Operando B
                                                       -- sw(9..8) = Operador (0=Suma, 1=Resta, 2=Compara, 3=Multiplica)
        
        -- Salidas a los Displays de 7 segmentos (Ánodo Común / Activo Bajo)
        seg      : out std_logic_vector(6 downto 0);   -- Segmentos A, B, C, D, E, F, G
        dp       : out std_logic;                      -- Punto decimal
        an       : out std_logic_vector(3 downto 0)    -- Ánodos de selección de los 4 dígitos
    );
end basys3_4004_soc;

architecture Behavioral of basys3_4004_soc is

    -- ----------------------------------------------------------
    -- Declaración de señales de Reloj y Reset
    -- ----------------------------------------------------------
    signal clk_ph1       : std_logic := '0';
    signal clk_ph2       : std_logic := '0';
    signal rst_debounced : std_logic := '1';
    
    -- Divisor de reloj de 100 MHz a ~740 kHz
    -- 100 MHz / 135 = 740.74 kHz. Usamos contador de 0 a 134.
    signal clk_div_cnt   : integer range 0 to 134 := 0;

    -- ----------------------------------------------------------
    -- Señales del Bus e Interfaz de CPU / ROM
    -- ----------------------------------------------------------
    signal bus_io        : std_logic_vector(3 downto 0);
    signal sync          : std_logic;
    signal cm_rom        : std_logic;
    signal cm_ram        : std_logic_vector(3 downto 0);
    
    -- Señales para deducir la fase del bus y sincronizar la ROM
    signal t_state       : unsigned(2 downto 0) := "000";
    signal rom_fase      : std_logic_vector(1 downto 0);

    -- Datos de E/S de la ROM
    signal rom0_io_in    : std_logic_vector(3 downto 0);
    signal rom1_io_in    : std_logic_vector(3 downto 0);
    signal rom2_io_in    : std_logic_vector(3 downto 0);
    signal rom2_io_out   : std_logic_vector(3 downto 0);

    -- ----------------------------------------------------------
    -- Señales del Display de 7 Segmentos
    -- ----------------------------------------------------------
    signal scan_cnt      : unsigned(19 downto 0) := (others => '0'); -- Escaneo a ~200 Hz
    signal active_digit  : integer range 0 to 3 := 0;
    signal hex_val       : std_logic_vector(3 downto 0);
    signal seg_decoded   : std_logic_vector(6 downto 0);

    -- ----------------------------------------------------------
    -- Debouncer para el botón de Reset
    -- ----------------------------------------------------------
    signal reset_shift   : std_logic_vector(15 downto 0) := (others => '1');
    signal deb_clk_cnt   : integer range 0 to 99999 := 0; -- Reloj de muestreo a 1 kHz

    -- Decodificador de 7 segmentos para dígitos hexadecimales (Activo Bajo)
    function hex_to_7seg(val : std_logic_vector(3 downto 0)) return std_logic_vector is
    begin
        case val is
            when x"0" => return "1000000"; -- 0
            when x"1" => return "1111001"; -- 1
            when x"2" => return "0100100"; -- 2
            when x"3" => return "0110000"; -- 3
            when x"4" => return "0011001"; -- 4
            when x"5" => return "0010010"; -- 5
            when x"6" => return "0000010"; -- 6
            when x"7" => return "1111000"; -- 7
            when x"8" => return "0000000"; -- 8
            when x"9" => return "0010000"; -- 9
            when x"A" => return "0001000"; -- A
            when x"B" => return "0000011"; -- b
            when x"C" => return "1000110"; -- C
            when x"D" => return "0100001"; -- d
            when x"E" => return "0000110"; -- E
            when x"F" => return "0001110"; -- F
            when others => return "1111111";
        end case;
    end function;

begin

    -- Desactivamos el punto decimal (Ánodo Común, 1 es apagado)
    dp <= '1';

    -- ----------------------------------------------------------
    -- Generador de Relojes de 2 Fases No Solapadas (ph1 y ph2)
    -- ----------------------------------------------------------
    CLK_GEN : process(clk)
    begin
        if rising_edge(clk) then
            if clk_div_cnt = 134 then
                clk_div_cnt <= 0;
            else
                clk_div_cnt <= clk_div_cnt + 1;
            end if;

            -- Fase 1 activa de 0 a 30 (duración de ~300 ns)
            if clk_div_cnt >= 0 and clk_div_cnt <= 30 then
                clk_ph1 <= '1';
            else
                clk_ph1 <= '0';
            end if;

            -- Fase 2 activa de 67 a 97 (duración de ~300 ns)
            -- Totalmente separada de ph1 para asegurar el no solapamiento físico
            if clk_div_cnt >= 67 and clk_div_cnt <= 97 then
                clk_ph2 <= '1';
            else
                clk_ph2 <= '0';
            end if;
        end if;
    end process CLK_GEN;

    -- ----------------------------------------------------------
    -- Debouncer para el Botón de Reset Físico (btnC)
    -- ----------------------------------------------------------
    DEBOUNCER : process(clk)
    begin
        if rising_edge(clk) then
            if deb_clk_cnt = 99999 then  -- Muestreo cada 1 ms (100 MHz / 100,000)
                deb_clk_cnt <= 0;
                reset_shift <= reset_shift(14 downto 0) & btnC;
            else
                deb_clk_cnt <= deb_clk_cnt + 1;
            end if;

            -- Si el botón se mantiene presionado consistentemente durante 16 ms, se activa el reset
            if reset_shift = x"FFFF" then
                rst_debounced <= '1';
            elsif reset_shift = x"0000" then
                rst_debounced <= '0';
            end if;
        end if;
    end process DEBOUNCER;

    -- ----------------------------------------------------------
    -- Instanciación del Núcleo CPU Intel 4004
    -- ----------------------------------------------------------
    inst_cpu: entity work.cpu_4004_top
    port map(
        clk_ph1   => clk_ph1,
        clk_ph2   => clk_ph2,
        reset     => rst_debounced,
        test_pin  => '1',              -- Test pin inactivo (1)
        D_bus     => bus_io,
        sync      => sync,
        cm_rom    => cm_rom,
        cm_ram    => cm_ram
    );

    -- ----------------------------------------------------------
    -- Lógica del Receptor ROM de fases y seguimiento del ciclo
    -- ----------------------------------------------------------
    process(clk_ph1, rst_debounced)
    begin
        if rst_debounced = '1' then
            t_state <= "000";
        elsif rising_edge(clk_ph1) then
            if sync = '1' then
                t_state <= "001";
            else
                if t_state = "111" then
                    t_state <= "000";
                else
                    t_state <= t_state + 1;
                end if;
            end if;
        end if;
    end process;

    rom_fase <= "00" when sync = '1' else
                "01" when t_state = "001" else
                "10" when t_state = "010" else
                "11";

    -- Mapeo de entradas de los interruptores a los puertos de la ROM
    rom0_io_in <= sw(3 downto 0);                             -- Operando A
    rom1_io_in <= sw(7 downto 4);                             -- Operando B
    rom2_io_in <= "00" & sw(9 downto 8);                      -- Operador (0 a 3)

    -- ----------------------------------------------------------
    -- Instanciación de la ROM de 4 KB con Puertos de E/S
    -- ----------------------------------------------------------
    inst_rom: entity work.ROM
    port map(
        clk          => clk_ph1,
        cm_rom       => cm_rom,
        fase         => rom_fase,
        bus_io       => bus_io,
        rom0_io_in   => rom0_io_in,
        rom1_io_in   => rom1_io_in,
        rom2_io_in   => rom2_io_in,
        rom2_io_out  => rom2_io_out
    );

    -- ----------------------------------------------------------
    -- Controlador y Multiplexor del Display de 7 Segmentos
    -- ----------------------------------------------------------
    process(clk)
    begin
        if rising_edge(clk) then
            scan_cnt <= scan_cnt + 1;
            
            -- Selección del ánodo y del dato a mostrar según el estado de escaneo
            case scan_cnt(19 downto 18) is
                when "00" =>  -- Dígito 0: Resultado BCD (Derecha)
                    an <= "1110";
                    seg_decoded <= hex_to_7seg(rom2_io_out);
                    
                when "01" =>  -- Dígito 1: Operando B
                    an <= "1101";
                    seg_decoded <= hex_to_7seg(sw(7 downto 4));
                    
                when "10" =>  -- Dígito 2: Símbolo del Operador
                    an <= "1011";
                    case sw(9 downto 8) is
                        when "00" => seg_decoded <= "0001000"; -- 'A' de ADICIÓN
                        when "01" => seg_decoded <= "1111110"; -- '-' de RESTA
                        when "10" => seg_decoded <= "1000110"; -- 'C' de COMPARA
                        when "11" => seg_decoded <= "0001100"; -- 'P' de PRODUCTO (Multiplicación)
                        when others => seg_decoded <= "1111111";
                    end case;
                    
                when "11" =>  -- Dígito 3: Operando A (Izquierda)
                    an <= "0111";
                    seg_decoded <= hex_to_7seg(sw(3 downto 0));
                    
                when others =>
                    an <= "1111";
                    seg_decoded <= "1111111";
            end case;
        end if;
    end process;

    seg <= seg_decoded;

end Behavioral;
