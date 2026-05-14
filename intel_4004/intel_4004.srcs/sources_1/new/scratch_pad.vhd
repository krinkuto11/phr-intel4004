-- =============================================================
--  Intel 4004 - Scratchpad
--  Archivo : scratch_pad.vhd
--
--  Arquitectura: Structural
--
--  16 registros de 4 bits instanciados mediante GENERATE.
--  Un multiplexor 16:1 selecciona la salida del registro activo.
--  El decodificador de enable activa solo el registro apuntado
--  por 'address' cuando w_e = '1'.
-- =============================================================
library IEEE;
use IEEE.NUMERIC_STD.ALL;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
 
-- -------------------------------------------------------------
entity scratch_pad is
    port (
        clk_r    : in  std_logic;
        rst_r    : in  std_logic;
        w_e      : in  std_logic;                      -- write enable
        pair_mode : in  std_logic;                     -- '1' = modo par (RRn), '0' = modo individual
        address   : in  std_logic_vector(3 downto 0); -- dirección (0-15 individual | 0-7 par → RR0,RR2,...RR14)
        data_in   : in  std_logic_vector(7 downto 0); -- dato a escribir (8 bits; [3:0] en modo individual)
        data_out  : out std_logic_vector(7 downto 0)  -- dato leído     (8 bits; [3:0] en modo individual)
    );
end entity scratch_pad;
 
-- -------------------------------------------------------------
architecture Structural of scratch_pad is
 
    -- ----------------------------------------------------------
    -- Componente: registro de 4 bits con enable y reset
    -- ----------------------------------------------------------
    component registro_4b is
        port (
            clk   : in  std_logic;
            R     : in  std_logic;
            E     : in  std_logic;
            D_in  : in  std_logic_vector(3 downto 0);
            Q_out : out std_logic_vector(3 downto 0)
        );
    end component;
    for all : registro_4b use entity work.registro_4b(Structural);
 
    -- ----------------------------------------------------------
    -- Componente: multiplexor 16:1 de nibbles
    -- ----------------------------------------------------------
    component mtx_scratchpad is
        port (
            i0, i1, i2,  i3,  i4,  i5,  i6,  i7  : in  std_logic_vector(3 downto 0);
            i8, i9, i10, i11, i12, i13, i14, i15  : in  std_logic_vector(3 downto 0);
            sel                                     : in  std_logic_vector(3 downto 0);
            y                                       : out std_logic_vector(3 downto 0)
        );
    end component;
    for all : mtx_scratchpad use entity work.mtx_scratchpad(FlujoDatos);
    type nibble_array is array (0 to 15) of std_logic_vector(3 downto 0);
    signal q_regs  : nibble_array;
 
    -- Enable individual para cada registro
    signal en_regs : std_logic_vector(15 downto 0);
 
    -- Dirección del registro par base y del impar correspondiente
    -- En modo par: address[3:1] selecciona el par (0-7)
    --              reg_even = address[3:1] & '0'
    --              reg_odd  = address[3:1] & '1'
    signal reg_even : integer range 0 to 14;  -- índice par  (0,2,4,...,14)
    signal reg_odd  : integer range 1 to 15;  -- índice impar(1,3,5,...,15)
 
    -- Dirección completa para modo individual (0-15)
    signal addr_int : integer range 0 to 15;
 
    -- Salidas del mux para modo individual
    signal mux_out  : std_logic_vector(3 downto 0);
 
    -- Dirección efectiva para el mux en modo individual
    signal mux_sel  : std_logic_vector(3 downto 0);
    signal din_even : std_logic_vector(3 downto 0);
 
