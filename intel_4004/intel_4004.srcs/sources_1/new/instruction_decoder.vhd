----------------------------------------------------------------------------------
-- Instruction Decoder — Intel 4004
-- Archivo: instruction_decoder.vhd
--
-- Entidad adaptadora que envuelve a decodIns y proporciona la interfaz
-- completa que necesitan cpu_4004_top y timing_and_control.
--
-- Funciones:
--   1. Divide ir_in(7:4) → entrada1 y ir_in(3:0) → entrada2
--   2. Genera inst_group (16-bit one-hot) para timing_and_control
--   3. Registra current_frag (síncrono): '0'=primer ciclo, '1'=segundo ciclo
--   4. Genera disable_ir: inhibe carga del IR durante el segundo ciclo
--   5. Propaga scratch_addr = ir_in(3:0) al scratch pad
--   6. Genera bus_out/out_en para instrucciones con dato inmediato (LDM, BBL)
--      LDM: bus_out = ir_in(3:0) (dato inmediato de 4 bits)
--      BBL: bus_out = ir_in(3:0) (dato que se carga al volver de subrutina)
--
-- Protocolo de current_frag:
--   - Se pone a '1' en el flanco de reloj de X3 cuando ciclo='1'
--     (la instrucción necesita una segunda palabra de ROM)
--   - Se pone a '0' al inicio del ciclo siguiente (tras capturar la 2ª palabra)
--
-- Nota: el 4004 implementa instrucciones de 2 palabras tomando un segundo
-- ciclo de máquina completo (A1-A3 + M1-M2 + X1-X3). Durante ese segundo
-- ciclo, el IR ya contiene la primera palabra y NO debe sobreescribirse.
-- Por eso disable_ir='1' durante el segundo ciclo fetch (current_frag='1').
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.pkg_4004.all;

entity instruction_decoder is
    port(
        clk           : in  STD_LOGIC;
        reset         : in  STD_LOGIC;

        -- Desde el Instruction Register (8 bits)
        ir_in         : in  STD_LOGIC_VECTOR(7 downto 0);

        -- Hacia timing_and_control
        inst_group    : out STD_LOGIC_VECTOR(15 downto 0); -- one-hot de instrucción
        current_frag  : out STD_LOGIC;                     -- 0=ciclo1, 1=ciclo2
        disable_ir    : out STD_LOGIC;                     -- inhibir carga del IR

        -- Hacia el bus interno: datos inmediatos (LDM, BBL)
        bus_out       : out STD_LOGIC_VECTOR(BUS_W-1 downto 0);
        out_en        : out STD_LOGIC
    );
end instruction_decoder;

architecture Structural of instruction_decoder is

    -- --------------------------------------------------------
    -- Componente decodIns
    -- --------------------------------------------------------
    component decodIns is
        port(
            enable        : in  std_logic;
            entrada1      : in  std_logic_vector(3 downto 0);
            entrada2      : in  std_logic_vector(3 downto 0);
            salidaControl : out std_logic_vector(15 downto 0);
            ciclo         : out std_logic;
            extras        : out std_logic_vector(1 downto 0)
        );
    end component;

    -- --------------------------------------------------------
    -- Señales internas
    -- --------------------------------------------------------
    signal nibble_alto    : STD_LOGIC_VECTOR(3 downto 0);  -- IR[7:4]
    signal nibble_bajo    : STD_LOGIC_VECTOR(3 downto 0);  -- IR[3:0]

    signal inst_group_int : STD_LOGIC_VECTOR(15 downto 0);
    signal ciclo_int      : STD_LOGIC;                     -- combinacional

    -- Registro de ciclo: se activa al detectar instrucción de 2 palabras
    signal frag_reg       : STD_LOGIC := '0';

    -- Para detectar instrucciones con dato inmediato al bus
    -- Bit 13 = LDM (opcode 1101), Bit 12 = BBL (opcode 1100)
    signal es_ldm_bbl     : STD_LOGIC;

begin

    -- --------------------------------------------------------
    -- División del IR en nibbles
    -- --------------------------------------------------------
    nibble_alto <= ir_in(7 downto 4);
    nibble_bajo <= ir_in(3 downto 0);

    -- --------------------------------------------------------
    -- Instancia del decodificador principal
    -- --------------------------------------------------------
    U_DEC : decodIns
        port map(
            enable        => '1',
            entrada1      => nibble_alto,
            entrada2      => nibble_bajo,
            salidaControl => inst_group_int,
            ciclo         => ciclo_int,
            extras        => open
        );

    -- --------------------------------------------------------
    -- Salidas directas
    -- --------------------------------------------------------
    inst_group   <= inst_group_int;

    -- --------------------------------------------------------
    -- Registro síncrono de current_frag
    --
    -- Lógica:
    --   - Si estamos en ciclo 1 y ciclo_int='1' → siguiente ciclo es el 2º
    --   - Si estamos en ciclo 2 → volver a ciclo 1 (instrucción completada)
    -- Se captura en el flanco de subida del reloj (fase X3 → A1 siguiente)
    -- --------------------------------------------------------
    process(clk, reset)
    begin
        if reset = '1' then
            frag_reg <= '0';
        elsif rising_edge(clk) then
            if frag_reg = '1' then
                -- Acabamos de ejecutar el segundo ciclo: volver a ciclo 1
                frag_reg <= '0';
            elsif ciclo_int = '1' then
                -- Primera palabra detectada como instrucción de 2 palabras
                frag_reg <= '1';
            end if;
        end if;
    end process;

    current_frag <= frag_reg;

    -- --------------------------------------------------------
    -- disable_ir: inhibe la carga del IR durante el 2º ciclo fetch
    -- Cuando frag_reg='1', el IR no debe sobreescribirse con
    -- la segunda palabra (que es la dirección/dato, no un opcode).
    -- --------------------------------------------------------
    disable_ir <= frag_reg;

    -- --------------------------------------------------------
    -- bus_out / out_en: datos inmediatos al bus interno
    --
    -- LDM (bit 13): carga nibble_bajo directamente al acumulador
    -- BBL (bit 12): carga nibble_bajo al acumulador al retornar
    --
    -- El timing_and_control activará el OE en la fase X1
    -- --------------------------------------------------------
    es_ldm_bbl <= inst_group_int(13) or inst_group_int(12);

    bus_out <= nibble_bajo when es_ldm_bbl = '1' else (others => '0');
    out_en  <= es_ldm_bbl;

end Structural;
