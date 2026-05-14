# Skill: Mantenimiento de la memoria del proyecto Intel 4004

## Contexto del proyecto

- **Tipo de trabajo:** Proyecto Fin de Asignatura (PFA).
- **Asignatura:** Programación de Hardware Reconfigurable (PHR), 3º de Ingeniería de Computadores, ETSISI – UPM.
- **Alumnos:** Ander Regidor Barrante, Iván Serrano Prieto, Maria José García-Prieto Castells, Elena Esparza Baña.
- **Profesor:** Vicente A. García Alcántara.
- **Objetivo:** Implementar el procesador Intel 4004 de 4 bits en VHDL sobre una Basys 3 Artix-7 XC7A35TICPG236-1L.
- **Herramientas:** Vivado Design Suite, VHDL-93.
- **Fase actual:** Diseño (a actualizar conforme avance el proyecto).
- **Fichero de la memoria:** `memoria.tex` (LaTeX, clase `upm-report`).
- **Carpeta del proyecto Vivado:** `intel_4004/intel_4004.srcs/sources_1/new/`

---

## Estructura de la memoria

La memoria sigue la estructura de la plantilla UPM (`plantilla.tex`). Los capítulos son:

| Capítulo | Label LaTeX | Estado |
|---|---|---|
| Introducción | `ch:introduccion` | Esqueleto listo, por completar |
| Estado de la cuestión | `ch:estado-cuestion` | Borrador inicial |
| Metodología | `ch:metodologia` | Placeholder (completar con transparencias) |
| **Diseño** | `ch:diseno` | **Completo para los bloques actuales** |
| Verificación | `ch:verificacion` | TODO |
| Implementación | `ch:implementacion` | TODO |
| Conclusiones | `ch:conclusiones` | TODO |
| Apéndice: Listado de ficheros | `ch:ficheros` | Completo para los bloques actuales |

---

## Capítulo de Diseño — estructura interna

El capítulo de Diseño (`ch:diseno`) está organizado en las siguientes secciones:

```
ch:diseno
├── s:estructura          — Estructura del proyecto en código
│   ├── Filosofía: arquitectura estructural jerárquica
│   ├── Fichero raíz: cpu_4004_top.vhd
│   └── Paquete de constantes: pkg_4004.vhd
├── s:primitivas          — Primitivas de hardware
│   ├── ss:d-ff-en        — d_ff_en.vhd
│   ├── ss:registros      — registro_4b.vhd, registro_12b.vhd
│   └── ss:ff-jk          — flipflopJK.vhd
├── s:ruta-datos          — Ruta de datos
│   ├── ss:accumulator    — accumulator.vhd
│   ├── ss:temp-register  — temp_register.vhd
│   ├── ss:alu            — alu.vhd
│   ├── ss:decimal-adjust — decimal_adjust.vhd
│   └── ss:flags          — flag_flip_flops.vhd
├── s:memoria             — Memoria y direccionamiento
│   ├── ss:scratchpad     — scratch_pad.vhd + mtx_scratchpad.vhd
│   └── ss:stack          — stack_3L.vhd
│       ├── ss:puntero-stack — puntero_stack.vhd + flipflopJK.vhd
│       └── ss:mtx-stack     — mtx_stack.vhd
├── s:interfaz            — Interfaz con el exterior
│   ├── ss:bus-interno    — bus_interno_mux.vhd
│   └── ss:data-bus-buffer — data_bus_buffer.vhd
├── s:control             — Unidad de control
│   ├── ss:ir             — instruction_register.vhd
│   └── ss:timing-control — timing_and_control.vhd
└── s:pendientes          — Bloques aún no implementados
```

---

## Plantilla estándar para documentar un nuevo bloque VHDL

Cuando se añada un nuevo bloque al diseño, hay que añadir una subsección con esta estructura (copiar y adaptar):

```latex
\subsection{Nombre descriptivo: \texttt{nombre\_fichero.vhd}}
\label{ss:nombre-label}

[Párrafo introductorio: función del bloque en la CPU y por qué existe
como entidad separada. Mencionar si es un wrapper, si tiene lógica especial,
o qué decisión de diseño justifica su implementación.]

\begin{table}[H]
\centering
\caption{Puertos de la entidad \texttt{nombre\_entidad}}
\label{tab:nombre-label}
\begin{tabularx}{\textwidth}{@{}llcX@{}}
\toprule
\textbf{Puerto} & \textbf{Dir.} & \textbf{Bits} & \textbf{Descripción} \\
\midrule
\texttt{puerto1} & in/out/inout & N & Descripción del puerto \\
% ... más puertos ...
\bottomrule
\end{tabularx}
\end{table}

[Párrafo de arquitectura: tipo de arquitectura VHDL elegida
(Structural / Behavioral / Combinational / FlujoDatos) y por qué.
Mencionar cualquier patrón relevante: GENERATE, CASE, process con/sin
sensibilidad a reloj, etc.]

% Si hay un fragmento de código especialmente ilustrativo:
\begin{lstlisting}[language=VHDL, caption={Descripción del fragmento},
    label=lst:nombre-label]
-- código relevante aquí
\end{lstlisting}
```

