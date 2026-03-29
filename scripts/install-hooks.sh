#!/usr/bin/env bash
# ============================================
# Homelab Apraghatyus — Instalador de Git Hooks
# Ejecutar desde ~/homelab/
# ============================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
HOOKS_DIR="$REPO_DIR/.git/hooks"
HOOKS_SRC="$SCRIPT_DIR/git-hooks"

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
BOLD='\033[1m'

echo ""
echo -e "${BOLD}Instalando Git hooks para Homelab Apraghatyus...${NC}"
echo ""

# Verificar que estamos en un repo Git
if [ ! -d "$REPO_DIR/.git" ]; then
    echo -e "${RED}Error: $REPO_DIR no es un repositorio Git${NC}"
    exit 1
fi

# Verificar dependencias
echo -e "${BOLD}Verificando dependencias...${NC}"

if command -v python3 &>/dev/null; then
    if python3 -c "import yaml" 2>/dev/null; then
        echo -e "  ${GREEN}✔${NC} python3 + PyYAML disponibles"
    else
        echo -e "  ${RED}✖${NC} PyYAML no instalado — instalando..."
        sudo apt install -y python3-yaml
    fi
else
    echo -e "  ${RED}✖${NC} Python3 no disponible"
    echo "    Instalar: sudo apt install python3 python3-yaml"
fi

# Enlazar hooks
for hook in pre-commit commit-msg; do
    if [ -f "$HOOKS_SRC/$hook" ]; then
        ln -sf "$HOOKS_SRC/$hook" "$HOOKS_DIR/$hook"
        echo -e "  ${GREEN}✔${NC} $hook → instalado"
    else
        echo -e "  ${RED}✖${NC} $hook → no encontrado en $HOOKS_SRC/"
    fi
done

echo ""
echo -e "${GREEN}${BOLD}Hooks instalados correctamente.${NC}"
echo -e "Se ejecutarán automáticamente en cada git commit."
echo ""
