----------------------------------------------------------------------------------
-- Instruction Decoder and Machine Cycle Encoding — Intel 4004
--
-- Contiene tres decodificadores en cascada:
--   d4_16 : Decodificador principal (nibble alto del opcode, 4→16 one-hot)
--   d4_14 : Sub-decodificador para grupo 1111xxxx (instrucciones acumulador/carry)
--   d4_15 : Sub-decodificador para grupo 1110xxxx (instrucciones RAM)
--
-- La entidad top decodIns orquesta los tres y genera:
--   salidaControl  : vector 16-bit one-hot de la instrucción activa
--   ciclo          : '1' si la instrucción es de dos palabras
--   extras         : {es_1111, es_1110}  (para uso externo si se necesita)
--
-- Correcciones v1.1:
--   - Todos los vectores usan downto (antes 'to', incorrecto)
--   - Puerto 's' eliminado de d4_16 (era orphan)
--   - Latch de segundaPalabra corregido (else + bit 3 para FIN)
--   - Nombres enable_1111 / enable_1110 en lugar de enable_E / enable_D
--   - Mux de salida corregido y claramente comentado
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- ============================================================
-- d4_16 : Decodificador principal — nibble alto del opcode
--         Salida one-hot de 16 bits
--         Bits 14 y 15 activan los sub-decodificadores
-- ============================================================
entity d4_16 is
    port(
        e : in  std_logic;
        a : in  std_logic_vector(3 downto 0);
        d : out std_logic_vector(15 downto 0)
    );
end d4_16;

architecture Behavioral of d4_16 is
begin
    process(a, e)
    begin
        if e = '0' then
            d <= (others => '0');
        else
            case a is
                when "0000" => d <= "0000000000000001"; -- NOP
                when "0001" => d <= "0000000000000010"; -- JCN*  (2 palabras)
                when "0010" => d <= "0000000000000100"; -- FIM*/SRC* (2 palabras)
                when "0011" => d <= "0000000000001000"; -- FIN*/JIN
                when "0100" => d <= "0000000000010000"; -- JUN*  (2 palabras)
                when "0101" => d <= "0000000000100000"; -- JMS*  (2 palabras)
                when "0110" => d <= "0000000001000000"; -- INC
                when "0111" => d <= "0000000010000000"; -- ISZ*  (2 palabras)
                when "1000" => d <= "0000000100000000"; -- ADD
                when "1001" => d <= "0000001000000000"; -- SUB
                when "1010" => d <= "0000010000000000"; -- LD
                when "1011" => d <= "0000100000000000"; -- XCH
                when "1100" => d <= "0001000000000000"; -- BBL
                when "1101" => d <= "0010000000000000"; -- LDM
                when "1110" => d <= "0100000000000000"; -- Grupo 1110 (RAM) → sub-dec
                when "1111" => d <= "1000000000000000"; -- Grupo 1111 (ACC) → sub-dec
                when others => d <= (others => '0');
            end case;
        end if;
    end process;
end Behavioral;


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- ============================================================
-- d4_14 : Sub-decodificador para grupo 1111 xxxx
--         Instrucciones de acumulador y carry
-- ============================================================
entity d4_14 is
    port(
        e : in  std_logic;
        a : in  std_logic_vector(3 downto 0);
        d : out std_logic_vector(15 downto 0)
    );
end d4_14;

architecture Behavioral of d4_14 is
begin
    process(a, e)
    begin
        if e = '0' then
            d <= (others => '0');
        else
            case a is
                when "0000" => d <= "0000000000000001"; -- CLB
                when "0001" => d <= "0000000000000010"; -- CLC
                when "0010" => d <= "0000000000000100"; -- IAC
                when "0011" => d <= "0000000000001000"; -- CMC
                when "0100" => d <= "0000000000010000"; -- CMA
                when "0101" => d <= "0000000000100000"; -- RAL
                when "0110" => d <= "0000000001000000"; -- RAR
                when "0111" => d <= "0000000010000000"; -- TCC
                when "1000" => d <= "0000000100000000"; -- DAC
                when "1001" => d <= "0000001000000000"; -- TCS
                when "1010" => d <= "0000010000000000"; -- STC
                when "1011" => d <= "0000100000000000"; -- DAA
                when "1100" => d <= "0001000000000000"; -- KBP
                when "1101" => d <= "0010000000000000"; -- DCL
                when others => d <= (others => '0');
            end case;
        end if;
    end process;
