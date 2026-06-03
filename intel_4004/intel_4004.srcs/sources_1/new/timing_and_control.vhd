library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity timing_and_control is
    Port (
        clk_ph1       : in  STD_LOGIC;
        clk_ph2       : in  STD_LOGIC;
        reset         : in  STD_LOGIC;
        
        -- ==========================================
        -- Entradas desde el Instruction Decoder
        -- ==========================================
        inst_group    : in  STD_LOGIC_VECTOR(15 downto 0); -- One-Hot (Ej: Bit 8 es ADD)
        current_frag  : in  STD_LOGIC;                     -- 0: Ciclo 1, 1: Ciclo 2
        disable_ir    : in  STD_LOGIC;                     -- 1 para no cargar IR
        ir_in         : in  STD_LOGIC_VECTOR(7 downto 0);  -- Byte de instrucción actual
        test_pin      : in  STD_LOGIC;                     -- Entrada de test físico
        
        -- Salida de estado para el Instruction Decoder
        t_state       : out STD_LOGIC_VECTOR(2 downto 0);
        
        -- ==========================================
        -- Salidas hacia el Datapath
        -- ==========================================
        -- Control de Timing general
        sync          : out STD_LOGIC;
        fase_reloj    : out STD_LOGIC_VECTOR(1 downto 0);
        ext_dir       : out STD_LOGIC; 
        load_ir_high  : out STD_LOGIC;
        load_ir_low   : out STD_LOGIC;
        
        -- Control de Registros
        acc_load      : out STD_LOGIC;
        acc_oe        : out STD_LOGIC;
        tmp_load      : out STD_LOGIC;
        tmp_oe        : out STD_LOGIC;
        
        -- Control de ALU
        alu_op        : out STD_LOGIC_VECTOR(2 downto 0);
        alu_b_mux     : out STD_LOGIC;
        alu_oe        : out STD_LOGIC;
        
        -- Control de Flags
        flags_load    : out STD_LOGIC;
        flags_oe      : out STD_LOGIC;
        
        -- Control de Scratch Pad
        scratch_we    : out STD_LOGIC;
        scratch_pair  : out STD_LOGIC;
        scratch_oe    : out STD_LOGIC;
        
        -- Control de Stack
        stack_oe      : out STD_LOGIC;
        stack_up_dn   : out STD_LOGIC;
        stack_en      : out STD_LOGIC;

        -- Control de ROM (4001) - solo chip select
        cm_rom_out    : out STD_LOGIC  -- Chip select físico hacia la ROM 4001 externa
    );
end timing_and_control;

architecture Behavioral of timing_and_control is
    signal current_state : unsigned(2 downto 0) := "000";
