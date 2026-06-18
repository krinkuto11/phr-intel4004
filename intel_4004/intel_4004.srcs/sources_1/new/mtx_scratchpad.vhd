----------------------------------------------------------------------------------
-- Multiplexor 16:1 de nibbles para el scratchpad
-- Recibe las salidas Q de los 16 registros de 4 bits y propaga al bus el nibble
-- del registro apuntado por 'sel'.
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity mtx_scratchpad is
        Port(
            i0, i1, i2 : in std_logic_vector (3 downto 0);
            i3, i4 : in std_logic_vector (3 downto 0);
            i5, i6, i7 : in std_logic_vector (3 downto 0);
            i8, i9,i10 : in std_logic_vector (3 downto 0);
            i11, i12, i13, i14, i15 : in std_logic_vector (3 downto 0);
            sel : in std_logic_vector (3 downto 0);
            y   : out std_logic_vector (3 downto 0)
        );
end entity;


architecture Flujodatos of mtx_scratchpad is
signal reg_activo : std_logic_vector(3 downto 0);
begin

    y <= reg_activo;

    -- Multiplexor 16:1: propaga el nibble del registro apuntado por sel
    process(sel, i0, i1, i2, i3, i4, i5, i6,i7,i8,i9,i10,i11,i12,i13, i14, i15)
    begin
        if    sel = "0000" then reg_activo <= i0;
        elsif sel = "0001" then reg_activo <= i1;
        elsif sel = "0010" then reg_activo <= i2;
        elsif sel = "0011" then reg_activo <= i3;
        elsif sel = "0100" then reg_activo <= i4;
        elsif sel = "0101" then reg_activo <= i5;
        elsif sel = "0110" then reg_activo <= i6;
        elsif sel = "0111" then reg_activo <= i7;
        elsif sel = "1000" then reg_activo <= i8;
        elsif sel = "1001" then reg_activo <= i9;
        elsif sel = "1010" then reg_activo <= i10;
        elsif sel = "1011" then reg_activo <= i11;
        elsif sel = "1100" then reg_activo <= i12;
        elsif sel = "1101" then reg_activo <= i13;
        elsif sel = "1110" then reg_activo <= i14;
        elsif sel = "1111" then reg_activo <= i15;
        else  reg_activo <= (others => 'X');
        end if;
    end process;
end Flujodatos;
