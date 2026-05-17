library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- =============================================================
-- Timing and Control — Intel 4004
--
-- Gestiona los 8 T-states del ciclo de máquina (A1-A3, M1-M2, X1-X3)
-- y genera todas las señales de control del datapath según la instrucción
-- activa (recibida del Instruction Decoder como vector one-hot).
--
-- Mapa de inst_group (one-hot, índice 0 = LSB):
--   Instrucciones de un ciclo (nibble alto 0000-1101):
--     0  = NOP   1  = JCN*  2  = FIM*/SRC  3  = FIN/JIN
--     4  = JUN*  5  = JMS*  6  = INC       7  = ISZ*
--     8  = ADD   9  = SUB   10 = LD        11 = XCH
--     12 = BBL   13 = LDM   14 = grupo1110  15 = grupo1111
--
--   Cuando inst_group(15)='1' (grupo 1111 activo), los bits 0..13
--   contienen la salida del sub-decoder d4_14:
--     0=CLB 1=CLC 2=IAC 3=CMC 4=CMA 5=RAL 6=RAR 7=TCC
--     8=DAC 9=TCS 10=STC 11=DAA 12=KBP 13=DCL
--
--   Cuando inst_group(14)='1' (grupo 1110 activo), bits 0..15
--   contienen la salida del sub-decoder d4_15 (instrucciones RAM).
--
-- ALU op codes (4 bits):
--   0000=ADD  0001=SUB  0010=AND  0011=OR  0100=XOR
--   0101=PASS_A  0110=INC  0111=DEC  1000=NOT_A
--   1001=RAL  1010=RAR  1111=ZERO
-- =============================================================

entity timing_and_control is
    Port (
        clk_ph1       : in  STD_LOGIC;
        clk_ph2       : in  STD_LOGIC;
        reset         : in  STD_LOGIC;

        inst_group    : in  STD_LOGIC_VECTOR(15 downto 0);
        current_frag  : in  STD_LOGIC;
        disable_ir    : in  STD_LOGIC;

        carry_in      : in  STD_LOGIC;

        t_state       : out STD_LOGIC_VECTOR(2 downto 0);

        sync          : out STD_LOGIC;
        fase_reloj    : out STD_LOGIC_VECTOR(1 downto 0);
        ext_dir       : out STD_LOGIC;
        load_ir_high  : out STD_LOGIC;
        load_ir_low   : out STD_LOGIC;

        acc_load      : out STD_LOGIC;
        acc_oe        : out STD_LOGIC;
        tmp_load      : out STD_LOGIC;
        tmp_oe        : out STD_LOGIC;

        alu_op        : out STD_LOGIC_VECTOR(3 downto 0);
        alu_b_mux     : out STD_LOGIC;
        alu_oe        : out STD_LOGIC;

        flags_load    : out STD_LOGIC;
        flags_oe      : out STD_LOGIC;
        carry_load_en : out STD_LOGIC;
        force_carry_en : out STD_LOGIC;
        force_carry_val: out STD_LOGIC;

        scratch_we    : out STD_LOGIC;
        scratch_pair  : out STD_LOGIC;
        scratch_oe    : out STD_LOGIC;

        stack_oe      : out STD_LOGIC;
        stack_up_dn   : out STD_LOGIC;
        stack_en      : out STD_LOGIC;

        cm_rom_out    : out STD_LOGIC
    );
end timing_and_control;

architecture Behavioral of timing_and_control is
    signal current_state : unsigned(2 downto 0) := "000";

    -- Señales de grupo activo
    signal is_group1111 : STD_LOGIC;
    signal is_group1110 : STD_LOGIC;
