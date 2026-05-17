library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.pkg_4004.all;

entity cpu_4004_top is
    Port (
        clk_ph1     : in  STD_LOGIC;
        clk_ph2     : in  STD_LOGIC;
        reset       : in  STD_LOGIC;
        test_pin    : in  STD_LOGIC;
        sync        : out STD_LOGIC;
        cm_rom      : out STD_LOGIC;
        cm_ram      : out STD_LOGIC_VECTOR(3 downto 0);
        D_bus       : inout STD_LOGIC_VECTOR(BUS_W-1 downto 0);
        fase_out    : out STD_LOGIC_VECTOR(1 downto 0)
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

    signal ctrl_alu_op           : STD_LOGIC_VECTOR(3 downto 0) := "0101";  -- PASS_A
    signal cable_alu_carry_out   : STD_LOGIC;
    signal cable_alu_zero        : STD_LOGIC;

    signal cable_decimal_adj_out : STD_LOGIC_VECTOR(BUS_W-1 downto 0);
    signal ctrl_alu_b_mux        : STD_LOGIC := '0';
    signal cable_alu_b_in        : STD_LOGIC_VECTOR(BUS_W-1 downto 0);

    signal ctrl_acc_load         : STD_LOGIC := '0';
    signal ctrl_tmp_load         : STD_LOGIC := '0';

    signal cable_flags_out       : STD_LOGIC_VECTOR(BUS_W-1 downto 0);
    signal cable_flags_oe        : STD_LOGIC := '0';

    -- Señales de control de flags
    signal load_flags            : STD_LOGIC := '0';
    signal cable_carry_load_en   : STD_LOGIC := '0';
    signal cable_force_carry_en  : STD_LOGIC := '0';
    signal cable_force_carry_val : STD_LOGIC := '0';

    -- =======================================================
    -- SEÑALES: Instruction Register & Decoder
    -- =======================================================
    signal cable_ir_out_8bit     : STD_LOGIC_VECTOR(7 downto 0);
    signal cable_decoder_out     : STD_LOGIC_VECTOR(BUS_W-1 downto 0);
    signal cable_decoder_oe      : STD_LOGIC := '0';

    -- =======================================================
    -- SEÑALES: Address Stack y Scratch Pad
    -- =======================================================
    signal cable_stack_out       : STD_LOGIC_VECTOR(BUS_W-1 downto 0);
    signal cable_stack_oe        : STD_LOGIC := '0';

    signal stack_in_12b          : STD_LOGIC_VECTOR(11 downto 0) := (others => '0');
    signal stack_out_12b         : STD_LOGIC_VECTOR(11 downto 0);
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
    signal load_ir_high          : STD_LOGIC := '0';
    signal load_ir_low           : STD_LOGIC := '0';
    signal fase_reloj            : STD_LOGIC_VECTOR(1 downto 0) := "00";
    signal cable_t_state         : STD_LOGIC_VECTOR(2 downto 0);

    signal cable_inst_group      : STD_LOGIC_VECTOR(15 downto 0);
    signal cable_current_frag    : STD_LOGIC;
    signal cable_disable_ir      : STD_LOGIC;
    signal cable_decoder_imm     : STD_LOGIC_VECTOR(BUS_W-1 downto 0);

    -- =======================================================
    -- SEÑALES: ROM chip select
    -- =======================================================
    signal ctrl_cm_rom           : STD_LOGIC := '0';

    -- =======================================================
    -- SEÑALES: Program Counter (12 bits)
    -- El PC es el top-of-stack. Se auto-incrementa en M2 y
    -- se escribe en el stack al inicio de cada ciclo de fetch.
    -- =======================================================
    signal pc_reg                : STD_LOGIC_VECTOR(11 downto 0) := (others => '0');

begin

    ctrl_ext_oe <= not ctrl_dir_out;
    cm_rom   <= ctrl_cm_rom;
    fase_out <= fase_reloj;

    -- =======================================================
    -- PROGRAM COUNTER: auto-incremento en estado M2 (t_state="100")
    -- Instrucciones de 2 palabras incrementan el PC dos veces
    -- (una por cada ciclo de máquina), lo cual es el comportamiento
    -- correcto según la spec del 4004.
    -- =======================================================
    process(clk_ph1, reset)
    begin
        if reset = '1' then
            pc_reg <= (others => '0');
        elsif rising_edge(clk_ph1) then
            if cable_t_state = "100" then  -- M2: instrucción ya captada, incrementar PC
                pc_reg <= std_logic_vector(unsigned(pc_reg) + 1);
            end if;
        end if;
    end process;

    -- stack_in_12b reservado para futura implementación de JMS/BBL.
    -- Por ahora el PC sale directo al bus por el proceso de abajo.
    stack_in_12b <= pc_reg;

    -- =======================================================
    -- TIMING AND CONTROL
    -- =======================================================
    inst_timing_and_control: entity work.timing_and_control
    port map(
        clk_ph1         => clk_ph1,
        clk_ph2         => clk_ph2,
        reset           => reset,

        inst_group      => cable_inst_group,
        current_frag    => cable_current_frag,
        disable_ir      => cable_disable_ir,

        carry_in        => cable_flags_out(0),

        t_state         => cable_t_state,

        sync            => sync,
        fase_reloj      => fase_reloj,
        ext_dir         => ctrl_dir_out,
        load_ir_high    => load_ir_high,
        load_ir_low     => load_ir_low,

        acc_load        => ctrl_acc_load,
        acc_oe          => cable_acc_oe,
        tmp_load        => ctrl_tmp_load,
        tmp_oe          => cable_tmp_reg_oe,

        alu_op          => ctrl_alu_op,
        alu_b_mux       => ctrl_alu_b_mux,
        alu_oe          => cable_alu_oe,

        flags_load      => load_flags,
        flags_oe        => cable_flags_oe,
        carry_load_en   => cable_carry_load_en,
        force_carry_en  => cable_force_carry_en,
        force_carry_val => cable_force_carry_val,

        scratch_we      => ctrl_scratch_we,
        scratch_pair    => ctrl_scratch_pair,
        scratch_oe      => cable_scratch_pad_oe,

        stack_oe        => cable_stack_oe,
        stack_up_dn     => ctrl_stack_up_down,
        stack_en        => ctrl_stack_en,

        cm_rom_out      => ctrl_cm_rom
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
        decoder_oe   => cable_decoder_oe,

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
    cable_alu_b_in <= cable_decimal_adj_out when ctrl_alu_b_mux = '1' else cable_tmp_reg_out;

    inst_alu: entity work.alu
    port map(
        A_in        => cable_acc_out,
        B_in        => cable_alu_b_in,
        carry_in    => cable_flags_out(0),
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
    inst_flag_flip_flops: entity work.flag_flip_flops
    port map(
        clk             => clk_ph1,
        reset           => reset,
        load_en         => load_flags,
        d_in            => cable_bus_interno,
        carry_in        => cable_alu_carry_out,
        carry_load_en   => cable_carry_load_en,
        force_carry_en  => cable_force_carry_en,
        force_carry_val => cable_force_carry_val,
        q_out           => cable_flags_out
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
        decoder_out => open,
        decoder_oe  => open
    );

    -- =======================================================
    -- INSTRUCTION DECODER
    -- =======================================================
    inst_instruction_decoder: entity work.instruction_decoder
    port map(
        clk          => clk_ph1,
        reset        => reset,
        ir_in        => cable_ir_out_8bit,
        inst_group   => cable_inst_group,
        current_frag => cable_current_frag,
        disable_ir   => cable_disable_ir,
        bus_out      => cable_decoder_imm,
        out_en       => cable_decoder_oe
    );

    ctrl_scratch_addr <= cable_ir_out_8bit(3 downto 0);
    cable_decoder_out <= cable_decoder_imm;

    -- =======================================================
    -- ADDRESS OUTPUT (salida directa del PC al bus durante A1-A3)
    --
    -- El stack_3L original tiene un puntero libre (sin enable) que
    -- cambia cada ciclo de reloj, haciendo imposible serializar la
    -- dirección correctamente. Se reemplaza por lógica combinacional
    -- que vuelca los nibbles de pc_reg según la fase del bus.
    --
    -- A1 (fase="00"): nibble alto  PC[11:8]
    -- A2 (fase="01"): nibble medio PC[7:4]
    -- A3 (fase="10"): nibble bajo  PC[3:0]
    --
    -- stack_3L se mantiene en el proyecto para futura implementación
    -- de JMS (push) y BBL (pop), pero no se usa para el fetch.
    -- =======================================================
    process(cable_stack_oe, fase_reloj, pc_reg)
    begin
        if cable_stack_oe = '1' then
            case fase_reloj is
                when "00"   => cable_stack_out <= pc_reg(11 downto 8);
                when "01"   => cable_stack_out <= pc_reg(7  downto 4);
                when "10"   => cable_stack_out <= pc_reg(3  downto 0);
                when others => cable_stack_out <= (others => '0');
            end case;
        else
            cable_stack_out <= (others => '0');
        end if;
    end process;

    -- =======================================================
    -- SCRATCH PAD
    -- =======================================================
    scratch_data_in(3 downto 0) <= cable_bus_interno;

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

    cable_scratch_pad_out <= scratch_data_out(3 downto 0);

end Structural;
