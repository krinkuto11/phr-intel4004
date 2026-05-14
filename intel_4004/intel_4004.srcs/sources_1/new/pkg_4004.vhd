----------------------------------------------------------------------------------
-- Paquete global del procesador Intel 4004
-- Contiene definiciones de tipos y constantes utilizadas en todo el diseño.
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

package pkg_4004 is

    -- Ancho del bus de datos interno
    constant BUS_W : integer := 4;
    
    -- Valor constante para inicializaciones o placeholders en el bus
    constant BUS_CERO : std_logic_vector(BUS_W-1 downto 0) := "0000";

    -- Valor constante para colisiones de bus
    constant BUS_ERROR : std_logic_vector(BUS_W-1 downto 0) := "XXXX";

end package pkg_4004;

package body pkg_4004 is
    -- Vacio por ahora, aqui irian las implementaciones de subprogramas si las hubiera
end package body pkg_4004;
