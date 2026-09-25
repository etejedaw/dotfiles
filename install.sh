#!/usr/bin/env bash
# Instala y enlaza los dotfiles. Se puede ejecutar varias veces: cada paso revisa si ya está hecho.
#
#   ./install.sh            instala
#   ./install.sh --dry-run  muestra lo que haría, sin cambiar nada

set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES="$DOTFILES/packages"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
NVM_VERSION="v0.40.8"
DRY_RUN=no
[[ "${1:-}" == "--dry-run" || "${1:-}" == "-n" ]] && DRY_RUN=yes

# --- Utilidades ---

step() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
info() { printf '    %s\n' "$*"; }
warn() { printf '\033[1;33m    ! %s\033[0m\n' "$*"; }

# Ejecuta un comando, o solo lo muestra en --dry-run
run() {
  if [[ $DRY_RUN == yes ]]; then
    printf '    [dry-run] %s\n' "$*"
  else
    "$@"
  fi
}

# Lee una lista de packages/ sin comentarios ni líneas vacías
list() { sed 's/#.*//' "$PACKAGES/$1" | xargs -n1; }

# --- Detección del sistema ---

OS="$(uname)"
case "$OS" in
  Darwin) ;;
  Linux)
    [[ -f /etc/fedora-release ]] || { echo "Solo se soporta Fedora en Linux." >&2; exit 1; } ;;
  *) echo "Sistema no soportado: $OS" >&2; exit 1 ;;
esac
[[ $EUID -eq 0 ]] && { echo "No ejecutes install.sh como root: usa tu usuario (pide sudo cuando lo necesita)." >&2; exit 1; }

# Escritorio: se detecta por lo instalado, así funciona también por SSH. En Fedora solo se soportan KDE y GNOME.
KDE=no
if [[ $OS == Linux ]]; then
  if command -v plasmashell >/dev/null; then
    KDE=yes
  elif ! command -v gnome-shell >/dev/null; then
    echo "No se encontró KDE ni GNOME: solo se soporta Fedora con escritorio." >&2; exit 1
  fi
fi

step "Sistema: $OS · KDE: $KDE · dry-run: $DRY_RUN"

# Estado del repo al empezar: al final se avisa si algún instalador modificó archivos del repo
REPO_STATUS_BEFORE=$(git -C "$DOTFILES" status --porcelain 2>/dev/null || true)

# --- 1. Paquetes ---

