library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity stack_3L is
    Port (
        Clk_s   : in  std_logic;
        sp_clk  : in  std_logic;                      -- Reloj exclusivo para el puntero de pila
        U_D_s   : in  std_logic;                      -- up/down para el stack pointer
        D_12_s  : in  std_logic_vector(11 downto 0);  -- dato de entrada (nueva dirección)
        E_s     : in  std_logic;                      -- enable escritura en registro activo
        R_s     : in  std_logic;                      -- reset global
        oe_s    : in  std_logic;                      -- output enable hacia el bus
        fase_s  : in  std_logic_vector(1 downto 0);   -- fase del reloj para serializar
        sal_4_stck : out std_logic_vector(3 downto 0); -- hacia el bus interno
        PC_out  : out std_logic_vector(11 downto 0)   -- valor del PC actual (12 bits)
    );
end stack_3L;

architecture Structural of stack_3L is
    component registro_12b is
        Port (
            E     : in  std_logic;
            clk   : in  std_logic;
            R     : in  std_logic;
            D_in  : in  std_logic_vector(11 downto 0);
            Q_out : out std_logic_vector(11 downto 0)
        );
    end component;
    for all: registro_12b use entity work.registro_12b(Structural);

    component puntero_stack is
        Port (
            clk     : in  std_logic;
            up_down : in  std_logic;
            q1, q0  : out std_logic
        );
    end component;
    for all: puntero_stack use entity work.puntero_stack(structural);

    component mtx_stack is
        Port (
            clk    : in  std_logic;
            i0, i1, i2, i3 : in  std_logic_vector(11 downto 0);
            sel    : in  std_logic_vector(1 downto 0);
            oe     : in  std_logic;
            fase   : in  std_logic_vector(1 downto 0);
            y      : out std_logic_vector(3 downto 0)
        );
    end component;
    for all: mtx_stack use entity work.mtx_stack(FlujoDatos);
    signal sp_q1, sp_q0    : std_logic;
    signal sel_sp           : std_logic_vector(1 downto 0);
    signal q_reg0, q_reg1,
           q_reg2, q_reg3  : std_logic_vector(11 downto 0);
    signal en_reg0, en_reg1,
           en_reg2, en_reg3 : std_logic;

begin

    SP : puntero_stack
        port map (
            clk     => sp_clk,
            up_down => U_D_s,
            q1      => sp_q1,
            q0      => sp_q0
        );

    sel_sp <= sp_q1 & sp_q0;
    en_reg0 <= E_s when sel_sp = "00" else '0';
    en_reg1 <= E_s when sel_sp = "01" else '0';
    en_reg2 <= E_s when sel_sp = "10" else '0';
    en_reg3 <= E_s when sel_sp = "11" else '0';
    REG0 : registro_12b
        port map (
            clk   => Clk_s,
            R     => R_s,
            E     => en_reg0,
            D_in  => D_12_s,
            Q_out => q_reg0
        );

    -- Nivel 1
    REG1 : registro_12b
        port map (
            clk   => Clk_s,
            R     => R_s,
            E     => en_reg1,
            D_in  => D_12_s,
            Q_out => q_reg1
        );

    -- Nivel 2
    REG2 : registro_12b
        port map (
            clk   => Clk_s,
            R     => R_s,
            E     => en_reg2,
            D_in  => D_12_s,
            Q_out => q_reg2
        );

    -- Nivel 3
    REG3 : registro_12b
        port map (
            clk   => Clk_s,
            R     => R_s,
            E     => en_reg3,
            D_in  => D_12_s,
            Q_out => q_reg3
        );

    MUX : mtx_stack
        port map (
            clk  => Clk_s,
            i0   => q_reg0,
            i1   => q_reg1,
            i2   => q_reg2,
            i3   => q_reg3,
            sel  => sel_sp,
            oe   => oe_s,
            fase => fase_s,
            y    => sal_4_stck
        );

    -- Salida del PC de 12 bits seleccionado por el puntero de pila (SP)
    PC_out <= q_reg0 when sel_sp = "00" else
              q_reg1 when sel_sp = "01" else
              q_reg2 when sel_sp = "10" else
              q_reg3;

end Structural;