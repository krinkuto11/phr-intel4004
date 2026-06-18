----------------------------------------------------------------------------------
-- Biestable D con enable síncrono y reset asíncrono
-- Componente básico a partir del cual se construyen todos los registros del diseño.
-- Reset asíncrono activo a nivel alto; captura el dato sólo cuando en='1'.
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.pkg_4004.all;

entity d_ff_en is
    Port ( 
        clk    : in  STD_LOGIC;
        reset  : in  STD_LOGIC;
        en     : in  STD_LOGIC;
        d      : in  STD_LOGIC;
        q      : out STD_LOGIC
    );
end d_ff_en;

architecture Behavioral of d_ff_en is
begin
    process(clk, reset)
    begin
        if reset = '1' then
            q <= '0';
        elsif rising_edge(clk) then
            if en = '1' then
                q <= d;
            end if;
        end if;
    end process;
end Behavioral;
