----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 11.05.2026 17:52:39
-- Design Name: 
-- Module Name: instruction_register - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.pkg_4004.all; -- Requiere que el diccionario esté compilado

entity instruction_register is
    Port (
        clk         : in  STD_LOGIC;
        reset       : in  STD_LOGIC;
        load_high   : in  STD_LOGIC; -- Activo en fase M1
        load_low    : in  STD_LOGIC; -- Activo en fase M2
        bus_in      : in  STD_LOGIC_VECTOR(BUS_W-1 downto 0); -- 4 bits
        instr_out   : out STD_LOGIC_VECTOR(7 downto 0);        -- 8 bits
        decoder_out : out STD_LOGIC_VECTOR(BUS_W-1 downto 0);  -- For bus connection
        decoder_oe  : out STD_LOGIC                             -- Output enable
    );
end instruction_register;

architecture Structural of instruction_register is
    signal instr_out_int : STD_LOGIC_VECTOR(7 downto 0);
begin

    -- Asignamos la señal interna a la salida externa
    instr_out <= instr_out_int;

    -- Decoder out: lower 4 bits of instruction
    decoder_out <= instr_out_int(3 downto 0);
    
    -- Decoder OE: placeholder, '0'
    decoder_oe <= '0';

    -- PARTE ALTA: Captura los 4 bits del bus y los pone en instr_out(7..4)
    gen_high: for i in 0 to 3 generate
        bit_high: entity work.d_ff_en 
            port map (
                clk   => clk,
                reset => reset,
                en    => load_high,
                d     => bus_in(i),
                q     => instr_out_int(i+4)
            );
    end generate;

    -- PARTE BAJA: Captura los 4 bits del bus y los pone en instr_out(3..0)
    gen_low: for i in 0 to 3 generate
        bit_low: entity work.d_ff_en 
            port map (
                clk   => clk,
                reset => reset,
                en    => load_low,
                d     => bus_in(i),
                q     => instr_out_int(i)
            );
    end generate;

end Structural;
