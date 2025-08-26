#!/bin/bash
set -e

MSG="${1:-🚀 update GhostUtils installer}"

echo "[*] Publicando instalador GhostUtils no GitHub Pages..."
git add linux
git commit -m "$MSG"
git push

echo "[OK] Publicado com sucesso!"
echo "Agora o comando já está atualizado:"
echo "  curl -fsSL https://naskanghost.github.io/linux | sh"