begin
 
    -- ----------------------------------------------------------
    -- Cálculo de índices
    -- ----------------------------------------------------------
    addr_int <= to_integer(unsigned(address));
    din_even <= data_in(7 downto 4) when pair_mode = '1' else data_in(3 downto 0);
 
    -- En modo par: address[3:1] da el número de par (0-7)
    --             → reg_even = par*2,  reg_odd = par*2+1
    reg_even <= to_integer(unsigned(address(3 downto 1))) * 2;
    reg_odd  <= to_integer(unsigned(address(3 downto 1))) * 2 + 1;
 
    -- El mux siempre usa la dirección completa de 4 bits
    mux_sel <= address;
 
    -- ----------------------------------------------------------
    -- Decodificador de enable
    --
    -- CORRECCIÓN: se usa '=' (no '<=') para activar UN SOLO
    -- registro en modo individual.
    --
    -- Modo individual: activa en_regs(addr_int) si w_e='1'.
    -- Modo par       : activa en_regs(reg_even) y en_regs(reg_odd)
    --                  simultáneamente si w_e='1'.
    -- ----------------------------------------------------------
 
     GEN_EN : for i in 0 to 15 generate
        en_regs(i) <=
            -- Modo individual: solo el registro apuntado por address
            w_e when (pair_mode = '0' and addr_int = i)
            -- Modo par: activa el registro par de la pareja
            else w_e when (pair_mode = '1' and reg_even = i)
            -- Modo par: activa el registro impar de la pareja
            else w_e when (pair_mode = '1' and reg_odd  = i)
            else '0';
    end generate GEN_EN;
 
    -- ----------------------------------------------------------
    -- Instanciación de los 16 registros de 4 bits
    --
    -- Modo individual: data_in[3:0] → registro seleccionado
    -- Modo par       : data_in[7:4] → registro par  (nibble alto)
    --                  data_in[3:0] → registro impar (nibble bajo)
    --
    -- Cada registro recibe su nibble según su paridad de índice.
    -- ----------------------------------------------------------
    GEN_REGS : for i in 0 to 15 generate
        -- Registros de índice PAR (0,2,4,...,14)
        EVEN_REG : if (i mod 2 = 0) generate
            REG_i : registro_4b
                port map (
                    clk   => clk_r,
                    R     => rst_r,
                    E     => en_regs(i),
                    -- En modo par recibe nibble ALTO; en individual, nibble bajo
                    D_in  => din_even,  -- señal ya resuelta, sin condicional
                    Q_out => q_regs(i)
                );
        end generate EVEN_REG;
 
        -- Registros de índice IMPAR (1,3,5,...,15)
        ODD_REG : if (i mod 2 = 1) generate
            REG_i : registro_4b
                port map (
                    clk   => clk_r,
                    R     => rst_r,
                    E     => en_regs(i),
                    -- Siempre recibe nibble BAJO
                    D_in  => data_in(3 downto 0),
                    Q_out => q_regs(i)
                );
        end generate ODD_REG;
 
    end generate GEN_REGS;
 
    -- ----------------------------------------------------------
    -- Multiplexor 16:1
    --
    -- Selecciona la salida del registro apuntado por 'address'.
    -- Funciona tanto en lectura como en escritura (el registro
    -- ya habrá actualizado su Q_out en el flanco de reloj).
    -- ----------------------------------------------------------
    MX : mtx_scratchpad
        port map (
            i0  => q_regs(0),
            i1  => q_regs(1),
            i2  => q_regs(2),
            i3  => q_regs(3),
            i4  => q_regs(4),
            i5  => q_regs(5),
            i6  => q_regs(6),
            i7  => q_regs(7),
            i8  => q_regs(8),
            i9  => q_regs(9),
            i10 => q_regs(10),
            i11 => q_regs(11),
            i12 => q_regs(12),
            i13 => q_regs(13),
            i14 => q_regs(14),
            i15 => q_regs(15),
            sel => mux_sel,
            y   => mux_out
        );
     -- ----------------------------------------------------------
    -- Lógica de salida
    --
    -- Modo individual: data_out[7:4] = "0000" (no usado)
    --                  data_out[3:0] = mux_out (nibble del registro)
    --
    -- Modo par       : data_out[7:4] = q_regs(reg_even)  nibble alto
    --                  data_out[3:0] = q_regs(reg_odd)   nibble bajo
    --                  → forman el registro de 8 bits RRn
    -- ----------------------------------------------------------
    data_out <= "0000" & mux_out when pair_mode = '0' else q_regs(reg_even) & q_regs(reg_odd);
end architecture Structural;