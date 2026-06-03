library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.pkg_4004.all;

entity cpu_4004_top is
    Port (
        -- Pines físicos del chip Intel 4004 (16-pin DIP)
        
        -- Clocks
        clk_ph1     : in  STD_LOGIC;
        clk_ph2     : in  STD_LOGIC;
        
        -- Control Inputs
        reset       : in  STD_LOGIC;
        test_pin    : in  STD_LOGIC;
        
        -- Control Outputs
        sync        : out STD_LOGIC;
        cm_rom      : out STD_LOGIC;
        cm_ram      : out STD_LOGIC_VECTOR(3 downto 0);
        
        -- D0-D3 bidirectional Data Bus
        D_bus       : inout STD_LOGIC_VECTOR(BUS_W-1 downto 0)
    );
end cpu_4004_top;

architecture Structural of cpu_4004_top is

    -- =======================================================
    -- 4 BIT INTERNAL DATA BUS
    -- =======================================================
    signal cable_bus_interno     : STD_LOGIC_VECTOR(BUS_W-1 downto 0);

    -- =======================================================
    -- SEÑALES: Data Bus Buffer
    -- =======================================================
    signal cable_ext_in          : STD_LOGIC_VECTOR(BUS_W-1 downto 0);
    signal ctrl_dir_out          : STD_LOGIC := '0';
    signal ctrl_ext_oe           : STD_LOGIC;

    -- =======================================================
    -- SEÑALES: Accumulator y Temp. Register
    -- =======================================================
    signal cable_acc_out         : STD_LOGIC_VECTOR(BUS_W-1 downto 0);
    signal cable_acc_oe          : STD_LOGIC := '0';
    
    signal cable_tmp_reg_out     : STD_LOGIC_VECTOR(BUS_W-1 downto 0);
    signal cable_tmp_reg_oe      : STD_LOGIC := '0';

    -- =======================================================
    -- SEÑALES: ALU, Decimal Adjust y Flag Flip Flops
    -- =======================================================
    signal cable_alu_out         : STD_LOGIC_VECTOR(BUS_W-1 downto 0);
    signal cable_alu_oe          : STD_LOGIC := '0';
    
    signal ctrl_alu_op           : STD_LOGIC_VECTOR(2 downto 0) := "000";
    signal cable_alu_carry_out   : STD_LOGIC;
    signal cable_alu_zero        : STD_LOGIC;
    
    signal cable_decimal_adj_out : STD_LOGIC_VECTOR(BUS_W-1 downto 0);
    signal ctrl_alu_b_mux        : STD_LOGIC := '0';
    signal cable_alu_a_in        : STD_LOGIC_VECTOR(BUS_W-1 downto 0);
    signal cable_alu_b_in        : STD_LOGIC_VECTOR(BUS_W-1 downto 0);
    signal ctrl_alu_carry_in     : STD_LOGIC;

    
    -- Señales de carga para Acumulador y Temp Reg
    signal ctrl_acc_load         : STD_LOGIC := '0';
    signal ctrl_tmp_load         : STD_LOGIC := '0';
    
    signal cable_flags_in        : STD_LOGIC_VECTOR(BUS_W-1 downto 0);
    signal cable_flags_out       : STD_LOGIC_VECTOR(BUS_W-1 downto 0);
    signal cable_flags_oe        : STD_LOGIC := '0';
    
    -- =======================================================
    -- SEÑALES: Instruction Register & Decoder
    -- =======================================================
    signal cable_ir_out_8bit     : STD_LOGIC_VECTOR(7 downto 0);
    signal cable_decoder_out     : STD_LOGIC_VECTOR(BUS_W-1 downto 0);
    signal cable_decoder_oe      : STD_LOGIC := '0';
    signal cable_decoder_oe_gated : STD_LOGIC := '0';

    -- =======================================================
    -- SEÑALES: Address Stack y Scratch Pad
    -- =======================================================
    signal cable_stack_out       : STD_LOGIC_VECTOR(BUS_W-1 downto 0);
    signal cable_stack_oe        : STD_LOGIC := '0';
    
    signal stack_in_12b          : STD_LOGIC_VECTOR(11 downto 0);
    signal stack_out_12b         : STD_LOGIC_VECTOR(11 downto 0);
    signal cable_sp_clk          : STD_LOGIC := '0';
    
    -- Señales para lógica de saltos (JCN, JUN, JMS) e instrucciones de 2 bytes
    signal second_byte_reg       : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal cond_invert           : STD_LOGIC;
    signal cond_accum            : STD_LOGIC;
    signal cond_carry            : STD_LOGIC;
    signal cond_test             : STD_LOGIC;
    signal cond_met              : STD_LOGIC;
    signal jcn_taken             : STD_LOGIC;
    signal jump_taken_active     : STD_LOGIC;
    signal target_jump_addr      : STD_LOGIC_VECTOR(11 downto 0);
    signal ctrl_stack_up_down    : STD_LOGIC := '0';
    signal ctrl_stack_en         : STD_LOGIC := '0';

    signal cable_scratch_pad_out : STD_LOGIC_VECTOR(BUS_W-1 downto 0);
    signal cable_scratch_pad_oe  : STD_LOGIC := '0';
    
    signal ctrl_scratch_we       : STD_LOGIC := '0';
    signal ctrl_scratch_pair     : STD_LOGIC := '0';
    signal ctrl_scratch_addr     : STD_LOGIC_VECTOR(3 downto 0);
    signal scratch_data_in       : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal scratch_data_out      : STD_LOGIC_VECTOR(7 downto 0);

    -- =======================================================
    -- SEÑALES: Timing and Control
    -- =======================================================
    signal load_flags            : STD_LOGIC := '0';
    signal load_ir_high          : STD_LOGIC := '0';
    signal load_ir_low           : STD_LOGIC := '0';
    signal fase_reloj            : STD_LOGIC_VECTOR(1 downto 0) := "00";
    signal cable_t_state         : STD_LOGIC_VECTOR(2 downto 0);
    
    -- Señales pendientes del futuro Instruction Decoder
    signal cable_inst_group      : STD_LOGIC_VECTOR(15 downto 0) := (others => '0');
    signal cable_current_frag    : STD_LOGIC := '0';
    signal cable_disable_ir      : STD_LOGIC := '0';

    -- =======================================================
    -- SEÑALES: ROM (4001) - chip select
    -- =======================================================
    -- La ROM 4001 es un componente EXTERNO conectado al bus D0-D3.
    -- El CPU sólo genera cm_rom (chip select) para seleccionarla.
    -- La instancia de la ROM va en el testbench, no aquí.
    signal ctrl_cm_rom           : STD_LOGIC := '0';
    signal cable_pc_out          : STD_LOGIC_VECTOR(11 downto 0);
    signal cable_is_2byte        : STD_LOGIC;


