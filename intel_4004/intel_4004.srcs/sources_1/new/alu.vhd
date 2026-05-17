library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.pkg_4004.all;

entity alu is
    Port (
        A_in        : in  STD_LOGIC_VECTOR(BUS_W-1 downto 0);
        B_in        : in  STD_LOGIC_VECTOR(BUS_W-1 downto 0);
        carry_in    : in  STD_LOGIC;

        op          : in  STD_LOGIC_VECTOR(3 downto 0);

        result_out  : out STD_LOGIC_VECTOR(BUS_W-1 downto 0);
        carry_out   : out STD_LOGIC;
        zero_flag   : out STD_LOGIC
    );
end alu;

-- ALU op codes (4 bits):
--   0000=ADD    A+B+CY
--   0001=SUB    A+NOT(B)+CY  (ones-complement, authentic 4004)
--   0010=AND    A AND B
--   0011=OR     A OR B
--   0100=XOR    A XOR B
--   0101=PASS_A A
--   0110=INC    A+1
--   0111=DEC    A-1  (carry_out=1 si no hay borrow, 0 si borrow)
--   1000=NOT_A  NOT A
--   1001=RAL    rotate left:  result={A[2:0],CY}, carry_out=A[3]
--   1010=RAR    rotate right: result={CY,A[3:1]}, carry_out=A[0]
--   1111=ZERO   result=0000, carry_out=0
--   otros=PASS_A

architecture Combinational of alu is
    signal sum_result : STD_LOGIC_VECTOR(BUS_W downto 0);
    signal sub_result : STD_LOGIC_VECTOR(BUS_W downto 0);
    signal inc_result : STD_LOGIC_VECTOR(BUS_W downto 0);
    signal dec_result : STD_LOGIC_VECTOR(BUS_W downto 0);
    signal B_neg      : STD_LOGIC_VECTOR(BUS_W-1 downto 0);

    signal resultado_interno : STD_LOGIC_VECTOR(BUS_W-1 downto 0);
    signal carry_interno     : STD_LOGIC;
begin

    B_neg      <= NOT B_in;

    sum_result <= STD_LOGIC_VECTOR(
        ('0' & unsigned(A_in)) + ('0' & unsigned(B_in)) + ("0000" & carry_in));

    sub_result <= STD_LOGIC_VECTOR(
        ('0' & unsigned(A_in)) + ('0' & unsigned(B_neg)) + ("0000" & carry_in));

    inc_result <= STD_LOGIC_VECTOR(('0' & unsigned(A_in)) + 1);

    -- DEC: A + 15 = A - 1 (mod 16). carry_out=1 si A>=1 (no borrow)
    dec_result <= STD_LOGIC_VECTOR(('0' & unsigned(A_in)) + "01111");

    process(op, A_in, B_in, carry_in, sum_result, sub_result, inc_result, dec_result)
    begin
        case op is
            when "0000" =>  -- ADD
                resultado_interno <= sum_result(BUS_W-1 downto 0);
                carry_interno     <= sum_result(BUS_W);

            when "0001" =>  -- SUB
                resultado_interno <= sub_result(BUS_W-1 downto 0);
                carry_interno     <= sub_result(BUS_W);

            when "0010" =>  -- AND
                resultado_interno <= A_in AND B_in;
                carry_interno     <= carry_in;

            when "0011" =>  -- OR
                resultado_interno <= A_in OR B_in;
                carry_interno     <= carry_in;

            when "0100" =>  -- XOR
                resultado_interno <= A_in XOR B_in;
                carry_interno     <= carry_in;

            when "0101" =>  -- PASS_A
                resultado_interno <= A_in;
                carry_interno     <= carry_in;

            when "0110" =>  -- INC
                resultado_interno <= inc_result(BUS_W-1 downto 0);
                carry_interno     <= inc_result(BUS_W);

            when "0111" =>  -- DEC
                resultado_interno <= dec_result(BUS_W-1 downto 0);
                carry_interno     <= dec_result(BUS_W);

            when "1000" =>  -- NOT_A
                resultado_interno <= NOT A_in;
                carry_interno     <= carry_in;

            when "1001" =>  -- RAL: rotate left through carry
                resultado_interno <= A_in(2 downto 0) & carry_in;
                carry_interno     <= A_in(3);

            when "1010" =>  -- RAR: rotate right through carry
                resultado_interno <= carry_in & A_in(3 downto 1);
                carry_interno     <= A_in(0);

            when "1111" =>  -- ZERO
                resultado_interno <= "0000";
                carry_interno     <= '0';

            when others =>  -- PASS_A (default)
                resultado_interno <= A_in;
                carry_interno     <= carry_in;
        end case;
    end process;

    result_out <= resultado_interno;
    carry_out  <= carry_interno;
    zero_flag  <= '1' when resultado_interno = "0000" else '0';

end Combinational;
