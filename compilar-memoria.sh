#!/bin/bash
# =============================================================
#  compilar-memoria.sh
#  Compila memoria/memoria.tex con XeLaTeX.
#
#  - Todo el proceso ocurre en  memoria/build/
#  - El PDF resultante se copia a la raíz del proyecto.
#
#  REQUISITOS:
#    1. MacTeX      →  brew install --cask mactex
#    2. Serif font  →  brew install --cask font-source-serif-4
#    3. Mono font   →  brew install --cask font-source-code-pro
#    (Helvetica Neue ya viene preinstalada en macOS)
# =============================================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}⚠${NC}  $1"; }
err()  { echo -e "${RED}✗${NC}  $1"; }

DOCNAME="memoria"
ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_DIR="$ROOT_DIR/$DOCNAME"         # carpeta fuente: memoria/
BUILD_DIR="$SRC_DIR/build"           # carpeta de compilación: memoria/build/

# =============================================================
# 1. Comprobar dependencias
# =============================================================
echo ""
echo "── Dependencias ──────────────────────────────────────────"

if ! command -v xelatex &>/dev/null; then
    err "xelatex no encontrado. Instala MacTeX:"
    echo "    brew install --cask mactex"
    exit 1
fi
ok "xelatex  → $(xelatex --version | head -1)"

if ! command -v biber &>/dev/null; then
    warn "biber no encontrado — referencias bibliográficas omitidas."
    BIBER=false
else
    ok "biber    → $(biber --version | head -1)"
    BIBER=true
fi

if ! command -v makeglossaries &>/dev/null; then
    warn "makeglossaries no encontrado — glosario/acrónimos omitidos."
    GLOSSARIES=false
else
    ok "makeglossaries → OK"
    GLOSSARIES=true
fi

# =============================================================
# 2. Comprobar fuentes requeridas
# =============================================================
echo ""
echo "── Fuentes ───────────────────────────────────────────────"

font_exists() { fc-list | grep -qi "$1"; }

if font_exists "Source Serif 4" || font_exists "Source Serif Pro"; then
    ok "Fuente serif (Source Serif 4) OK"
else
    err "Fuente serif no encontrada:  brew install --cask font-source-serif-4"; exit 1
fi
if font_exists "Helvetica Neue" || font_exists "Helvetica" || font_exists "Arial"; then
    ok "Fuente sans (Helvetica Neue) OK"
else
    warn "Helvetica Neue no encontrada — se usará fuente por defecto."
fi
if font_exists "Source Code Pro"; then
    ok "Fuente mono (Source Code Pro) OK"
else
    err "Source Code Pro no encontrada:  brew install --cask font-source-code-pro"; exit 1
fi

# =============================================================
# 3. Preparar carpeta de build (patrón del Makefile oficial)
#    → copiar todo el contenido de memoria/ en memoria/build/
#      (excepto el propio build/ para evitar recursión)
# =============================================================
echo ""
echo "── Preparando build ──────────────────────────────────────"

mkdir -p "$BUILD_DIR"
# Copiar fuentes a build/, excluyendo la propia carpeta build
rsync -a --exclude='build' "$SRC_DIR/" "$BUILD_DIR/"
ok "Fuentes copiadas a memoria/build/"

# =============================================================
# 4. Función de compilación con salida de errores clara
# =============================================================
run_xelatex() {
    local LABEL="$1"
    echo ""
    echo "[$LABEL] xelatex…"
    local LOG_TMP
    LOG_TMP=$(mktemp)
    local EXIT_CODE=0
    xelatex -interaction=nonstopmode -file-line-error \
            "$DOCNAME.tex" > "$LOG_TMP" 2>&1 || EXIT_CODE=$?
    if [ "$EXIT_CODE" -ne 0 ]; then
        if [ -f "$DOCNAME.pdf" ]; then
            # PDF generado a pesar de errores — mostrar advertencias y continuar
            warn "xelatex terminó con código $EXIT_CODE en '$LABEL' (PDF generado — errores no fatales):"
            echo "──────────────────────────────────────────"
            grep -A4 "^!" "$LOG_TMP" | head -30 || true
            echo "──────────────────────────────────────────"
        else
            echo ""
            err "xelatex falló en '$LABEL' y no generó PDF:"
            echo "──────────────────────────────────────────"
            grep -A4 "^!" "$LOG_TMP" | head -50
            echo "──────────────────────────────────────────"
            err "Log completo: $BUILD_DIR/$DOCNAME.log"
            rm -f "$LOG_TMP"
            exit 1
        fi
    fi
    grep -E "^Package .* Warning|Overfull|Underfull" "$LOG_TMP" | head -10 || true
    rm -f "$LOG_TMP"
    ok "$LABEL completado"
}

# =============================================================
# 5. Limpiar restos de compilaciones anteriores en la raíz
# =============================================================
echo ""
echo "── Limpiando raíz ────────────────────────────────────────"
ROOT_JUNK=(acn aux bcf glo ist log lol lot out run.xml toc)
for EXT in "${ROOT_JUNK[@]}"; do
    f="$ROOT_DIR/$DOCNAME.$EXT"
    [ -f "$f" ] && rm -f "$f" && warn "Eliminado resto: $DOCNAME.$EXT"
done
# Eliminar cls modificada suelta en la raíz (si existe)
[ -f "$ROOT_DIR/upm-report.cls" ] && rm -f "$ROOT_DIR/upm-report.cls" \
    && warn "Eliminado upm-report.cls suelto de la raíz"
[ -f "$ROOT_DIR/$DOCNAME.tex" ] && warn "$DOCNAME.tex en raíz ya no se usa — puedes borrarlo manualmente"
ok "Raíz limpia"

# =============================================================
# 6. Pipeline de compilación (dentro de build/)
# =============================================================
echo ""
echo "── Compilando ────────────────────────────────────────────"
cd "$BUILD_DIR"

run_xelatex "1/4 — primera pasada"

if [ "$GLOSSARIES" = true ]; then
    echo ""
    echo "[2/4] makeglossaries…"
    makeglossaries "$DOCNAME" 2>&1 | grep -Ev "^$|Generating" || true
    ok "2/4 — makeglossaries completado"
else
    warn "[2/4] makeglossaries — omitido"
fi

if [ "$BIBER" = true ] && [ -f "$DOCNAME.bcf" ]; then
    echo ""
    echo "[3/4] biber…"
    biber "$DOCNAME" 2>&1 | grep -E "INFO|WARN|ERROR" | head -20 || true
    ok "3/4 — biber completado"
else
    warn "[3/4] biber — omitido"
fi

run_xelatex "4/4 — segunda pasada"

# Tercera pasada si LaTeX pide rerun (referencias cruzadas, ToC, etc.)
if grep -qE "Rerun|run again" "$DOCNAME.log" 2>/dev/null; then
    run_xelatex "4b — pasada extra (referencias pendientes)"
fi

# =============================================================
# 6. Copiar PDF a la raíz del proyecto
# =============================================================
echo ""
echo "── Resultado ─────────────────────────────────────────────"
if [ -f "$DOCNAME.pdf" ]; then
    cp "$DOCNAME.pdf" "$ROOT_DIR/$DOCNAME.pdf"
    ok "PDF copiado a: $ROOT_DIR/$DOCNAME.pdf"
    echo ""
    open "$ROOT_DIR/$DOCNAME.pdf"
else
    err "No se generó el PDF. Revisa: $BUILD_DIR/$DOCNAME.log"
    exit 1
fi
echo ""
