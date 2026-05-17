library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.pkg_4004.all;

-- Flag register del Intel 4004.
--
-- Bit 0 = Carry (CY)
-- Bit 1 = Test
-- Bits 2-3 = reservados
--
-- Prioridad de actualización del carry (bit 0):
--   1. force_carry_en='1'  → carry ← force_carry_val   (STC, CLC, CMC, TCC, CLB)
--   2. carry_load_en='1'   → carry ← carry_in           (aritmética: ADD, SUB, IAC, DAC, RAL, RAR)
--   3. load_en='1'         → carry ← d_in(0)            (carga genérica desde bus)
-- Los bits 1-3 se actualizan solo con load_en='1'.

entity flag_flip_flops is
    Port (
        clk            : in  STD_LOGIC;
        reset          : in  STD_LOGIC;

        load_en        : in  STD_LOGIC;
        d_in           : in  STD_LOGIC_VECTOR(BUS_W-1 downto 0);

        carry_in       : in  STD_LOGIC;
        carry_load_en  : in  STD_LOGIC;

        force_carry_en : in  STD_LOGIC;
        force_carry_val: in  STD_LOGIC;

        q_out          : out STD_LOGIC_VECTOR(BUS_W-1 downto 0)
    );
end flag_flip_flops;

architecture Behavioral of flag_flip_flops is
    signal flags_reg : STD_LOGIC_VECTOR(BUS_W-1 downto 0) := (others => '0');
begin

    process(clk, reset)
    begin
        if reset = '1' then
            flags_reg <= (others => '0');
        elsif rising_edge(clk) then
            -- Bits 1-3: solo load_en los actualiza
            if load_en = '1' then
                flags_reg(BUS_W-1 downto 1) <= d_in(BUS_W-1 downto 1);
            end if;

            -- Bit 0 (carry): prioridad force > carry_load > load_en
            if force_carry_en = '1' then
                flags_reg(0) <= force_carry_val;
            elsif carry_load_en = '1' then
                flags_reg(0) <= carry_in;
            elsif load_en = '1' then
                flags_reg(0) <= d_in(0);
            end if;
        end if;
    end process;

    q_out <= flags_reg;

end Behavioral;
