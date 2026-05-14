library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.pkg_4004.all;

entity alu is
    Port (
        -- Operandos
        A_in        : in  STD_LOGIC_VECTOR(BUS_W-1 downto 0);
        B_in        : in  STD_LOGIC_VECTOR(BUS_W-1 downto 0);
        carry_in    : in  STD_LOGIC;

        -- Control de operación
        op          : in  STD_LOGIC_VECTOR(2 downto 0);

        -- Salidas de estado (Flags)
        result_out  : out STD_LOGIC_VECTOR(BUS_W-1 downto 0);
        carry_out   : out STD_LOGIC;
        zero_flag   : out STD_LOGIC
    );
end alu;

architecture Combinational of alu is
    signal sum_result   : STD_LOGIC_VECTOR(BUS_W downto 0);
    signal sub_result   : STD_LOGIC_VECTOR(BUS_W downto 0);
    signal inc_result   : STD_LOGIC_VECTOR(BUS_W downto 0);
    
    signal resultado_interno : STD_LOGIC_VECTOR(BUS_W-1 downto 0);
    signal carry_interno     : STD_LOGIC;
    signal B_neg             : STD_LOGIC_VECTOR(BUS_W-1 downto 0);

begin

    -- 1. SUMA: A + B + Carry
    sum_result <= STD_LOGIC_VECTOR(
        ('0' & unsigned(A_in)) + ('0' & unsigned(B_in)) + ("0000" & carry_in)
    );

    -- 2. RESTA AUTÉNTICA 4004: A + NOT(B) + Carry
    B_neg      <= NOT B_in;
    sub_result <= STD_LOGIC_VECTOR(
        ('0' & unsigned(A_in)) + ('0' & unsigned(B_neg)) + ("0000" & carry_in)
    );

    -- 3. INCREMENTO: A + 1
    inc_result <= STD_LOGIC_VECTOR(('0' & unsigned(A_in)) + 1);

    -- 4. SELECTOR DE OPERACIÓN (Multiplexor)
    process(op, A_in, B_in, carry_in, sum_result, sub_result, inc_result)
    begin
        case op is
            when "000" =>  -- ADD
                resultado_interno <= sum_result(BUS_W-1 downto 0);
                carry_interno     <= sum_result(BUS_W);

            when "001" =>  -- SUB
                resultado_interno <= sub_result(BUS_W-1 downto 0);
                carry_interno     <= sub_result(BUS_W);

            when "010" =>  -- AND
                resultado_interno <= A_in AND B_in;
                carry_interno     <= carry_in;

            when "011" =>  -- OR
                resultado_interno <= A_in OR B_in;
                carry_interno     <= carry_in;

            when "100" =>  -- XOR
                resultado_interno <= A_in XOR B_in;
                carry_interno     <= carry_in;

            when "101" =>  -- PASS A
                resultado_interno <= A_in;
                carry_interno     <= carry_in;

            when "110" =>  -- INC
                resultado_interno <= inc_result(BUS_W-1 downto 0);
                carry_interno     <= inc_result(BUS_W);

            when others => -- Default: PASS A
                resultado_interno <= A_in;
                carry_interno     <= carry_in;
        end case;
    end process;

    result_out <= resultado_interno;
    carry_out  <= carry_interno;
    zero_flag  <= '1' when resultado_interno = "0000" else '0';

end Combinational;
