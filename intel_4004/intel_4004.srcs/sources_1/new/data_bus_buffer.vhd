library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.pkg_4004.all;

entity data_bus_buffer is
    Port (
        internal_bus_in  : in  STD_LOGIC_VECTOR(BUS_W-1 downto 0);
        internal_bus_out : out STD_LOGIC_VECTOR(BUS_W-1 downto 0);
        dir_out          : in  STD_LOGIC; -- '1'=Sacar datos, '0'=Leer datos
        data_bus_ext     : inout STD_LOGIC_VECTOR(BUS_W-1 downto 0)
    );
end data_bus_buffer;

architecture Tristate of data_bus_buffer is
begin
    -- Lectura constante hacia el interior
    internal_bus_out <= data_bus_ext;

    -- Aislamiento tri-estado hacia el exterior:
    -- dir_out = '0' -> CPU escribe hacia afuera (PC en A1-A3, escrituras)
    -- dir_out = '1' -> CPU se pone en alta impedancia (M1-M2, lecturas) para escuchar a la ROM/RAM
    data_bus_ext <= internal_bus_in when (dir_out = '0') else (others => 'Z');
end Tristate;