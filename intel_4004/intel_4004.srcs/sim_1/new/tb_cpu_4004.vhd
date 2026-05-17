library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.pkg_4004.all;

-- =============================================================
-- Testbench: tb_cpu_4004
--
-- Instancia cpu_4004_top + ROM y simula el programa de validación.
-- Duración: 6000 ns ≈ 30 instrucciones × 8 T-states × 20 ns/ciclo + margen.
--
-- Señales clave para el waveform (añadir desde UUT):
--   pc_reg            — Program Counter (12 bits)
--   cable_acc_out     — Acumulador (4 bits)
--   cable_flags_out   — Flags; bit 0 = Carry
--   cable_ir_out_8bit — Instrucción en el IR (8 bits)
--   cable_t_state     — T-state actual ("111"=X3 = fin de instrucción)
--
-- Tabla de resultados esperados (leer en flanco de subida de X3→A1):
--   PC   Instrucción    ACC esperado   CY esperado
--   001  LDM 5          5              0
--   002  XCH R0         0              0   (R0←5)
--   003  LDM 3          3              0
--   004  XCH R2         0              0   (R2←3)
--   005  LD R0          5              0
--   006  ADD R2         8              0
--   007  LDM 15         F              0
--   008  ADD R2         2              1   overflow
--   009  LD R0          5              1
--   00A  SUB R2         2              1
--   00B  CLC            2              0
--   00C  LDM 15         F              0
--   00D  IAC            0              1   overflow
--   00E  LDM 0          0              1
--   00F  DAC            F              0   borrow
--   010  CMC            F              1
--   011  LDM 5          5              1
--   012  CMA            A              1
--   013  CLB            0              0
--   014  STC            0              1
--   015  TCC            1              0
--   016  RAL            2              0
--   017  RAL            4              0
--   018  RAR            2              0
--   019  LDM 8          8              0
--   01A  RAL            0              1   MSB→CY
--   01B  RAR            8              0   CY→MSB
--   01C  LD R0          5              0
-- =============================================================

entity tb_cpu_4004 is
end tb_cpu_4004;

architecture sim of tb_cpu_4004 is

    -- Señales hacia el DUT (cpu_4004_top)
    signal clk_ph1   : STD_LOGIC := '0';
    signal clk_ph2   : STD_LOGIC := '1';
    signal reset     : STD_LOGIC := '1';
    signal test_pin  : STD_LOGIC := '0';

    signal sync_out  : STD_LOGIC;
    signal cm_rom    : STD_LOGIC;
    signal cm_ram    : STD_LOGIC_VECTOR(3 downto 0);
    signal D_bus     : STD_LOGIC_VECTOR(BUS_W-1 downto 0);
    signal fase_out  : STD_LOGIC_VECTOR(1 downto 0);

    -- Período de reloj
    constant T_CLK : time := 20 ns;

begin

    -- ----------------------------------------------------------------
    -- Generación de relojes bifásicos
    -- clk_ph1 y clk_ph2 son complementarios (no solapantes)
    -- ----------------------------------------------------------------
    clk_ph1 <= not clk_ph1 after T_CLK / 2;
    clk_ph2 <= not clk_ph1;

    -- ----------------------------------------------------------------
    -- Reset: activo 3 ciclos de reloj, luego liberado
    -- ----------------------------------------------------------------
    reset <= '0' after 3 * T_CLK;

    -- ----------------------------------------------------------------
    -- DUT: Intel 4004 CPU
    -- ----------------------------------------------------------------
    UUT : entity work.cpu_4004_top
        port map(
            clk_ph1  => clk_ph1,
            clk_ph2  => clk_ph2,
            reset    => reset,
            test_pin => test_pin,
            sync     => sync_out,
            cm_rom   => cm_rom,
            cm_ram   => cm_ram,
            D_bus    => D_bus,
            fase_out => fase_out
        );

    -- ----------------------------------------------------------------
    -- ROM externa (Intel 4001)
    -- ----------------------------------------------------------------
    ROM_INST : entity work.ROM
        port map(
            clk    => clk_ph1,
            cm_rom => cm_rom,
            fase   => fase_out,
            bus_io => D_bus
        );

    -- ----------------------------------------------------------------
    -- Control de simulación
    -- 30 instrucciones × 8 T-states × 20 ns = 4800 ns + margen
    -- ----------------------------------------------------------------
    process
    begin
        wait for 6000 ns;
        report "=== Simulacion completada (6000 ns) ===" severity note;
        report "Verificar señales cable_acc_out y cable_flags_out(0)" severity note;
        report "en los flancos donde cable_t_state = 111 (estado X3)" severity note;
        wait;
    end process;

end sim;