end Behavioral;


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- ============================================================
-- d4_15 : Sub-decodificador para grupo 1110 xxxx
--         Instrucciones de memoria RAM
-- ============================================================
entity d4_15 is
    port(
        e : in  std_logic;
        a : in  std_logic_vector(3 downto 0);
        d : out std_logic_vector(15 downto 0)
    );
end d4_15;

architecture Behavioral of d4_15 is
begin
    process(a, e)
    begin
        if e = '0' then
            d <= (others => '0');
        else
            case a is
                when "0000" => d <= "0000000000000001"; -- WRM
                when "0001" => d <= "0000000000000010"; -- WMP
                when "0010" => d <= "0000000000000100"; -- WRR
                when "0011" => d <= "0000000000001000"; -- WPM
                when "0100" => d <= "0000000000010000"; -- WR0
                when "0101" => d <= "0000000000100000"; -- WR1
                when "0110" => d <= "0000000001000000"; -- WR2
                when "0111" => d <= "0000000010000000"; -- WR3
                when "1000" => d <= "0000000100000000"; -- SBM
                when "1001" => d <= "0000001000000000"; -- RDM
                when "1010" => d <= "0000010000000000"; -- RDR
                when "1011" => d <= "0000100000000000"; -- ADM
                when "1100" => d <= "0001000000000000"; -- RD0
                when "1101" => d <= "0010000000000000"; -- RD1
                when "1110" => d <= "0100000000000000"; -- RD2
                when "1111" => d <= "1000000000000000"; -- RD3
                when others => d <= (others => '0');
            end case;
        end if;
    end process;
end Behavioral;


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- ============================================================
-- decodIns : Decodificador top-level
--
-- Puertos:
--   enable        : habilita la decodificación
--   entrada1      : nibble alto del opcode (IR[7:4])
--   entrada2      : nibble bajo  del opcode (IR[3:0])
--   salidaControl : vector 16-bit one-hot de la instrucción
--   ciclo         : '1' si la instrucción requiere segunda palabra
--   extras        : {es_grupo_1111, es_grupo_1110}
-- ============================================================
entity decodIns is
    port(
        enable        : in  std_logic;
        entrada1      : in  std_logic_vector(3 downto 0);
        entrada2      : in  std_logic_vector(3 downto 0);
        salidaControl : out std_logic_vector(15 downto 0);
        ciclo         : out std_logic;
        extras        : out std_logic_vector(1 downto 0)
    );
end decodIns;

architecture Behavioral of decodIns is

    component d4_16 is
        port(e: in std_logic; a: in std_logic_vector(3 downto 0); d: out std_logic_vector(15 downto 0));
    end component;

    component d4_14 is
        port(e: in std_logic; a: in std_logic_vector(3 downto 0); d: out std_logic_vector(15 downto 0));
    end component;

    component d4_15 is
        port(e: in std_logic; a: in std_logic_vector(3 downto 0); d: out std_logic_vector(15 downto 0));
    end component;

    -- Salida del decodificador principal (one-hot del nibble alto)
    signal salD_principal     : std_logic_vector(15 downto 0);

    -- Salidas de los sub-decodificadores
    signal salD_grupo_1111    : std_logic_vector(15 downto 0);  -- d4_14: grupo 1111 xxxx
    signal salD_grupo_1110    : std_logic_vector(15 downto 0);  -- d4_15: grupo 1110 xxxx

    -- Enables para los sub-decodificadores
    -- Bit 15 del principal = opcode "1111" → activa sub-dec de instrucciones acumulador
    -- Bit 14 del principal = opcode "1110" → activa sub-dec de instrucciones RAM
    signal enable_1111        : std_logic;
    signal enable_1110        : std_logic;

    -- Indica si la instrucción tiene segunda palabra (sin latch)
    signal es_dos_palabras    : std_logic;

