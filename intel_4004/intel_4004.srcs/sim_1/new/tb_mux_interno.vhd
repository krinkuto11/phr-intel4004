----------------------------------------------------------------------------------
-- Testbench del Multiplexor del Bus Interno
-- Comprueba que sólo la fuente habilitada conduce el bus y que una colisión
-- entre varias salidas activas a la vez se señaliza correctamente.
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.pkg_4004.all;

entity tb_bus_interno_mux is
-- La entidad de testbench siempre va vacía
end tb_bus_interno_mux;

architecture simulacion of tb_bus_interno_mux is

    -- =======================================================
    -- SEÑALES DE CONTROL PARA LOS STUBS
    -- =======================================================
    -- Señales de "Write Enable" individuales
    signal we_acc      : STD_LOGIC := '0';
    signal we_tmp_reg  : STD_LOGIC := '0';
    signal we_flags    : STD_LOGIC := '0';
    signal we_alu      : STD_LOGIC := '0';
    signal we_decoder  : STD_LOGIC := '0';
    signal we_stack    : STD_LOGIC := '0';
    signal we_reg_mux  : STD_LOGIC := '0';
    signal we_ext_buf  : STD_LOGIC := '0';

    -- Cables de salida de los stubs hacia el MUX
    signal out_acc     : STD_LOGIC_VECTOR(BUS_W-1 downto 0);
    signal out_tmp_reg : STD_LOGIC_VECTOR(BUS_W-1 downto 0);
    signal out_flags   : STD_LOGIC_VECTOR(BUS_W-1 downto 0);
    signal out_alu     : STD_LOGIC_VECTOR(BUS_W-1 downto 0);
    signal out_decoder : STD_LOGIC_VECTOR(BUS_W-1 downto 0);
    signal out_stack   : STD_LOGIC_VECTOR(BUS_W-1 downto 0);
    signal out_reg_mux : STD_LOGIC_VECTOR(BUS_W-1 downto 0);
    signal out_ext_buf : STD_LOGIC_VECTOR(BUS_W-1 downto 0);

    -- El cable general que queremos observar
    signal tb_internal_bus : STD_LOGIC_VECTOR(BUS_W-1 downto 0);

