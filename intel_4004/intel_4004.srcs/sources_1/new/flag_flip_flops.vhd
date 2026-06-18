library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.pkg_4004.all;

entity flag_flip_flops is
    Port (
        clk       : in  STD_LOGIC;
        reset     : in  STD_LOGIC;
        
        -- Activo cuando la unidad de control indica que hay que actualizar las banderas
        load_en   : in  STD_LOGIC;
        
        -- Entrada de datos (puede venir del bus o de la ALU)
        d_in      : in  STD_LOGIC_VECTOR(BUS_W-1 downto 0);
        
        -- Salida de los flags
        q_out     : out STD_LOGIC_VECTOR(BUS_W-1 downto 0);
        
        -- Habilitación de salida al bus (gestionada por Timing & Control)
        flags_oe  : out STD_LOGIC
    );
end flag_flip_flops;

architecture Structural of flag_flip_flops is
    -- No necesitamos declarar el componente si usamos 'entity work'
begin

    -- La habilitación la gestiona Timing & Control; el FF la fuerza a '0' como punto seguro de reset
    flags_oe <= '0';

    -- Generamos los 4 biestables de estado
    -- Bit 0 suele ser CARRY
    -- Bit 1 suele ser TEST
    -- Bits 2 y 3 pueden ser flags auxiliares
    gen_flags: for i in 0 to BUS_W-1 generate
        flag_bit: entity work.d_ff_en 
            port map (
                clk   => clk,
                reset => reset,
                en    => load_en,
                d     => d_in(i),
                q     => q_out(i)
            );
    end generate;

end Structural;