begin

    -- --------------------------------------------------------
    -- Instancia del decodificador principal
    -- --------------------------------------------------------
    U_PRINCIPAL : d4_16
        port map(e => enable, a => entrada1, d => salD_principal);

    -- --------------------------------------------------------
    -- Habilitar sub-decodificadores según grupo detectado
    -- --------------------------------------------------------
    enable_1111 <= salD_principal(15);   -- opcode "1111 xxxx" → instrs. acumulador
    enable_1110 <= salD_principal(14);   -- opcode "1110 xxxx" → instrs. RAM

    -- --------------------------------------------------------
    -- Sub-decodificador grupo 1111 (CLB, CLC, IAC, ... DCL)
    -- --------------------------------------------------------
    U_GRUPO_1111 : d4_14
        port map(e => enable_1111, a => entrada2, d => salD_grupo_1111);

    -- --------------------------------------------------------
    -- Sub-decodificador grupo 1110 (WRM, WMP, ... RD3)
    -- --------------------------------------------------------
    U_GRUPO_1110 : d4_15
        port map(e => enable_1110, a => entrada2, d => salD_grupo_1110);

    -- --------------------------------------------------------
    -- Mux de salida:
    --   Si opcode es 1111 → usar salida del sub-dec 1111
    --   Si opcode es 1110 → usar salida del sub-dec 1110
    --   En cualquier otro caso → usar la salida del principal
    -- --------------------------------------------------------
    -- El MUX preserva el bit de grupo (15 para ACC, 14 para RAM) en la salida,
    -- de forma que timing_and_control pueda distinguir grupo 1111/1110 de instrucciones
    -- normales que comparten los mismos bits bajos (p.ej. CLB vs NOP, ambos bit 0).
    -- d4_14 solo usa bits 0-13; bits 14-15 son siempre '0', el OR es seguro.
    process(salD_principal, salD_grupo_1111, salD_grupo_1110)
    begin
        if    salD_principal(15) = '1' then   -- grupo 1111 (ACC/carry)
            salidaControl <= salD_grupo_1111 or "1000000000000000";
        elsif salD_principal(14) = '1' then   -- grupo 1110 (RAM)
            salidaControl <= salD_grupo_1110 or "0100000000000000";
        else
            salidaControl <= salD_principal;
        end if;
    end process;

    -- --------------------------------------------------------
    -- Detección de instrucciones de dos palabras (sin latch)
    --
    -- Instrucciones de 2 palabras según spec Intel 4004:
    --   JCN  → bit 1  (opcode 0001)
    --   FIM  → bit 2  (opcode 0010, solo cuando OPA[0]='0')
    --   SRC  → bit 2  (opcode 0010, solo cuando OPA[0]='1') — 1 palabra ✓
    --   FIN  → bit 3  (opcode 0011, cuando OPA[0]='0') — 2 palabras
    --   JIN  → bit 3  (opcode 0011, cuando OPA[0]='1') — 1 palabra
    --   JUN  → bit 4  (opcode 0100)
    --   JMS  → bit 5  (opcode 0101)
    --   ISZ  → bit 7  (opcode 0111)
    --
    -- Para FIM/SRC y FIN/JIN se distingue por OPA[0] (entrada2(0)):
    --   OPA[0]='0' → FIM o FIN (2 palabras)
    --   OPA[0]='1' → SRC o JIN (1 palabra)
    -- --------------------------------------------------------
    es_dos_palabras <=
        salD_principal(1)                                              -- JCN
        or (salD_principal(2) and not entrada2(0))                    -- FIM (no SRC)
        or (salD_principal(3) and not entrada2(0))                    -- FIN (no JIN)
        or salD_principal(4)                                           -- JUN
        or salD_principal(5)                                           -- JMS
        or salD_principal(7);                                          -- ISZ

    ciclo  <= es_dos_palabras;

    -- --------------------------------------------------------
    -- Información de grupo para uso externo
    -- extras(1) = '1' cuando es grupo 1111
    -- extras(0) = '1' cuando es grupo 1110
    -- --------------------------------------------------------
    extras(1) <= enable_1111;
    extras(0) <= enable_1110;

end Behavioral;