begin
    t_state <= std_logic_vector(current_state);

    is_group1111 <= inst_group(15);
    is_group1110 <= inst_group(14);

    -- --------------------------------------------------------
    -- Contador de T-states
    -- 000(A1)→001(A2)→010(A3)→011(M1)→100(M2)→101(X1)→110(X2)→111(X3)→000
    -- --------------------------------------------------------
    process(clk_ph1, reset)
    begin
        if reset = '1' then
            current_state <= "000";
        elsif rising_edge(clk_ph1) then
            if current_state = "111" then
                current_state <= "000";
            else
                current_state <= current_state + 1;
            end if;
        end if;
    end process;

    -- --------------------------------------------------------
    -- Lógica combinacional de señales de control
    -- --------------------------------------------------------
    process(current_state, inst_group, current_frag, disable_ir, carry_in,
            is_group1111, is_group1110)
    begin
        -- ---- Valores por defecto ----
        sync            <= '0';
        fase_reloj      <= "00";
        ext_dir         <= '0';
        load_ir_high    <= '0';
        load_ir_low     <= '0';

        acc_load        <= '0';
        acc_oe          <= '0';
        tmp_load        <= '0';
        tmp_oe          <= '0';

        alu_op          <= "0101";  -- PASS_A (neutro)
        alu_b_mux       <= '0';
        alu_oe          <= '0';

        flags_load      <= '0';
        flags_oe        <= '0';
        carry_load_en   <= '0';
        force_carry_en  <= '0';
        force_carry_val <= '0';

        scratch_we      <= '0';
        scratch_pair    <= '0';
        scratch_oe      <= '0';

        stack_oe        <= '0';
        stack_up_dn     <= '0';
        stack_en        <= '0';

        cm_rom_out      <= '0';

        case current_state is

            -- ================================================
            -- FASES DE BÚSQUEDA (FETCH)
            -- ================================================
            -- A1-A3: CPU → ROM. ext_dir='1': CPU conduce D_bus con la dirección del PC.
            -- ctrl_ext_oe = NOT '1' = '0': el buffer externo no colisiona con stack_oe.
            when "000" =>  -- A1: CPU vuelca PC[11:8]
                sync       <= '1';
                fase_reloj <= "00";
                stack_oe   <= '1';
                ext_dir    <= '1';
                cm_rom_out <= '1';

            when "001" =>  -- A2: CPU vuelca PC[7:4]
                fase_reloj <= "01";
                stack_oe   <= '1';
                ext_dir    <= '1';
                cm_rom_out <= '1';

            when "010" =>  -- A3: CPU vuelca PC[3:0]
                fase_reloj <= "10";
                stack_oe   <= '1';
                ext_dir    <= '1';
                cm_rom_out <= '1';

            -- M1-M2: ROM → CPU. ext_dir='0' (default): CPU tristatea, ROM conduce D_bus.
            -- ctrl_ext_oe = NOT '0' = '1': datos de ROM llegan al bus interno → IR.
            when "011" =>  -- M1: ROM pone nibble alto en el bus
                cm_rom_out <= '1';
                if disable_ir = '0' then
                    load_ir_high <= '1';
                end if;

            when "100" =>  -- M2: ROM pone nibble bajo en el bus
                if disable_ir = '0' then
                    load_ir_low <= '1';
                end if;

            -- ================================================
            -- FASES DE EJECUCIÓN (EXECUTE)
            -- ================================================
            when "101" =>  -- X1
                if current_frag = '0' then
                    -- ------------------------------------------
                    -- Instrucciones registro-acumulador (ciclo único)
                    -- X1: leer registro al temp o directo a acc
                    -- ------------------------------------------

                    -- ADD (8), SUB (9): reg → tmp
                    if inst_group(8) = '1' or inst_group(9) = '1' then
                        scratch_oe <= '1';
                        tmp_load   <= '1';
                    end if;

                    -- LD (10): reg → acc directamente
                    if inst_group(10) = '1' then
                        scratch_oe <= '1';
                        acc_load   <= '1';
                    end if;

                    -- XCH (11): reg → tmp (acc irá a reg en X2, tmp irá a acc en X3)
                    if inst_group(11) = '1' then
                        scratch_oe <= '1';
                        tmp_load   <= '1';
                    end if;

                    -- INC (6): reg → tmp
                    if inst_group(6) = '1' then
                        scratch_oe <= '1';
                        tmp_load   <= '1';
                    end if;

                    -- ISZ (7): reg → tmp
                    if inst_group(7) = '1' then
                        scratch_oe <= '1';
                        tmp_load   <= '1';
                    end if;

                    -- LDM (13): decoder pone dato inmediato → acc
                    if inst_group(13) = '1' then
                        acc_load <= '1';
                    end if;

                    -- ------------------------------------------
                    -- Grupo 1111 (ACC/carry): todas ejecutan en X1
                    -- inst_group(15)='1' indica grupo activo;
                    -- bits 0..13 son salida del sub-decoder d4_14.
                    -- ------------------------------------------

                    -- CLB: ACC←0, CY←0
                    if is_group1111 = '1' and inst_group(0) = '1' then
                        alu_op          <= "1111";  -- ZERO
                        alu_oe          <= '1';
                        acc_load        <= '1';
                        force_carry_en  <= '1';
                        force_carry_val <= '0';
                    end if;

                    -- CLC: CY←0
                    if is_group1111 = '1' and inst_group(1) = '1' then
                        force_carry_en  <= '1';
                        force_carry_val <= '0';
                    end if;

                    -- IAC: ACC←ACC+1; CY=carry_out
                    if is_group1111 = '1' and inst_group(2) = '1' then
                        alu_op        <= "0110";  -- INC
                        alu_oe        <= '1';
                        acc_load      <= '1';
                        carry_load_en <= '1';
                    end if;

                    -- CMC: CY←NOT CY
                    if is_group1111 = '1' and inst_group(3) = '1' then
                        force_carry_en  <= '1';
                        force_carry_val <= NOT carry_in;
                    end if;

                    -- CMA: ACC←NOT ACC
                    if is_group1111 = '1' and inst_group(4) = '1' then
                        alu_op   <= "1000";  -- NOT_A
                        alu_oe   <= '1';
                        acc_load <= '1';
                    end if;

                    -- RAL: {CY,ACC} rotate left — CY entra por A0, sale por A3
                    if is_group1111 = '1' and inst_group(5) = '1' then
                        alu_op        <= "1001";  -- RAL
                        alu_oe        <= '1';
                        acc_load      <= '1';
                        carry_load_en <= '1';
                    end if;

                    -- RAR: {CY,ACC} rotate right — CY entra por A3, sale por A0
                    if is_group1111 = '1' and inst_group(6) = '1' then
                        alu_op        <= "1010";  -- RAR
                        alu_oe        <= '1';
                        acc_load      <= '1';
                        carry_load_en <= '1';
                    end if;

                    -- TCC: ACC←"000"&CY; CY←0
                    -- flags_oe pone {0,0,0,CY} en el bus; acc_load lo captura
                    if is_group1111 = '1' and inst_group(7) = '1' then
                        flags_oe        <= '1';
                        acc_load        <= '1';
                        force_carry_en  <= '1';
                        force_carry_val <= '0';
                    end if;

                    -- DAC: ACC←ACC-1; CY=not borrow (1 si no underflow)
                    if is_group1111 = '1' and inst_group(8) = '1' then
                        alu_op        <= "0111";  -- DEC
                        alu_oe        <= '1';
                        acc_load      <= '1';
                        carry_load_en <= '1';
                    end if;

                    -- STC: CY←1
                    if is_group1111 = '1' and inst_group(10) = '1' then
                        force_carry_en  <= '1';
                        force_carry_val <= '1';
                    end if;

                end if;  -- current_frag='0'

            when "110" =>  -- X2
                if current_frag = '0' then
                    -- ADD: A + tmp → acc, carry desde ALU carry_out
                    if inst_group(8) = '1' then
                        alu_op        <= "0000";  -- ADD
                        alu_b_mux     <= '0';
                        alu_oe        <= '1';
                        acc_load      <= '1';
                        carry_load_en <= '1';
                    end if;

                    -- SUB: A + NOT(tmp) + C → acc, carry desde ALU carry_out
                    if inst_group(9) = '1' then
                        alu_op        <= "0001";  -- SUB
                        alu_b_mux     <= '0';
                        alu_oe        <= '1';
                        acc_load      <= '1';
                        carry_load_en <= '1';
                    end if;

                    -- XCH: acc → scratch (escribe acc al registro)
                    if inst_group(11) = '1' then
                        acc_oe     <= '1';
                        scratch_we <= '1';
                    end if;

                    -- INC: tmp + 1 → acc y scratchpad (carry NO se modifica)
                    if inst_group(6) = '1' then
                        alu_op     <= "0110";  -- INC
                        alu_oe     <= '1';
                        acc_load   <= '1';
                        scratch_we <= '1';
                    end if;

                    -- ISZ: tmp + 1 → acc, escribe en registro; actualiza zero para salto
                    if inst_group(7) = '1' then
                        alu_op     <= "0110";  -- INC
                        alu_oe     <= '1';
                        acc_load   <= '1';
                        scratch_we <= '1';
                        flags_load <= '1';
                    end if;

                    -- BBL: decoder_out → acc, stack pop
                    if inst_group(12) = '1' then
                        acc_load    <= '1';
                        stack_up_dn <= '1';  -- pop (down)
                        stack_en    <= '1';
                    end if;
                end if;

            when "111" =>  -- X3
                if current_frag = '0' then
                    -- XCH: tmp → acc (segunda mitad del intercambio)
                    if inst_group(11) = '1' then
                        tmp_oe   <= '1';
                        acc_load <= '1';
                    end if;
                end if;

            when others =>
                null;
        end case;
    end process;

end Behavioral;