**Reglas de estilo para la descripción de bloques:**
- Usar `\texttt{}` siempre para nombres de entidades, puertos, ficheros y señales.
- Las tablas de puertos llevan SIEMPRE los cuatro campos: Puerto, Dir., Bits, Descripción.
- La dirección se abrevia: `in`, `out`, `inout`.
- Los snippets de código son opcionales: solo incluirlos si ilustran una decisión no obvia.
- Cada bloque debe justificar su arquitectura VHDL (por qué Structural y no Behavioral, etc.).

---

## Cómo actualizar la memoria según la fase del proyecto

### Cuando se añade un nuevo fichero VHDL

1. Leer el nuevo fichero `.vhd` con la herramienta `Read`.
2. Identificar en qué sección del capítulo de Diseño encaja el nuevo bloque:
   - Primitiva → `s:primitivas`
   - Ruta de datos (registro, operación) → `s:ruta-datos`
   - Memoria/registros → `s:memoria`
   - Interfaz exterior → `s:interfaz`
   - Control/decodificación → `s:control`
3. Añadir una subsección usando la plantilla de arriba.
4. Si el bloque estaba en `s:pendientes`, eliminar esa entrada de la lista de pendientes.
5. Actualizar la tabla de ficheros en el apéndice `ch:ficheros`.
6. Actualizar este fichero (`memoria-skill.md`): añadir la nueva entrada a la estructura del capítulo de Diseño.

### Cuando se completa la fase de Verificación

1. Leer los testbenches en `intel_4004.srcs/sim_1/new/`.
2. Documentar en `ch:verificacion`:
   - Qué bloques tienen testbench.
   - Metodología de verificación (estímulos aplicados, señales observadas).
   - Resultados de simulación (capturas o tablas de verdad si son relevantes).
3. Actualizar el estado de la tabla de esta skill.

### Cuando se completa la síntesis/implementación

1. Leer los reports de síntesis en `intel_4004.runs/synth_1/`.
2. Documentar en `ch:implementacion`:
   - Informe de utilización de recursos (LUTs, FFs, BRAMs).
   - Informe de timing (frecuencia máxima, slack).
   - Configuración de constraints (`.xdc`).
3. Si hay resultados de funcionamiento sobre la Basys 3, documentarlos también.

### Cuando la metodología se completa

El capítulo `ch:metodologia` debe completarse con las fases descritas en las transparencias de la asignatura. Una vez disponibles, cada fase se documenta brevemente indicando qué actividades se realizaron y qué artefactos se produjeron.

---

## Bloques pendientes de implementar (a fecha 2026-05-14)

| Bloque | Fichero | Sección prevista |
|---|---|---|
| Decodificador de instrucciones | `instruction_decoder.vhd` | `s:control` |
| ROM de programa | `rom.vhd` o BRAM | nueva sección en `s:memoria` o apéndice |

Cuando se implemente cada uno de estos bloques:
- Eliminar su entrada de `s:pendientes` en `memoria.tex`.
- Añadir la subsección correspondiente siguiendo la plantilla.
- Actualizar este fichero.

---

## Acrónimos definidos en la memoria

Están definidos en el preámbulo de `memoria.tex`. Los más usados:

| Comando | Significado |
|---|---|
| `\acrshort{vhdl}` | VHDL |
| `\acrshort{fpga}` | FPGA |
| `\acrshort{cpu}` | CPU |
| `\acrshort{alu}` | ALU |
| `\acrshort{ir}` | IR |
| `\acrshort{fsm}` | FSM |
| `\acrshort{oe}` | OE |
| `\acrshort{bcd}` | BCD |
| `\acrshort{phr}` | PHR |

Glosario relevante:
- `\gls{bus-interno}` → "bus interno"
- `\gls{nibble}` → "nibble"
- `\gls{scratchpad}` → "scratchpad"
- `\gls{stack}` → "pila de direcciones"

---

## Notas de compilación LaTeX

La clase `upm-report` es la plantilla oficial de la UPM (disponible en el repositorio referenciado en `plantilla.tex`). Para compilar:

```bash
pdflatex memoria.tex
makeglossaries memoria
biber memoria
pdflatex memoria.tex
pdflatex memoria.tex
```

O usar `latexmk -pdf memoria.tex` si está disponible.

---

## Historial de actualizaciones

| Fecha | Cambio |
|---|---|
| 2026-05-14 | Creación inicial. Capítulo de Diseño completo para todos los bloques implementados en ese momento. |
