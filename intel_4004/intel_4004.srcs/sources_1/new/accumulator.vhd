----------------------------------------------------------------------------------
-- Acumulador de 4 bits
-- Almacena el operando A de la ALU y recibe el resultado de cada operación.
-- Es un registro_4b con la interfaz renombrada para mayor claridad en el datapath.
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity accumulator is
    Port (
        clk      : in  STD_LOGIC;
        reset    : in  STD_LOGIC;
        load_en  : in  STD_LOGIC;
        d_in     : in  STD_LOGIC_VECTOR(3 downto 0);
        q_out    : out STD_LOGIC_VECTOR(3 downto 0)
    );
end accumulator;

architecture Structural of accumulator is
begin
    -- Reutilizamos nuestro componente estándar de 4 bits
    inst_reg: entity work.registro_4b
        port map (
            clk   => clk,
            R     => reset,
            E     => load_en,
            D_in  => d_in,
            Q_out => q_out
        );
end Structural;
