library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.pkg_4004.all;

entity stub_componente is
    Port (
        -- Le pasamos un valor fijo de prueba genérico para saber quién está hablando
        valor_de_prueba : in  STD_LOGIC_VECTOR(BUS_W-1 downto 0);
        
        bus_in          : in  STD_LOGIC_VECTOR(BUS_W-1 downto 0);
        bus_out         : out STD_LOGIC_VECTOR(BUS_W-1 downto 0);
        write_en        : in  STD_LOGIC
    );
end stub_componente;

architecture simulacion of stub_componente is
begin
    -- El componente falso ignora el reloj y el bus_in.
    -- Solo obedece a tu regla estricta de aislamiento de salida.
    bus_out <= valor_de_prueba when (write_en = '1') else BUS_CERO;
end simulacion;