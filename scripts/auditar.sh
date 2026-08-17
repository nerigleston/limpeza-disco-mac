#!/bin/bash
# auditar.sh — auditoria de espaço em disco no macOS (SOMENTE LEITURA)
#
# Não apaga, move ou altera nada. Apenas mede e reporta.
# Uso: bash auditar.sh

set -u

sep() { printf '\n\033[1m== %s ==\033[0m\n' "$1"; }

# du tolerante a caminho inexistente
d() {
  for p in "$@"; do
    [ -e "$p" ] || continue
    du -sh "$p" 2>/dev/null
  done
}

sep "Disco"
echo "ATENÇÃO: use a linha /System/Volumes/Data — a de / é o volume de sistema selado."
df -h / /System/Volumes/Data 2>/dev/null | sed -n '1p;2p;3p'
echo
echo "Snapshots locais do Time Machine (ocupam espaço real):"
tmutil listlocalsnapshots / 2>/dev/null | tail -5

sep "Panorama geral"
d /Applications /Library /opt /usr/local | sort -rh
echo "--- home ---"
du -sh ~/.[!.]* ~/* 2>/dev/null | sort -rh | head -20

sep "~/Library (top 15)"
du -sh ~/Library/* 2>/dev/null | sort -rh | head -15

sep "Docker"
if command -v docker >/dev/null 2>&1; then
  docker system df 2>/dev/null || echo "  (daemon parado — abra o Docker Desktop para medir)"
  echo
  echo "!! NUNCA rodar prune com --volumes: volumes 'dangling' costumam ser bancos de projetos."
  echo "Volumes órfãos (revisar NOME POR NOME com o usuário):"
  docker volume ls -qf dangling=true 2>/dev/null | head -30 | sed 's/^/  /'
  echo
  echo "Arquivo de disco da VM (não encolhe na hora após prune):"
  d ~/Library/Containers/com.docker.docker/Data/vms
else
  echo "  docker não instalado"
fi

sep "WhatsApp (frequentemente o maior item do Mac)"
d ~/Library/Group\ Containers/group.net.whatsapp.WhatsApp.shared/Message/Media \
  ~/Library/Group\ Containers/group.net.whatsapp.WhatsApp.shared \
  ~/Library/Containers/net.whatsapp.WhatsApp
echo "  (remover APENAS Message/Media — bancos e stickers ficam)"

sep "Navegadores"
d ~/Library/Application\ Support/Google/Chrome/Default/Service\ Worker \
  ~/Library/Application\ Support/Google/Chrome \
  ~/Library/Application\ Support/Firefox \
  ~/Library/Application\ Support/BraveSoftware | sort -rh
echo "  (só Service Worker é seguro; WebStorage/IndexedDB guardam sessões)"

sep "Caches de package managers"
d ~/.npm ~/.pnpm-store ~/Library/pnpm/store ~/.bun/install/cache \
  ~/.yarn/berry/cache ~/Library/Caches/Yarn ~/.m2/repository \
  ~/.gradle/caches ~/.cache ~/.pub-cache ~/.cargo/registry ~/.rustup \
  ~/.nuget/packages ~/Library/Caches/pip ~/.local/share/uv ~/.deno | sort -rh

sep "Runtimes e versões antigas"
d ~/.nvm/versions/node ~/.pyenv/versions ~/.rbenv/versions ~/Library/Python | sort -rh
for v in ~/.nvm/versions/node ~/.pyenv/versions ~/.rbenv/versions; do
  [ -d "$v" ] && { echo "  $v:"; ls -1 "$v" 2>/dev/null | sed 's/^/    /'; }
done

sep "Go"
if command -v go >/dev/null 2>&1; then
  d "$(go env GOCACHE 2>/dev/null)" "$(go env GOMODCACHE 2>/dev/null)" | sort -rh
else
  echo "  go não instalado"
fi

sep "Xcode / iOS"
echo "xcode-select: $(xcode-select -p 2>/dev/null)"
ls -d /Applications/Xcode*.app 2>/dev/null || echo "  Xcode.app NÃO instalado (simuladores são resíduo órfão)"
d ~/Library/Developer/Xcode/DerivedData ~/Library/Developer/Xcode/Archives \
  ~/Library/Developer/Xcode/iOS\ DeviceSupport \
  ~/Library/Developer/CoreSimulator/Devices | sort -rh

sep "Android / Flutter"
d ~/.android/avd ~/Library/Android/sdk ~/.gradle ~/fvm ~/.fvm ~/.cocoapods | sort -rh

sep "JetBrains (versões antigas acumulam)"
found=0
for base in ~/Library/Application\ Support/JetBrains ~/Library/Caches/JetBrains; do
  [ -d "$base" ] || continue
  found=1; echo "$base:"; du -sh "$base"/* 2>/dev/null | sort -rh
done
[ "$found" = 0 ] && echo "  não encontrado"

sep "Editores de vídeo (cache pesado, projetos leves)"
d ~/Movies/CapCut/User\ Data/Cache ~/Movies/CapCut/User\ Data/Projects \
  ~/Library/Application\ Support/Blackmagic\ Design \
  /Library/Application\ Support/Blackmagic\ Design | sort -rh

sep "Wallpapers / screensavers 4K"
d ~/Library/Application\ Support/com.apple.wallpaper \
  ~/Library/Containers/com.apple.wallpaper.agent \
  /Library/Application\ Support/com.apple.idleassetsd

sep "Homebrew"
if command -v brew >/dev/null 2>&1; then
  d /opt/homebrew "$(brew --cache 2>/dev/null)"
  echo "Órfãos removíveis (brew autoremove):"; brew autoremove -n 2>&1 | tail -3
  echo "brew cleanup liberaria:"; brew cleanup -n 2>/dev/null | tail -1
  echo "Fórmulas maiores:"; du -sh /opt/homebrew/Cellar/* 2>/dev/null | sort -rh | head -5
else
  echo "  brew não instalado"
fi

sep "Apps instalados (top 12) — checar dono antes de remover"
du -sh /Applications/* 2>/dev/null | sort -rh | head -12

sep "Downloads"
d ~/Downloads
echo "Maiores itens:"; du -sh ~/Downloads/* 2>/dev/null | sort -rh | head -12
echo
echo "Instaladores (verificar se o app já está em /Applications):"
ls -1 ~/Downloads/*.dmg ~/Downloads/*.pkg 2>/dev/null | head -10 | sed 's/^/  /'
echo
echo "node_modules e venvs dentro de Downloads (apagar só o miolo, não a pasta):"
find ~/Downloads -maxdepth 3 -type d \( -name node_modules -o -name .venv -o -name venv \) 2>/dev/null | \
  while read -r p; do echo "  $(du -sh "$p" 2>/dev/null | cut -f1)  $p"; done | sort -rh | head -10
echo
echo "⚠️  Material sensível (NÃO apagar — avisar o usuário para mover):"
find ~/Downloads -maxdepth 1 \( -name "*.pfx" -o -name "*.pem" -o -name "*.key" \
  -o -name "*.ovpn" -o -name "*.p12" -o -name "*.backup.gz" \) 2>/dev/null | head -10 | sed 's/^/  /'

sep "Outros suspeitos"
d ~/Library/Caches ~/Library/Containers/com.apple.Preview ~/.serverless \
  ~/Library/Application\ Support/Slack ~/Library/Application\ Support/discord \
  ~/Library/Application\ Support/Postman ~/.Trash | sort -rh

sep "Fim"
echo "Nada foi apagado. Categorize os achados e confirme cada remoção antes de executar."
