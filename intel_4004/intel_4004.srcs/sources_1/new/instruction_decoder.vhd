----------------------------------------------------------------------------------
-- Decodificador de Instrucciones
-- Recibe el byte de instrucción de 8 bits desde el IR y genera señales de control
-- combinacionales para Timing & Control. Mapea el nibble alto (opcode principal) a
-- un bus One-Hot 'inst_group(15:0)' e identifica las instrucciones de 2 bytes
-- (JUN, JMS, JCN, FIM) para su ejecución en 2 ciclos de máquina.
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.pkg_4004.all;

entity instruction_decoder is
    Port (
        ir_in          : in  STD_LOGIC_VECTOR(7 downto 0); -- Byte de instrucción actual
        
        -- Grupo de instrucciones mapeado One-Hot a Timing & Control (16 bits)
        inst_group     : out STD_LOGIC_VECTOR(15 downto 0);
        
        -- Indicadores específicos de instrucción
        is_2byte       : out STD_LOGIC;  -- Habilitación de 2 ciclos (JUN, JMS, JCN, FIM)

        -- Salida hacia el bus interno (para cargas inmediatas: LDM, BBL)
        bus_out        : out STD_LOGIC_VECTOR(BUS_W-1 downto 0);
        out_en         : out STD_LOGIC
    );
end instruction_decoder;

architecture Combinational of instruction_decoder is
    signal op_high : STD_LOGIC_VECTOR(3 downto 0);
    signal op_low  : STD_LOGIC_VECTOR(3 downto 0);
begin

    op_high <= ir_in(7 downto 4);
    op_low  <= ir_in(3 downto 0);

    -- 1. Decodificación One-Hot del nibble alto (Opcodes 0 a 15)
    process(op_high)
    begin
        inst_group <= (others => '0');
        case op_high is
            when "0000" => inst_group(0)  <= '1'; -- NOP y grupo 0000
            when "0001" => inst_group(1)  <= '1'; -- JCN
            when "0010" => inst_group(2)  <= '1'; -- FIM / SRC
            when "0011" => inst_group(3)  <= '1'; -- FIN / OPR
            when "0100" => inst_group(4)  <= '1'; -- JUN
            when "0101" => inst_group(5)  <= '1'; -- JMS
            when "0110" => inst_group(6)  <= '1'; -- INC
            when "0111" => inst_group(7)  <= '1'; -- BBL
            when "1000" => inst_group(8)  <= '1'; -- ADD
            when "1001" => inst_group(9)  <= '1'; -- SUB
            when "1010" => inst_group(10) <= '1'; -- LD
            when "1011" => inst_group(11) <= '1'; -- XCH
            when "1100" => inst_group(12) <= '1'; -- Sin uso / Reservado
            when "1101" => inst_group(13) <= '1'; -- LDM
            when "1110" => inst_group(14) <= '1'; -- E/S y RAM (WRR, RDR, WMP, etc.)
            when "1111" => inst_group(15) <= '1'; -- Grupo de acumulador (CLB, CLC, DAA, TCS, etc.)
            when others => null;
        end case;
    end process;

    -- 2. Detección de instrucciones de 2 bytes (2 ciclos de máquina)
    --   - JCN: 0x1X
    --   - FIM: 0x2X cuando el último bit es '0' (0x20, 0x22, 0x24, etc.)
    --   - JUN: 0x4X
    --   - JMS: 0x5X
    is_2byte <= '1' when (op_high = "0001") or 
                         (op_high = "0100") or 
                         (op_high = "0101") or 
                         (op_high = "0010" and ir_in(0) = '0') 
                   else '0';

    -- 3. Carga de datos inmediatos (para LDM y BBL)
    bus_out <= op_low;
    out_en  <= '1' when (op_high = "1101" or op_high = "0111") else '0';

end Combinational;
