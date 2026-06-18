----------------------------------------------------------------------------------
-- Registro de Instrucción (IR)
-- Almacena el byte de instrucción de 8 bits, capturándolo en dos nibbles:
-- la parte alta durante la fase M1 y la parte baja durante M2.
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.pkg_4004.all;

entity instruction_register is
    Port (
        clk         : in  STD_LOGIC;
        reset       : in  STD_LOGIC;
        load_high   : in  STD_LOGIC; -- Activo en fase M1
        load_low    : in  STD_LOGIC; -- Activo en fase M2
        bus_in      : in  STD_LOGIC_VECTOR(BUS_W-1 downto 0); -- 4 bits
        instr_out   : out STD_LOGIC_VECTOR(7 downto 0)         -- 8 bits
    );
end instruction_register;

architecture Structural of instruction_register is
    signal instr_out_int : STD_LOGIC_VECTOR(7 downto 0);
begin

    instr_out <= instr_out_int;

    -- PARTE ALTA: Captura los 4 bits del bus y los pone en instr_out(7..4)
    gen_high: for i in 0 to 3 generate
        bit_high: entity work.d_ff_en 
            port map (
                clk   => clk,
                reset => reset,
                en    => load_high,
                d     => bus_in(i),
                q     => instr_out_int(i+4)
            );
    end generate;

    -- PARTE BAJA: Captura los 4 bits del bus y los pone en instr_out(3..0)
    gen_low: for i in 0 to 3 generate
        bit_low: entity work.d_ff_en 
            port map (
                clk   => clk,
                reset => reset,
                en    => load_low,
                d     => bus_in(i),
                q     => instr_out_int(i)
            );
    end generate;

end Structural;
