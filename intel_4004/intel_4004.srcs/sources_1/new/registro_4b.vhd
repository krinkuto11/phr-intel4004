----------------------------------------------------------------------------------
-- Registro de 4 bits con enable síncrono y reset asíncrono
-- Instancia cuatro d_ff_en en paralelo. Es la base del acumulador, del registro
-- temporal y de cada celda del scratchpad.
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity registro_4b is
    Port ( 
        E     : in std_logic;
        clk   : in std_logic;
        R     : in std_logic;
        D_in  : in std_logic_vector(3 downto 0);
        Q_out : out std_logic_vector(3 downto 0) 
    );
end registro_4b;

architecture Structural of registro_4b is
begin
    Block_FF : for i in 0 to 3 generate
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