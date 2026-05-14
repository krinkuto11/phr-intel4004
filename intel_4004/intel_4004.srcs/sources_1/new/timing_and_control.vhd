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
    process(current_state, inst_group, current_frag, disable_ir)
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
                if current_frag = '0' then
                    -- Ejemplo Plantilla: ADD (1000)
                    if inst_group(8) = '1' then
                        scratch_oe <= '1'; -- Lee el registro del scratch pad
                        tmp_load <= '1';   -- Lo guarda en el temp register
                    end if;
                end if;
                
            when "110" => -- X2
                if current_frag = '0' then
                    -- Ejemplo Plantilla: ADD (1000)
                    if inst_group(8) = '1' then
                        alu_op <= "000";   -- Operación suma
                        alu_b_mux <= '0';  -- Usa temp register en la entrada B
                        alu_oe <= '1';     -- Vuelca resultado al bus
                        acc_load <= '1';   -- Guarda en Acumulador
                        flags_load <= '1'; -- Actualiza los flags
                    end if;
                end if;
                
            when "111" => -- X3
                -- Fase final de ejecución. Aquí suelen ir saltos, escritura en RAM, etc.
                null;
                
            when others =>
                null;
        end case;
    end process;
    
end Behavioral;