install_mac_packages() {
  if ! command -v brew >/dev/null; then
    step "Instalando Homebrew"
    run /bin/bash -c '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
  fi
  for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    [[ -x $b ]] && eval "$("$b" shellenv)" && break
  done

  step "Paquetes de Homebrew (common + brew)"
  local pkgs p
  pkgs=$( (list common; list brew) | sort -u)
  # Paquetes de taps externos (<usuario>/<tap>/<paquete>): Homebrew pide confianza explícita para cargarlos.
  # Sin --formula ni --cask, brew trust deduce el tipo mirando el tap.
  for p in $pkgs; do
    [[ $p == */*/* ]] || continue
    run brew tap "${p%/*}"
    run brew trust "$p"
  done
  # Solo instala lo que falta: las actualizaciones quedan para autoupdate (algunos casks piden sudo al actualizar)
  # shellcheck disable=SC2086
  [[ -n $pkgs ]] && run env HOMEBREW_NO_INSTALL_UPGRADE=1 brew install $pkgs

  step "Actualizaciones automáticas de Homebrew"
  if brew autoupdate status 2>/dev/null | grep -q 'installed and running'; then
    info "ya activas"
  else
    run brew tap domt4/autoupdate
    run brew trust --command domt4/autoupdate/autoupdate
    # Cada 12 h y al iniciar sesión: actualiza fórmulas y casks, limpia versiones viejas y pide sudo con una ventana
    run brew autoupdate start 12h --upgrade --cleanup --immediate --sudo
  fi
}

install_fedora_packages() {
  step "Repos de dnf"
  rpm -q dnf5-plugins >/dev/null || run sudo dnf install -y dnf5-plugins
  local url
  for url in $(list dnf-repos); do
    if [[ -f /etc/yum.repos.d/$(basename "$url") ]]; then
      info "ya existe: $(basename "$url")"
    else
      run sudo dnf config-manager addrepo --from-repofile="$url"
    fi
  done

  step "Paquetes de dnf (common + dnf)"
  local missing=() p
  for p in $( (list common; list dnf) | sort -u); do
    rpm -q "$p" >/dev/null 2>&1 || missing+=("$p")
  done
  if (( ${#missing[@]} )); then
    run sudo dnf install -y "${missing[@]}"
  else
    info "todo instalado"
  fi

  step "Apps de Flathub"
  run flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
  local installed apps=() app
  installed=$(flatpak list --app --columns=application)
  for app in $(list flatpak); do
    grep -qx "$app" <<<"$installed" || apps+=("$app")
  done
  if (( ${#apps[@]} )); then
    run flatpak install --user -y --noninteractive flathub "${apps[@]}"
  else
    info "todo instalado"
  fi

  # No está en Flathub: se instala el .flatpak de la última versión en GitHub (no se actualiza con flatpak update)
  step "AFFiNE (.flatpak de GitHub)"
  if flatpak info pro.affine.app >/dev/null 2>&1; then
    info "ya instalado"
  else
    run bash -c 'set -e
      url=$(curl -fsSL https://api.github.com/repos/toeverything/AFFiNE/releases/latest | grep -o "https://[^\"]*linux-x64\.flatpak" | head -1)
      file=$(mktemp --suffix=.flatpak)
      curl -fsSL "$url" -o "$file"
      flatpak install --user -y --noninteractive "$file"
      rm -f "$file"'
  fi

  # No está en dnf: se descarga el binario de la última versión en GitHub (no se actualiza solo)
  step "git-flow-next (binario de GitHub)"
  if [[ -x $HOME/.local/bin/git-flow ]]; then
    info "ya instalado"
  else
    local arch
    case "$(uname -m)" in
      aarch64) arch=arm64 ;;
      *) arch=amd64 ;;
    esac
    # shellcheck disable=SC2016  # las variables las expande el bash -c, no este script
    run env ARCH="$arch" bash -c 'set -e
      url=$(curl -fsSL https://api.github.com/repos/gittower/git-flow-next/releases/latest | grep -o "https://[^\"]*linux-$ARCH\.tar\.gz" | head -1)
      mkdir -p "$HOME/.local/bin"
      curl -fsSL "$url" | tar -xz -C "$HOME/.local/bin" git-flow'
  fi
}

if [[ $OS == Darwin ]]; then install_mac_packages; else install_fedora_packages; fi

# Mismo instalador en Mac y Fedora: deja el binario en ~/.local/bin y se actualiza con `herdr update`
step "herdr"
if [[ -x $HOME/.local/bin/herdr ]]; then
  info "ya instalado"
else
  run bash -c 'curl -fsSL https://herdr.dev/install.sh | sh'
fi

# --- 2. Symlinks con Stow ---

# Si en ~ hay un archivo real donde va un symlink, Stow se niega. Se mueve a BACKUP_DIR.
# $1 = paquete, $2 = regex de rutas a ignorar (opcional, como --ignore de stow)
CONFLICTS=0
backup_conflicts() {
  local pkg=$1 ignore=${2:-} rel target
  CONFLICTS=0
  while IFS= read -r rel; do
    [[ $rel == .stow-local-ignore || $rel == extensions ]] && continue
    [[ -n $ignore && $rel =~ ^$ignore ]] && continue
    target="$HOME/$rel"
    [[ -e $target || -L $target ]] || continue
    [[ "$(readlink -f "$target")" == "$(readlink -f "$DOTFILES/$pkg/$rel")" ]] && continue
    info "respaldo: ~/$rel → ${BACKUP_DIR/#$HOME/~}/$rel"
    CONFLICTS=$((CONFLICTS + 1))
    run mkdir -p "$(dirname "$BACKUP_DIR/$rel")"
    run mv "$target" "$BACKUP_DIR/$rel"
  done < <(cd "$DOTFILES/$pkg" && find . \( -type f -o -type l \) | sed 's#^\./##')
}

# $1 = paquete, $2 = regex para --ignore (opcional)
stow_pkg() {
  local pkg=$1 ignore=${2:-} args=(-d "$DOTFILES" -t "$HOME" --no-folding)
  [[ -d $DOTFILES/$pkg ]] || { warn "no existe el paquete '$pkg', se omite"; return; }
  [[ -n $ignore ]] && args+=(--ignore="$ignore")
  backup_conflicts "$pkg" "$ignore"
  info "stow $pkg"
  if [[ $DRY_RUN == yes ]]; then
    # con respaldos pendientes, el simulacro de stow avisaría de conflictos que en la ejecución real ya no están
    (( CONFLICTS )) && return
    stow "${args[@]}" -n "$pkg" 2>&1 | grep -v 'simulation mode' | sed 's/^/    /' || true
  else
    stow "${args[@]}" -R "$pkg"
  fi
}

step "Symlinks"
# ~/.ssh tiene que existir con 700 antes de enlazar (si lo crea Stow queda en 755)
run mkdir -p "$HOME/.ssh/config.d"
run chmod 700 "$HOME/.ssh" "$HOME/.ssh/config.d"

for pkg in zsh git ssh claude herdr; do stow_pkg "$pkg"; done
if [[ $OS == Darwin ]]; then
  stow_pkg vscodium '\.var'
  stow_pkg hyper
else
  stow_pkg vscodium 'Library'
  if [[ $KDE == yes ]]; then
    for pkg in konsole vicinae; do stow_pkg "$pkg"; done
  fi
fi
run chmod 600 "$DOTFILES/ssh/.ssh/config"

# --- 3. Fuente ---

step "Fuente JetBrainsMono Nerd Font"
if [[ $OS == Darwin ]]; then
  if brew list --cask font-jetbrains-mono-nerd-font >/dev/null 2>&1; then
    info "ya instalada"
  else
    run brew install --cask font-jetbrains-mono-nerd-font
  fi
else
  FONT_DIR="$HOME/.local/share/fonts/JetBrainsMonoNerdFont"
  if compgen -G "$FONT_DIR/*.ttf" >/dev/null; then
    info "ya instalada"
  else
    run mkdir -p "$FONT_DIR"
    run bash -c "curl -fsSL https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz | tar -xJ -C '$FONT_DIR'"
    run fc-cache -f
  fi
fi

# --- 4. Oh My Zsh, Powerlevel10k y plugins ---

step "Oh My Zsh"
if [[ -d $HOME/.oh-my-zsh ]]; then
  info "ya instalado"
else
  # --keep-zshrc: no toca el ~/.zshrc (que ya es el symlink al repo)
  run bash -c 'sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended --keep-zshrc'
fi

step "Powerlevel10k"
P10K_DIR="$HOME/.oh-my-zsh/custom/themes/powerlevel10k"
if [[ -d $P10K_DIR ]]; then
  info "ya instalado"
else
  run git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"
fi

step "Plugins de zsh (del gestor de paquetes)"
if [[ $OS == Darwin ]]; then SHARE="$(brew --prefix)/share"; else SHARE=/usr/share; fi
for plugin in zsh-autosuggestions zsh-syntax-highlighting; do
  dir="$HOME/.oh-my-zsh/custom/plugins/$plugin"
  run mkdir -p "$dir"
  run ln -sfn "$SHARE/$plugin/$plugin.zsh" "$dir/$plugin.plugin.zsh"
done

# --- 5. nvm y Node ---

step "nvm y Node LTS"
export NVM_DIR="$HOME/.nvm"
if [[ -s $NVM_DIR/nvm.sh ]]; then
  info "nvm ya instalado"
else
  # PROFILE=/dev/null: que no escriba en ~/.zshrc (lo carga el plugin nvm de Oh My Zsh)
  run bash -c "curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/$NVM_VERSION/install.sh | PROFILE=/dev/null bash"
fi
if [[ $DRY_RUN == yes ]]; then
  info "[dry-run] nvm install --lts"
else
  set +u
  # shellcheck source=/dev/null
  . "$NVM_DIR/nvm.sh"
  nvm install --lts
  set -u
fi

# --- 6. Claude Code ---

step "Claude Code"
if [[ -x $HOME/.local/bin/claude ]]; then
  info "ya instalado"
else
  # Con ~/.local/bin en el PATH el instalador no tiene que agregarlo a la config de la shell (ya lo hace .zshrc)
  run env PATH="$HOME/.local/bin:$PATH" bash -c 'curl -fsSL https://claude.ai/install.sh | bash'
fi

step "Skills de Claude"
if [[ -e $HOME/.claude/skills/herdr ]]; then
  info "herdr ya instalada"
else
  run npx -y skills@latest add herdrdev/herdr --skill herdr -g -a claude-code -y
fi
if [[ -e $HOME/.claude/skills/find-docs ]]; then
  info "Context7 ya configurado"
else
  # Modo CLI + skill (sin servidor MCP). Abre el navegador para iniciar sesión en Context7.
  run npx -y ctx7@latest setup --claude --cli -y
fi

# --- 7. Extensiones de VSCodium ---

step "Extensiones de VSCodium"
if [[ $OS == Darwin ]]; then codium_cmd=(codium); else codium_cmd=(flatpak run com.vscodium.codium); fi
if [[ $OS == Darwin ]] && ! command -v codium >/dev/null; then
  warn "VSCodium no está instalado: se omiten las extensiones"
elif [[ $OS == Linux ]] && ! flatpak info com.vscodium.codium >/dev/null 2>&1; then
  warn "VSCodium no está instalado: se omiten las extensiones"
else
  installed=$("${codium_cmd[@]}" --list-extensions 2>/dev/null || true)
  while IFS= read -r ext; do
    [[ -z $ext ]] && continue
    if grep -qix "$ext" <<<"$installed"; then
      info "ya instalada: $ext"
    else
      run "${codium_cmd[@]}" --install-extension "$ext"
    fi
  done < "$DOTFILES/vscodium/extensions"
fi

# --- 8. Shell por defecto ---

step "Shell por defecto"
if [[ "$(basename "${SHELL:-}")" == zsh ]]; then
  info "ya es zsh"
else
  run chsh -s "$(command -v zsh)"
fi

# --- 9. Pasos manuales ---

step "Listo. Pasos manuales pendientes:"
cat <<EOF
    - gh auth login   (HTTPS y navegador)
    - Llaves SSH: copiarlas a ~/.ssh/ o generarlas, y crear ~/.ssh/config.d/hosts con los HostName
    - Crear ~/.secrets (600) con los tokens y ~/.zshrc.local con lo de este equipo
    - Abrir una terminal nueva para cargar zsh
EOF
[[ $OS == Darwin ]] && echo "    - p10k configure, si los íconos no se ven bien"
[[ $OS == Darwin ]] && echo "    - Docker: abrir Docker Desktop una vez para aceptar la licencia"
[[ $OS == Linux ]] && echo "    - Docker: sudo systemctl enable --now docker && sudo usermod -aG docker \$USER"
[[ -d $BACKUP_DIR ]] && echo "    - Revisar los archivos respaldados en ${BACKUP_DIR/#$HOME/~}"
if [[ "$(git -C "$DOTFILES" status --porcelain 2>/dev/null || true)" != "$REPO_STATUS_BEFORE" ]]; then
  warn "Algún instalador modificó archivos del repo: revisa 'git -C ${DOTFILES/#$HOME/~} diff'"
fi
exit 0