begin

    -- Lógica simple para coordinar lectura/escritura exterior
    ctrl_ext_oe <= ctrl_dir_out;

    -- Gatea la habilitación de salida del decodificador para que sólo conduzca
    -- al bus interno durante la fase de ejecución (X1-X3), previniendo colisiones en Fetch (M2)
    cable_decoder_oe_gated <= cable_decoder_oe when (cable_t_state = "101" or cable_t_state = "110" or cable_t_state = "111") else '0';

    -- Reloj para el puntero de pila: sólo conmuta en llamadas a subrutina (JMS) o retornos (BBL)
    cable_sp_clk <= clk_ph1 when (cable_inst_group(5) = '1' or cable_inst_group(7) = '1') else '0';

    -- CM_ROM: chip select físico hacia la ROM 4001 externa
    cm_rom <= ctrl_cm_rom;

    -- =======================================================
    -- TIMING AND CONTROL
    -- =======================================================
    inst_timing_and_control: entity work.timing_and_control
    port map(
        clk_ph1       => clk_ph1,
        clk_ph2       => clk_ph2,
        reset         => reset,
        test_pin      => test_pin,
        ir_in         => cable_ir_out_8bit,
        
        inst_group    => cable_inst_group,
        current_frag  => cable_current_frag,
        disable_ir    => cable_disable_ir,
        
        t_state       => cable_t_state,
        
        sync          => sync,
        fase_reloj    => fase_reloj,
        ext_dir       => ctrl_dir_out,
        load_ir_high  => load_ir_high,
        load_ir_low   => load_ir_low,
        
        acc_load      => ctrl_acc_load,
        acc_oe        => cable_acc_oe,
        tmp_load      => ctrl_tmp_load,
        tmp_oe        => cable_tmp_reg_oe,
        
        alu_op        => ctrl_alu_op,
        alu_b_mux     => ctrl_alu_b_mux,
        alu_oe        => cable_alu_oe,
        
        flags_load    => load_flags,
        flags_oe      => cable_flags_oe,
        
        scratch_we    => ctrl_scratch_we,
        scratch_pair  => ctrl_scratch_pair,
        scratch_oe    => cable_scratch_pad_oe,
        
        stack_oe      => cable_stack_oe,
        stack_up_dn   => ctrl_stack_up_down,
        stack_en      => ctrl_stack_en,

        cm_rom_out    => ctrl_cm_rom
    );

    -- =======================================================
    -- 4 BIT INTERNAL DATA BUS (Multiplexor central)
    -- =======================================================
    inst_bus_interno: entity work.bus_interno_mux
    port map(
        acc_out      => cable_acc_out,
        acc_oe       => cable_acc_oe,
        
        tmp_reg_out  => cable_tmp_reg_out, 
        tmp_reg_oe   => cable_tmp_reg_oe,
        
        flags_out    => cable_flags_out,
        flags_oe     => cable_flags_oe,

        alu_out      => cable_alu_out,
        alu_oe       => cable_alu_oe,

        decoder_out  => cable_decoder_out,
        decoder_oe   => cable_decoder_oe_gated,
        
        stack_out    => cable_stack_out,
        stack_oe     => cable_stack_oe,
        
        reg_mux_out  => cable_scratch_pad_out,
        reg_mux_oe   => cable_scratch_pad_oe,

        ext_buf_out  => cable_ext_in,
        ext_buf_oe   => ctrl_ext_oe,

        internal_bus => cable_bus_interno
    );

    -- =======================================================
    -- DATA BUS BUFFER
    -- =======================================================
    -- Gestiona la comunicación bidireccional con el bus D0-D3.
    -- Durante A1-A3: dir_out='0' → el stack vuelca la dirección al exterior.
    -- Durante M1-M2: dir_out='1' → la ROM externa pone datos en D_bus
    --                y el buffer los introduce en el bus interno hacia el IR.
    inst_data_bus_buffer: entity work.data_bus_buffer
    port map(
        internal_bus_in  => cable_bus_interno,
        internal_bus_out => cable_ext_in,
        dir_out          => ctrl_dir_out,
        data_bus_ext     => D_bus
    );

    -- =======================================================
    -- ACCUMULATOR
    -- =======================================================
    inst_accumulator: entity work.accumulator
    port map(
        clk      => clk_ph1,
        reset    => reset,
        load_en  => ctrl_acc_load,
        d_in     => cable_bus_interno,
        q_out    => cable_acc_out
    );

    -- =======================================================
    -- TEMP. REGISTER
    -- =======================================================
    inst_temp_register: entity work.temp_register
    port map(
        clk      => clk_ph1,
        reset    => reset,
        load_en  => ctrl_tmp_load,
        d_in     => cable_bus_interno,
        q_out    => cable_tmp_reg_out
    );

    -- =======================================================
    -- ALU
    -- =======================================================
    -- Durante la instrucción INC (cable_inst_group(6) = '1'), enrutamos el contenido del
    -- registro del scratchpad (cable_scratch_pad_out) al operando A de la ALU para incrementarlo
    -- directamente sin alterar el acumulador.
    cable_alu_a_in <= cable_scratch_pad_out when cable_inst_group(6) = '1' else cable_acc_out;
    cable_alu_b_in <= cable_decimal_adj_out when ctrl_alu_b_mux = '1' else cable_tmp_reg_out;
    
    -- Fix para DAA: Cuando se ejecuta DAA, la suma de ajuste (6 o 0) NO debe incluir el carry flag como sumando (+1).
    -- Por tanto, forzamos carry_in = '0' para la ALU durante la instrucción DAA.
    ctrl_alu_carry_in <= '0' when (cable_inst_group(15) = '1' and cable_ir_out_8bit(3 downto 0) = "1011") else cable_flags_out(0);
    
    inst_alu: entity work.alu
    port map(
        A_in        => cable_alu_a_in,
        B_in        => cable_alu_b_in,
        carry_in    => ctrl_alu_carry_in,
        op          => ctrl_alu_op,
        result_out  => cable_alu_out,
        carry_out   => cable_alu_carry_out,
        zero_flag   => cable_alu_zero
    );

    -- =======================================================
    -- DECIMAL ADJUST
    -- =======================================================
    inst_decimal_adjust: entity work.decimal_adjust
    port map(
        acc_in   => cable_acc_out,
        carry_in => cable_flags_out(0),
        adj_out  => cable_decimal_adj_out
    );

    -- =======================================================
    -- FLAG FLIP FLOPS
    -- =======================================================
    -- Lógica para la entrada del registro de banderas (flags):
    -- Bit 0 (Carry):
    --   - CLC (1111 0001): se limpia ('0')
    --   - CLB (1111 0000): se limpia ('0')
    --   - CMC (1111 0011): se complementa (not cable_flags_out(0))
    --   - Sumas/Restas/Ajuste decimal (ADD, SUB, DAA): recibe el carry de la ALU
    --   - Por defecto: cable_alu_carry_out
    -- Bit 1 (Test): conectado a test_pin
    -- Bits 3 y 2: libres a cero
    cable_flags_in(0) <= 
        '0' when cable_inst_group(15) = '1' and cable_ir_out_8bit(3 downto 0) = "0001" else -- CLC
        '0' when cable_inst_group(15) = '1' and cable_ir_out_8bit(3 downto 0) = "0000" else -- CLB
        not cable_flags_out(0) when cable_inst_group(15) = '1' and cable_ir_out_8bit(3 downto 0) = "0011" else -- CMC
        cable_alu_carry_out;
        
    cable_flags_in(1) <= test_pin;
    cable_flags_in(3 downto 2) <= "00";

    inst_flag_flip_flops: entity work.flag_flip_flops
    port map(
        clk      => clk_ph1,
        reset    => reset,
        load_en  => load_flags,
        d_in     => cable_flags_in,
        q_out    => cable_flags_out,
        flags_oe => cable_flags_oe
    );

    -- =======================================================
    -- INSTRUCTION REGISTER
    -- =======================================================
    inst_instruction_register: entity work.instruction_register
    port map(
        clk         => clk_ph1,
        reset       => reset,
        load_high   => load_ir_high,
        load_low    => load_ir_low,
        bus_in      => cable_bus_interno,
        instr_out   => cable_ir_out_8bit,
        decoder_out => open, -- Conectado al Decoder en el esquema
        decoder_oe  => open  -- Controlado por el Decoder
    );

    -- =======================================================
    -- INSTRUCTION DECODER AND MACHINE CYCLE ENCODING
    -- =======================================================
    inst_instruction_decoder: entity work.instruction_decoder
    port map(
        ir_in       => cable_ir_out_8bit,
        inst_group  => cable_inst_group,
        is_2byte    => cable_is_2byte,
        is_daa      => open,
        is_tcs      => open,
        is_rdr      => open,
        is_wrr      => open,
        is_wmp      => open,
        is_clc      => open,
        is_clb      => open,
        is_cmc      => open,
        bus_out     => cable_decoder_out,
        out_en      => cable_decoder_oe
    );

    -- Proceso secuencial para controlar el estado de instrucciones de 2 bytes (2 ciclos)
    process(clk_ph1, reset)
    begin
        if reset = '1' then
            cable_current_frag <= '0';
            cable_disable_ir   <= '0';
        elsif rising_edge(clk_ph1) then
            if cable_t_state = "111" then -- Al final del estado X3 del ciclo de máquina
                if cable_current_frag = '0' and cable_is_2byte = '1' then
                    cable_current_frag <= '1';
                    cable_disable_ir   <= '1'; -- Desactiva la carga de nueva instrucción en IR
                else
                    cable_current_frag <= '0';
                    cable_disable_ir   <= '0';
                end if;
            end if;
        end if;
    end process;

    -- =======================================================
    -- LÓGICA DE CAPTURA DEL SEGUNDO BYTE E EVALUACIÓN DE JCN
    -- =======================================================
    process(clk_ph1, reset)
    begin
        if reset = '1' then
            second_byte_reg <= (others => '0');
        elsif rising_edge(clk_ph1) then
            -- Si estamos en el ciclo 2 (current_frag = '1'), capturamos el dato en las fases M1 y M2
            if cable_current_frag = '1' then
                if cable_t_state = "011" then     -- Fase M1 (captura nibble alto del 2º byte)
                    second_byte_reg(7 downto 4) <= cable_bus_interno;
                elsif cable_t_state = "100" then   -- Fase M2 (captura nibble bajo del 2º byte)
                    second_byte_reg(3 downto 0) <= cable_bus_interno;
                end if;
            end if;
        end if;
    end process;

    -- Evaluación de la condición JCN (Jump on Condition):
    -- ir_in(3) (bit 3): invertir condición (1 = salta si NO se cumple la condición)
    -- ir_in(2) (bit 2): salta si Acumulador es cero
    -- ir_in(1) (bit 1): salta si Carry es uno
    -- ir_in(0) (bit 0): salta si Test Pin es cero
    cond_invert <= cable_ir_out_8bit(3);
    cond_accum  <= '1' when (cable_ir_out_8bit(2) = '1' and cable_acc_out = "0000") else '0';
    cond_carry  <= '1' when (cable_ir_out_8bit(1) = '1' and cable_flags_out(0) = '1') else '0';
    cond_test   <= '1' when (cable_ir_out_8bit(0) = '1' and test_pin = '0') else '0';
    
    cond_met    <= cond_accum or cond_carry or cond_test;
    jcn_taken   <= (not cond_met) when cond_invert = '1' else cond_met;

    -- Determina si se toma el salto
    jump_taken_active <= '1' when (cable_inst_group(4) = '1' or cable_inst_group(5) = '1' or (cable_inst_group(1) = '1' and jcn_taken = '1')) else '0';

    -- Dirección destino del salto:
    -- JUN/JMS: 12 bits formados por el nibble bajo del opcode (ir_in(3:0)) y el segundo byte.
    -- JCN: 8 bits en la página actual. Conserva los 4 bits altos del PC actual.
    target_jump_addr <= 
        cable_pc_out(11 downto 8) & second_byte_reg when cable_inst_group(1) = '1' else
        cable_ir_out_8bit(3 downto 0) & second_byte_reg;

    -- Multiplexado de la entrada de la pila:
    -- Si es un salto efectivo, cargamos la dirección destino.
    -- En cualquier otro caso, avanzamos el PC en 1 (normal PC + 1).
    stack_in_12b <= 
        target_jump_addr when (cable_current_frag = '1' and jump_taken_active = '1') else
        std_logic_vector(unsigned(cable_pc_out) + 1);

    -- =======================================================
    -- ADDRESS STACK
    -- =======================================================
    inst_address_stack: entity work.stack_3L
    port map(
        Clk_s       => clk_ph1,
        sp_clk      => cable_sp_clk,
        U_D_s       => ctrl_stack_up_down,
        D_12_s      => stack_in_12b,
        E_s         => ctrl_stack_en,
        R_s         => reset,
        oe_s        => cable_stack_oe,
        fase_s      => fase_reloj,
        sal_4_stck  => cable_stack_out,
        PC_out      => cable_pc_out
    );

    -- =======================================================
    -- SCRATCH PAD
    -- =======================================================
    -- Entrada de datos al scratchpad:
    -- En modo par (como FIM), pasamos los 8 bits completos capturados en second_byte_reg.
    -- En modo individual, pasamos el nibble inferior desde el bus interno.
    scratch_data_in <= 
        second_byte_reg when ctrl_scratch_pair = '1' else 
        "0000" & cable_bus_interno;
    
    -- Direccionamiento dinámico del scratchpad:
    -- Si estamos en modo par (ctrl_scratch_pair = '1'):
    --   - En la fase M2 (cable_t_state = "100") o fases finales de ejecución X2/X3, direccionamos el registro impar de la pareja.
    --   - En otras fases, direccionamos el registro par.
    -- Si estamos en modo normal:
    --   - Direccionamiento directo del registro indicado por ir_in(3:0).
    ctrl_scratch_addr <= 
        cable_ir_out_8bit(3 downto 1) & '1' when ctrl_scratch_pair = '1' and (cable_t_state = "100" or cable_t_state = "110" or cable_t_state = "111") else
        cable_ir_out_8bit(3 downto 1) & '0' when ctrl_scratch_pair = '1' else
        cable_ir_out_8bit(3 downto 0);
    
    inst_scratch_pad: entity work.scratch_pad
    port map(
        clk_r      => clk_ph1,
        rst_r      => reset,
        w_e        => ctrl_scratch_we,
        pair_mode  => ctrl_scratch_pair,
        address    => ctrl_scratch_addr,
        data_in    => scratch_data_in,
        data_out   => scratch_data_out
    );

    -- Conexión de salida al bus interno de 4 bits:
    -- Serializa la pareja de registros de 8 bits a través del bus de 4 bits durante SRC.
    cable_scratch_pad_out <= 
        scratch_data_out(7 downto 4) when (ctrl_scratch_pair = '1' and cable_t_state = "101") else -- X1: envía R4
        scratch_data_out(3 downto 0); -- Otros estados y X2: envía R5

    -- =======================================================
    -- TIMING AND CONTROL
    -- =======================================================
    -- inst_timing_and_control: entity work.timing_and_control
    -- port map(
    --     clk_ph1     => clk_ph1,
    --     clk_ph2     => clk_ph2,
    --     sync        => sync,
    --     reset       => reset,
    --     test_pin    => test_pin,
    --     cm_rom      => cm_rom,
    --     cm_ram      => cm_ram
    -- );

end Structural;