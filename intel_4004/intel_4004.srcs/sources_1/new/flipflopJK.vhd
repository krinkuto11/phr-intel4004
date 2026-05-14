library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
entity flipflopJK is
    Port(j,k,r : in std_logic;
    clk : in std_logic;
    q, notq : out std_logic);
end flipflopJK;

architecture FlujoDatos of flipflopJK is
signal q_aux : std_logic;
begin
q <= q_aux;
notq <= not q_aux;
process(clk, r)
begin
if(r = '1') then
    q_aux <= '0';
elsif(clk = '1' and clk'event) then 
    if( j = '0' and k = '1')then
        q_aux <= '0';
    elsif (j = '1' and k = '0') then 
        q_aux <= '1';
    elsif (j = '1' and k = '1') then 
        q_aux <= not q_aux;
    end if;
end if; 
end process;
end FlujoDatos;
