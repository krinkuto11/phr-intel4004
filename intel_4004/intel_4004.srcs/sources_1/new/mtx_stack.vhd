library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity mtx_stack is
    Port (
        clk    : in  std_logic;
        i0, i1, i2, i3 : in  std_logic_vector(11 downto 0);
        sel    : in  std_logic_vector(1 downto 0);   -- Stack Pointer
        oe     : in  std_logic;                       -- '1' durante A1,A2,A3
        fase   : in  std_logic_vector(1 downto 0);   -- "00"=A1 "01"=A2 "10"=A3
        y      : out std_logic_vector(3 downto 0)    -- salida serializada al bus
    );
end mtx_stack;

architecture FlujoDatos of mtx_stack is
    signal reg_activo : std_logic_vector(11 downto 0);
begin

    -- Selección del registro activo (igual que antes)
    process(sel, i0, i1, i2, i3)
    begin
        if    sel = "00" then reg_activo <= i0;
        elsif sel = "01" then reg_activo <= i1;
        elsif sel = "10" then reg_activo <= i2;
        elsif sel = "11" then reg_activo <= i3;
        else  reg_activo <= (others => 'X');
        end if;
    end process;

    -- Serialización: saca un nibble por ciclo según la fase
    process(clk)
    begin
        if rising_edge(clk) then
            if oe = '1' then
                case fase is
                    when "00" => y <= reg_activo(3  downto 0);   -- A1: nibble bajo
                    when "01" => y <= reg_activo(7  downto 4);   -- A2: nibble medio
                    when "10" => y <= reg_activo(11 downto 8);   -- A3: nibble alto
                    when others => y <= (others => 'X');
                end case;
            else
                y <= (others => '0');  -- bus en ceros cuando no es nuestro turno
            end if;
        end if;
    end process;

end FlujoDatos;