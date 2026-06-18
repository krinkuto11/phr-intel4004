----------------------------------------------------------------------------------
-- Registro de 12 bits con enable síncrono y reset asíncrono
-- Se usa como cada uno de los niveles del stack de direcciones del PC.
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity registro_12b is
    Port ( 
        E     : in std_logic;
        clk   : in std_logic;
        R     : in std_logic;
        D_in  : in std_logic_vector(11 downto 0);
        Q_out : out std_logic_vector(11 downto 0) 
    );
end registro_12b;

architecture Structural of registro_12b is
begin
    Block_FF : for i in 0 to 11 generate
        FF : entity work.d_ff_en 
            port map (
                clk   => clk,
                reset => R,
                en    => E,
                d     => D_in(i),
                q     => Q_out(i)
            );
    end generate;
end Structural;