begin

    -- =======================================================
    -- 1. INSTANCIACIÓN DE LOS 8 STUBS (Componentes Falsos)
    -- =======================================================
    -- Asignamos a cada uno un valor fijo diferente para poder identificarlos en el bus.

    stub_acc: entity work.stub_componente
        port map ( valor_de_prueba => "0001", bus_in => BUS_CERO, bus_out => out_acc, write_en => we_acc );
        
    stub_tmp_reg: entity work.stub_componente
        port map ( valor_de_prueba => "0010", bus_in => BUS_CERO, bus_out => out_tmp_reg, write_en => we_tmp_reg );
        
    stub_flags: entity work.stub_componente
        port map ( valor_de_prueba => "0011", bus_in => BUS_CERO, bus_out => out_flags, write_en => we_flags );
        
    stub_alu: entity work.stub_componente
        port map ( valor_de_prueba => "0100", bus_in => BUS_CERO, bus_out => out_alu, write_en => we_alu );
        
    stub_decoder: entity work.stub_componente
        port map ( valor_de_prueba => "0101", bus_in => BUS_CERO, bus_out => out_decoder, write_en => we_decoder );
        
    stub_stack: entity work.stub_componente
        port map ( valor_de_prueba => "0110", bus_in => BUS_CERO, bus_out => out_stack, write_en => we_stack );
        
    stub_reg_mux: entity work.stub_componente
        port map ( valor_de_prueba => "0111", bus_in => BUS_CERO, bus_out => out_reg_mux, write_en => we_reg_mux );
        
    stub_ext_buf: entity work.stub_componente
        port map ( valor_de_prueba => "1000", bus_in => BUS_CERO, bus_out => out_ext_buf, write_en => we_ext_buf );

    -- =======================================================
    -- 2. INSTANCIACIÓN DE TU MULTIPLEXOR CENTRAL (El DUT)
    -- =======================================================
    DUT_MUX: entity work.bus_interno_mux
        port map (
            acc_out      => out_acc,      acc_we      => we_acc,
            tmp_reg_out  => out_tmp_reg,  tmp_reg_we  => we_tmp_reg,
            flags_out    => out_flags,    flags_we    => we_flags,
            alu_out      => out_alu,      alu_we      => we_alu,
            decoder_out  => out_decoder,  decoder_we  => we_decoder,
            stack_out    => out_stack,    stack_we    => we_stack,
            reg_mux_out  => out_reg_mux,  reg_mux_we  => we_reg_mux,
            ext_buf_out  => out_ext_buf,  ext_buf_we  => we_ext_buf,
            internal_bus => tb_internal_bus
        );

    -- =======================================================
    -- 3. PROCESO PRINCIPAL DE LOS 3 TESTS
    -- =======================================================
    process_tests: process
    begin
        -- Pequeña pausa inicial
        wait for 10 ns;
        
        -- =======================================================
        -- TEST 1: REPOSO (IDLE)
        -- Objetivo: Si nadie tiene permiso, el bus debe estar a cero.
        -- =======================================================
        report "--- INICIANDO TEST 1: REPOSO ---";
        -- Nos aseguramos que todo esté apagado
        we_acc <= '0'; we_tmp_reg <= '0'; we_flags <= '0'; we_alu <= '0';
        we_decoder <= '0'; we_stack <= '0'; we_reg_mux <= '0'; we_ext_buf <= '0';
        
        wait for 10 ns;
        assert (tb_internal_bus = BUS_CERO) 
            report "Fallo en Test 1: El bus no esta a ceros en estado de reposo." severity error;
            
        -- =======================================================
        -- TEST 2: RUTEO INDIVIDUAL (ROUND ROBIN)
        -- Objetivo: Cada componente escribe uno a uno, verificando que el dato correcto llega al bus.
        -- =======================================================
        report "--- INICIANDO TEST 2: RUTEO ---";
        
        -- Turno 1: Acumulador
        we_acc <= '1'; wait for 10 ns;
        assert (tb_internal_bus = "0001") report "Fallo Test 2: Mux no rutea el Acumulador" severity error;
        we_acc <= '0'; wait for 5 ns; -- Apagamos y dejamos estabilizar
        
        -- Turno 2: Temp Register
        we_tmp_reg <= '1'; wait for 10 ns;
        assert (tb_internal_bus = "0010") report "Fallo Test 2: Mux no rutea el Temp Register" severity error;
        we_tmp_reg <= '0'; wait for 5 ns;
        
        -- Turno 3: ALU
        we_alu <= '1'; wait for 10 ns;
        assert (tb_internal_bus = "0100") report "Fallo Test 2: Mux no rutea la ALU" severity error;
        we_alu <= '0'; wait for 5 ns;

        -- Turno 4: Buffer Externo
        we_ext_buf <= '1'; wait for 10 ns;
        assert (tb_internal_bus = "1000") report "Fallo Test 2: Mux no rutea el Buffer Externo" severity error;
        we_ext_buf <= '0'; wait for 10 ns;

        -- =======================================================
        -- TEST 3: COLISIÓN (ESTRÉS)
        -- Objetivo: Dos componentes escriben a la vez. El Mux debe forzar XXXX.
        -- =======================================================
        report "--- INICIANDO TEST 3: COLISION ---";
        
        -- Encendemos ALU y Flags al mismo tiempo
        we_alu <= '1';
        we_flags <= '1';
        wait for 10 ns;
        
        assert (tb_internal_bus = BUS_ERROR) 
            report "Fallo en Test 3: El Mux NO detecto la colision (no saco XXXX)." severity error;
            
        -- Limpieza final
        we_alu <= '0';
        we_flags <= '0';
        wait for 10 ns;
        
        report "--- TODOS LOS TESTS SUPERADOS CORRECTAMENTE ---";
        wait; -- Detenemos la simulación infinitamente
    end process;

end simulacion;