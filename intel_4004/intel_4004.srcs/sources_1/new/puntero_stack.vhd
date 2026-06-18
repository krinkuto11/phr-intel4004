----------------------------------------------------------------------------------
-- Puntero de pila: contador de 2 bits up/down
-- Implementado con dos biestables JK en modo toggle (J=K=1) conectados en ripple.
-- La entidad auxiliar clk_up_down selecciona Q o /Q del primer FF como reloj del
-- segundo, lo que invierte el sentido del conteo sin lógica adicional.
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity puntero_stack is
  Port (clk, up_down: in std_logic;
  q1,q0 : out std_logic);
end puntero_stack;



library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
entity clk_up_down is
    Port(qi, notqi, up_down_select : in std_logic;
    salida : out std_logic);
end clk_up_down;
-- Al contar hacia arriba, el reloj del segundo FF toma el flanco de Q del primero (q).
-- Al contar hacia abajo, lo toma de NOT(Q) (notq). Así se invierte el sentido del ripple.
architecture clk_add of clk_up_down is
signal not_updown : std_logic;
begin
    not_updown <= not up_down_select;
    salida <= (qi and up_down_select) or (notqi and not_updown);
end clk_add;

architecture structural of puntero_stack is
    component flipflopJK is
        Port (j,k,r,clk: in std_logic ; q, notq : out std_logic );
    end component;
    component clk_up_down is
        Port(qi, notqi, up_down_select : in std_logic;
        salida : out std_logic);
    end component;   
    signal reset : std_logic;
    signal s_clk_mas_1 : std_logic;
    signal uno : std_logic := '1';
     signal cero : std_logic := '0';
    signal q_uno, notq_uno, q_dos, notq_dos: std_logic;
begin
    b1: flipflopJK port map (j => uno,k=> uno, r=> cero, clk => clk, q => q_uno, notq => notq_uno);
    clk_incremento : clk_up_down port map (qi => q_uno, notqi => notq_uno, up_down_select => up_down, salida => s_clk_mas_1);
    b2: flipflopJK port map (j => uno,k=> uno, r => cero , clk => s_clk_mas_1, q => q_dos, notq => notq_dos);
    q1 <= q_uno;
    q0 <= q_dos;
end structural;
