library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity decimal_adjust is
    Port (
        acc_in   : in  STD_LOGIC_VECTOR(3 downto 0);
        carry_in : in  STD_LOGIC;
        adj_out  : out STD_LOGIC_VECTOR(3 downto 0)
    );
end decimal_adjust;

architecture Combinational of decimal_adjust is
begin
    process(acc_in, carry_in)
    begin
        if (carry_in = '1' or unsigned(acc_in) > 9) then
            adj_out <= "0110";
        else
            adj_out <= "0000";
        end if;
    end process;
end Combinational;