begin
    t_state <= std_logic_vector(current_state);
    
    -- El 4004 cambia de ciclo de máquina con la caída de phi_2,
    -- lo modelaremos de forma simplificada con el flanco de subida de phi_1.
    process(clk_ph1, reset)
    begin
        if reset = '1' then
            current_state <= "000"; -- Empieza en A1
        elsif rising_edge(clk_ph1) then
            if current_state = "111" then
                current_state <= "000";
            else
                current_state <= current_state + 1;
            end if;
        end if;
    end process;

    -- Lógica Combinacional de Salidas
    process(current_state, inst_group, current_frag, disable_ir, ir_in, test_pin)
    begin
        -- Valores por defecto (Seguridad contra latches)
        sync <= '0';
        fase_reloj <= "00";
        ext_dir <= '0'; 
        load_ir_high <= '0';
        load_ir_low <= '0';
        
        acc_load <= '0';
        acc_oe <= '0';
        tmp_load <= '0';
        tmp_oe <= '0';
        
        alu_op <= "101"; -- PASS A por defecto
        alu_b_mux <= '0';
        alu_oe <= '0';
        
        flags_load <= '0';
        flags_oe <= '0';
        
        scratch_we <= '0';
        scratch_pair <= '0';
        scratch_oe <= '0';
        
        stack_oe <= '0';
        stack_up_dn <= '0';
        stack_en <= '0';

        cm_rom_out <= '0';
        
        case current_state is
            -- ===================================================
            -- FASES DE BÚSQUEDA (FETCH)
            -- ===================================================
            when "000" => -- A1
                sync <= '1';
                fase_reloj <= "00";
                stack_oe <= '1';
                ext_dir <= '0';   -- CPU saca dirección al bus (stack → D_bus)
            when "001" => -- A2
                fase_reloj <= "01";
                stack_oe <= '1';
                ext_dir <= '0';
            when "010" => -- A3
                fase_reloj <= "10";
                stack_oe <= '1';
                ext_dir <= '0';
                cm_rom_out <= '1';  -- Activa chip select de la ROM 4001
            when "011" => -- M1: ROM externa pone nibble alto en D_bus
                ext_dir <= '1';     -- Buffer escucha el bus externo
                cm_rom_out <= '1';
                if disable_ir = '0' then
                    load_ir_high <= '1'; -- IR captura nibble alto [7:4] en flanco M1→M2
                end if;
            when "100" => -- M2: ROM externa pone nibble bajo en D_bus
                ext_dir <= '1';
                if disable_ir = '0' then
                    load_ir_low <= '1';  -- IR captura nibble bajo [3:0] en flanco M2→X1
                end if;
                
            -- ===================================================
            -- FASES DE EJECUCIÓN (EXECUTE)
            -- ===================================================
            when "101" => -- X1
                stack_en <= '0';
                
                if current_frag = '0' then -- Primer ciclo (o instrucción de 1 ciclo)
                    -- ADD (1000)
                    if inst_group(8) = '1' then
                        scratch_oe <= '1'; -- Lee registro index
                        tmp_load   <= '1'; -- Guarda en TEMP
                    
                    -- SUB (1001)
                    elsif inst_group(9) = '1' then
                        scratch_oe <= '1'; -- Lee registro index
                        tmp_load   <= '1'; -- Guarda en TEMP
                        
                    -- LD (1010)
                    elsif inst_group(10) = '1' then
                        scratch_oe <= '1'; -- Lee registro index
                        acc_load   <= '1'; -- Carga directa en acumulador
                        
                    -- XCH (1011)
                    elsif inst_group(11) = '1' then
                        scratch_oe <= '1'; -- Lee registro index
                        tmp_load   <= '1'; -- Guarda en TEMP para el swap
                        
                    -- INC (0110)
                    elsif inst_group(6) = '1' then
                        scratch_oe <= '1'; -- El bypass de top-level desvía esto a ALU A
                        
                    -- LDM (1101)
                    elsif inst_group(13) = '1' then
                        acc_load   <= '1'; -- Decoder coloca inmediato en bus, lo cargamos en ACC
                        
                    -- BBL (0111)
                    elsif inst_group(7) = '1' then
                        stack_up_dn <= '1'; -- Pop del stack pointer (restablece nivel anterior)
                        stack_en    <= '1'; -- Ejecuta el pop
                        acc_load    <= '1'; -- Decoder coloca inmediato en bus, lo cargamos en ACC
                        
                    -- FIM (0010 de 2 bytes, 1er ciclo)
                    elsif inst_group(2) = '1' and ir_in(0) = '0' then
                        scratch_pair <= '1'; -- Asegura modo par en el scratchpad
                        
                    -- SRC (0010 de 1 ciclo)
                    elsif inst_group(2) = '1' and ir_in(0) = '1' then
                        scratch_pair <= '1'; -- Modo par activo
                        scratch_oe   <= '1'; -- Envía el registro par de 8 bits al bus externo
                        ext_dir      <= '0'; -- Direcciones van hacia afuera
                        
                    -- E/S y RAM (1110)
                    elsif inst_group(14) = '1' then
                        -- RDR (1110 1010): Lee datos de ROM
                        if ir_in = "11101010" then
                            ext_dir <= '1';   -- Buffer de bus externo lee
                            acc_load <= '1';  -- Carga en acumulador
                        -- WRR (1110 0010): Escribe en ROM
                        elsif ir_in = "11100010" then
                            acc_oe <= '1';    -- Pone acumulador en el bus interno
                            ext_dir <= '0';   -- Envía hacia afuera
                        -- WMP (1110 0001): Escribe en puerto RAM
                        elsif ir_in = "11100001" then
                            acc_oe <= '1';
                            ext_dir <= '0';
                        end if;
                        
                    -- Grupo Acumulador (1111)
                    elsif inst_group(15) = '1' then
                        -- CLB (1111 0000): Limpia ACC y Carry
                        if ir_in(3 downto 0) = "0000" then
                            acc_load   <= '1'; -- Cargará 0000 desde el bus interno
                            flags_load <= '1'; -- Carga Carry con 0
                        -- CLC (1111 0001): Limpia Carry
                        elsif ir_in(3 downto 0) = "0001" then
                            flags_load <= '1'; -- Carga Carry con 0
                        -- CMC (1111 0011): Complementa Carry
                        elsif ir_in(3 downto 0) = "0011" then
                            flags_load <= '1'; -- Carga Carry complementado
                        -- DAA (1111 1011): Decimal Adjust Accumulator
                        elsif ir_in(3 downto 0) = "1011" then
                            alu_op     <= "000"; -- Suma
                            alu_b_mux  <= '1';   -- Selecciona la salida de decimal_adjust en entrada B
                            alu_oe     <= '1';   -- Vuelca suma al bus interno
                            acc_load   <= '1';   -- Guarda corrección en acumulador
                            flags_load <= '1';   -- Actualiza Carry
                        -- TCS (1111 1001): Transfer Carry to Accumulator
                        elsif ir_in(3 downto 0) = "1001" then
                            acc_load   <= '1'; -- Carga valor según Carry (9 o 10) al acumulador
                            flags_load <= '1'; -- Limpia Carry
                        end if;
                    end if;
                    
                else -- Segundo ciclo (current_frag = '1') de instrucciones de 2 bytes
                    
                    -- FIM (0010, 2º ciclo)
                    if inst_group(2) = '1' then
                        scratch_pair <= '1'; -- Escribe en modo par
                        scratch_we   <= '1'; -- Escribe el byte inmediato completo
                        
                    -- JMS (0101, 2º ciclo)
                    elsif inst_group(5) = '1' then
                        stack_up_dn <= '0'; -- Push al stack (SP incrementa)
                        stack_en    <= '1'; -- Ejecuta push
                    end if;
                end if;
                
            when "110" => -- X2
                if current_frag = '0' then -- Primer ciclo (o de 1 ciclo)
                    
                    -- ADD (1000)
                    if inst_group(8) = '1' then
                        alu_op     <= "000";   -- Suma
                        alu_b_mux  <= '0';     -- Usa TEMP reg
                        alu_oe     <= '1';     -- Vuelca al bus
                        acc_load   <= '1';     -- Carga en ACC
                        flags_load <= '1';     -- Carga carry/zero
                        
                    -- SUB (1001)
                    elsif inst_group(9) = '1' then
                        alu_op     <= "001";   -- Resta (A + NOT B + C)
                        alu_b_mux  <= '0';     -- Usa TEMP reg
                        alu_oe     <= '1';     -- Vuelca al bus
                        acc_load   <= '1';     -- Carga en ACC
                        flags_load <= '1';     -- Carga carry/zero
                        
                    -- XCH (1011)
                    elsif inst_group(11) = '1' then
                        -- En X1 pusimos el registro en TEMP.
                        -- En X2 escribimos el acumulador en el registro.
                        acc_oe     <= '1';     -- Acumulador al bus
                        scratch_we <= '1';     -- Escribe en scratchpad
                        
                    -- INC (0110)
                    elsif inst_group(6) = '1' then
                        alu_op     <= "110";   -- Operación INC (A + 1)
                        alu_oe     <= '1';     -- Vuelca al bus
                        scratch_we <= '1';     -- Escribe en scratchpad
                        
                    -- SRC (0010 de 1 ciclo, 2º nibble)
                    elsif inst_group(2) = '1' and ir_in(0) = '1' then
                        scratch_pair <= '1';
                        scratch_oe   <= '1';
                        ext_dir      <= '0';
                    end if;
                end if;
                
            when "111" => -- X3
                -- En X3 finalizamos la instrucción actualizando el PC activo.
                -- Ponemos stack_en a '1' para escribir el nuevo PC (ya calculado como PC+1 o dirección de salto)
                stack_en <= '1';
                
                if current_frag = '0' then
                    -- XCH (1011): fase final del swap
                    if inst_group(11) = '1' then
                        -- En X3 leemos el valor guardado en TEMP y lo metemos al acumulador.
                        tmp_oe   <= '1'; -- TEMP al bus
                        acc_load <= '1'; -- Carga en acumulador
                    end if;
                end if;
                
            when others =>
                null;
        end case;
    end process;
    
end Behavioral;
