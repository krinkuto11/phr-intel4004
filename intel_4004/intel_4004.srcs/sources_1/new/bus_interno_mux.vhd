library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.pkg_4004.all;

entity bus_interno_mux is
    Port (
        -- 1. Accumulator (in-out)
        acc_out         : in  STD_LOGIC_VECTOR(BUS_W-1 downto 0);
        acc_oe          : in  STD_LOGIC;
        
        -- 2. Temp. Register (in-out)
        tmp_reg_out     : in  STD_LOGIC_VECTOR(BUS_W-1 downto 0);
        tmp_reg_oe      : in  STD_LOGIC;
        
        -- 3. Flag Flip Flops (in-out)
        flags_out       : in  STD_LOGIC_VECTOR(BUS_W-1 downto 0);
        flags_oe        : in  STD_LOGIC;
        
        -- 4. ALU (out)
        alu_out         : in  STD_LOGIC_VECTOR(BUS_W-1 downto 0);
        alu_oe          : in  STD_LOGIC;
        
        -- 5. Instruction Decoder (out)
        decoder_out     : in  STD_LOGIC_VECTOR(BUS_W-1 downto 0);
        decoder_oe      : in  STD_LOGIC;
        
        -- 6. Stack Multiplexer (in-out)
        stack_out       : in  STD_LOGIC_VECTOR(BUS_W-1 downto 0);
        stack_oe        : in  STD_LOGIC;
        
        -- 7. Register Multiplexer (in-out)
        reg_mux_out     : in  STD_LOGIC_VECTOR(BUS_W-1 downto 0);
        reg_mux_oe      : in  STD_LOGIC;
        
        -- 8. Buffer Externo (in-out respecto al bus interno)
        ext_buf_out     : in  STD_LOGIC_VECTOR(BUS_W-1 downto 0);
        ext_buf_oe      : in  STD_LOGIC;

        -- Nota: Instruction Register no está porque es solo "in" (lectura).

        -- Salida resolutiva al bus central
        internal_bus    : out STD_LOGIC_VECTOR(BUS_W-1 downto 0)
    );
end bus_interno_mux;

architecture Combinacional of bus_interno_mux is
    -- Vector de 8 bits para analizar peticiones simultáneas
    signal vector_peticiones : STD_LOGIC_VECTOR(7 downto 0);
begin
    
    -- Concatenamos todos los permisos de escritura/salida
    vector_peticiones <= acc_oe & tmp_reg_oe & flags_oe & alu_oe & 
                         decoder_oe & stack_oe & reg_mux_oe & ext_buf_oe;

    process(vector_peticiones, acc_out, tmp_reg_out, flags_out, alu_out, 
            decoder_out, stack_out, reg_mux_out, ext_buf_out)
    begin
        case vector_peticiones is
            when "00000000" => internal_bus <= BUS_CERO;
            when "10000000" => internal_bus <= acc_out;
            when "01000000" => internal_bus <= tmp_reg_out;
            when "00100000" => internal_bus <= flags_out;
            when "00010000" => internal_bus <= alu_out;
            when "00001000" => internal_bus <= decoder_out;
            when "00000100" => internal_bus <= stack_out;
            when "00000010" => internal_bus <= reg_mux_out;
            when "00000001" => internal_bus <= ext_buf_out;
            when others     => internal_bus <= BUS_ERROR; -- ¡Colisión detectada!
        end case;
    end process;

end Combinacional;