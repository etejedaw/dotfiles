#!/usr/bin/env bash
# Instala y enlaza los dotfiles. Se puede ejecutar varias veces: cada paso revisa si ya está hecho.
#
#   ./install.sh            instala
#   ./install.sh --dry-run  muestra lo que haría, sin cambiar nada
#
# Todo lo que muestra queda también, sin colores, en ~/.local/state/dotfiles/install.log (solo la última ejecución).
#
# Se ejecuta también con el bash 3.2 de un Mac recién instalado: nada de mapfile, arreglos asociativos ni ${var,,}.

set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES="$DOTFILES/packages"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
NVM_VERSION="v0.40.8"
LOG="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/install.log"
readonly DOTFILES PACKAGES BACKUP_DIR NVM_VERSION LOG

# Los define main al empezar y desde ahí no cambian
DRY_RUN=no
OS=
KDE=no

# --- Utilidades ---

step() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
info() { printf '    %s\n' "$*"; }
warn() { printf '\033[1;33m    ! %s\033[0m\n' "$*" >&2; }

# Ejecuta un comando, o solo lo muestra en --dry-run
run() {
  if [[ $DRY_RUN == yes ]]; then
    printf '    [dry-run] %s\n' "$*"
  else
    "$@"
  fi
}

# Pide la contraseña de sudo la primera vez que se necesita y la renueva cada minuto hasta que termina el script.
# Así se escribe una sola vez y el script puede quedar solo. Si no hay nada que instalar, no la pide.
SUDO_KEEPALIVE_PID=
sudo_once() {
  [[ $DRY_RUN == yes || -n $SUDO_KEEPALIVE_PID ]] && return
  sudo -v
  # Se detiene sola si el script muere; on_exit la detiene apenas termina
  while kill -0 "$$" 2>/dev/null; do sudo -n true; sleep 60; done >/dev/null 2>&1 &
  SUDO_KEEPALIVE_PID=$!
}

# Al salir: detiene la renovación de sudo y, si algo falló, dice dónde está el log
# shellcheck disable=SC2329  # la invoca el trap EXIT
on_exit() {
  local code=$?
  if [[ -n $SUDO_KEEPALIVE_PID ]]; then kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true; fi
  if (( code )); then warn "install.sh terminó con error (código $code). Log: ${LOG/#$HOME/\~}"; fi
}

# Lee una lista de packages/ sin comentarios ni líneas vacías
list() { sed 's/#.*//' "$PACKAGES/$1" | xargs -n1; }

is_gnome() { [[ $OS == Linux && $KDE == no ]]; }

# Agrega un valor a una lista de gsettings, si no está ya
gsettings_add() {
  local schema=$1 key=$2 value=$3 list
  list=$(gsettings get "$schema" "$key")
  [[ $list == *"'$value'"* ]] && return
  list=${list#@as }
  if [[ $list == '[]' ]]; then list="['$value']"; else list="${list%]}, '$value']"; fi
  run gsettings set "$schema" "$key" "$list"
}

# Cambia un valor de gsettings, si no lo tiene ya. $1 = schema (con ruta, si es relocatable), $2 = clave,
# $3 = valor en formato GVariant
gsettings_set() {
  if [[ "$(gsettings get "$1" "$2")" == "$3" ]]; then
    info "ya configurado: $2"
  else
    run gsettings set "$1" "$2" "$3"
  fi
}

# Atajo personalizado de GNOME. $1 = id, $2 = nombre, $3 = comando, $4 = atajo
gnome_shortcut() {
  local path="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/$1/"
  local schema="org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$path"
  gsettings_add org.gnome.settings-daemon.plugins.media-keys custom-keybindings "$path"
  run gsettings set "$schema" name "'$2'"
  run gsettings set "$schema" command "'$3'"
  run gsettings set "$schema" binding "'$4'"
}

# --- Inicio ---

# Una opción desconocida detiene todo: con un --dry-run mal escrito se haría la instalación real
parse_args() {
  local arg
  for arg; do
    case "$arg" in
      -n|--dry-run) DRY_RUN=yes ;;
      *) echo "Opción desconocida: $arg (uso: ./install.sh [--dry-run])" >&2; exit 1 ;;
    esac
  done
}

# La salida va a la terminal y al log (sin los códigos de color). La contraseña de sudo no pasa por aquí: sudo la
# pide directo en la terminal. Con -E, la trampa ERR también ve los errores dentro de funciones, y anota el comando
# que falló y su línea, para no tener que adivinarlo leyendo la salida.
start_log() {
  mkdir -p "$(dirname "$LOG")"
  printf '== install.sh %s · %s · %s\n' "$*" "$(date '+%Y-%m-%d %H:%M:%S')" "$(uname -srm)" >"$LOG"
  exec > >(tee >(sed $'s/\e\\[[0-9;]*m//g' >>"$LOG")) 2>&1
  set -E
  trap 'warn "falló en la línea $LINENO: $BASH_COMMAND"' ERR
}

detect_system() {
  OS="$(uname)"
  case "$OS" in
    Darwin) ;;
    Linux)
      [[ -f /etc/fedora-release ]] || { echo "Solo se soporta Fedora en Linux." >&2; exit 1; } ;;
    *) echo "Sistema no soportado: $OS" >&2; exit 1 ;;
  esac
  [[ $EUID -eq 0 ]] && { echo "No ejecutes install.sh como root: usa tu usuario (pide sudo cuando lo necesita)." >&2; exit 1; }

  # Escritorio: se detecta por lo instalado, así funciona también por SSH. En Fedora solo se soportan KDE y GNOME.
  if [[ $OS == Linux ]]; then
    if command -v plasmashell >/dev/null; then
      KDE=yes
    elif ! command -v gnome-shell >/dev/null; then
      echo "No se encontró KDE ni GNOME: solo se soporta Fedora con escritorio." >&2; exit 1
    fi
  fi
}

# --- 1. Paquetes ---

DOCKER_GROUP_ADDED=no  # si es yes, al final se avisa que hay que volver a entrar

install_mac_packages() {
  local b
  if ! command -v brew >/dev/null; then
    step "Instalando Homebrew"
    sudo_once
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
  local installed missing=()
  installed=$( (brew list --formula -1; brew list --cask -1) 2>/dev/null)
  for p in $pkgs; do
    grep -qxF "${p##*/}" <<<"$installed" || missing+=("$p")
  done
  if (( ${#missing[@]} )); then
    sudo_once
    run env HOMEBREW_NO_INSTALL_UPGRADE=1 brew install "${missing[@]}"
  else
    info "todo instalado"
  fi

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
  rpm -q dnf5-plugins >/dev/null || { sudo_once; run sudo dnf install -y dnf5-plugins; }
  local url
  for url in $(list dnf-repos); do
    if [[ -f /etc/yum.repos.d/$(basename "$url") ]]; then
      info "ya existe: $(basename "$url")"
    else
      sudo_once
      run sudo dnf config-manager addrepo --from-repofile="$url"
    fi
  done

  step "Paquetes de dnf (common + dnf)"
  local missing=() p
  for p in $( (list common; list dnf) | sort -u); do
    rpm -q "$p" >/dev/null 2>&1 || missing+=("$p")
  done
  if (( ${#missing[@]} )); then
    sudo_once
    run sudo dnf install -y "${missing[@]}"
  else
    info "todo instalado"
  fi

  step "Docker"
  if systemctl is-enabled --quiet docker 2>/dev/null && systemctl is-active --quiet docker; then
    info "servicio ya activo"
  else
    sudo_once
    run sudo systemctl enable --now docker
  fi
  # id -nG "$USER" lee los grupos guardados, no los de la sesión actual (que no cambian hasta volver a entrar)
  if id -nG "$USER" | tr ' ' '\n' | grep -qx docker; then
    info "$USER ya está en el grupo docker"
  else
    sudo_once
    run sudo usermod -aG docker "$USER"
    DOCKER_GROUP_ADDED=yes
  fi

  step "Apps de Flathub"
  run flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
  local installed apps=() app
  installed=$(flatpak list --app --columns=application)
  for app in $(list flatpak); do
    grep -qxF "$app" <<<"$installed" || apps+=("$app")
  done
  if (( ${#apps[@]} )); then
    run flatpak install --user -y --noninteractive flathub "${apps[@]}"
  else
    info "todo instalado"
  fi
}

# custom-packages baja de GitHub lo que no está en dnf ni en Flathub (en Fedora: AFFiNE, git-flow-next, balenaEtcher,
# Vicinae y su extensión para GNOME) o que Homebrew no deja instalar (en Mac: MarkText).
# Solo instala los que faltan; las actualizaciones son a mano, con `custom-packages update`.
# Si falla (GitHub caído, por ejemplo), se avisa y el resto de la instalación sigue.
install_custom_packages() {
  step "Programas de GitHub (custom-packages)"
  local custom_packages="$DOTFILES/custom-packages/.local/bin/custom-packages"
  if [[ $DRY_RUN == yes ]]; then
    "$custom_packages" ls || warn "custom-packages falló"
  else
    "$custom_packages" install -y || warn "custom-packages falló: revisa ~/.local/state/dotfiles/custom-packages.log"
  fi
}

# Mismo instalador en Mac y Fedora: deja el binario en ~/.local/bin y se actualiza con `herdr update`
install_herdr() {
  step "herdr"
  if [[ -x $HOME/.local/bin/herdr ]]; then
    info "ya instalado"
  else
    # pipefail en cada `curl | sh`: si curl falla, la shell recibe un script vacío y el paso terminaría bien
    run bash -o pipefail -c 'curl -fsSL https://herdr.dev/install.sh | sh'
  fi
}

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
    info "respaldo: ~/$rel → ${BACKUP_DIR/#$HOME/\~}/$rel"
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

link_dotfiles() {
  step "Symlinks"
  # ~/.ssh tiene que existir con 700 antes de enlazar (si lo crea Stow queda en 755)
  run mkdir -p "$HOME/.ssh/config.d"
  run chmod 700 "$HOME/.ssh" "$HOME/.ssh/config.d"

  # custom-packages deja el comando en ~/.local/bin, para `custom-packages update`
  local pkg
  for pkg in zsh git ssh claude herdr custom-packages; do stow_pkg "$pkg"; done
  if [[ $OS == Darwin ]]; then
    stow_pkg vscodium '\.var'
    stow_pkg hyper
  else
    stow_pkg vscodium 'Library'
    stow_pkg vicinae
    if [[ $KDE == yes ]]; then stow_pkg konsole; fi
  fi
  run chmod 600 "$DOTFILES/ssh/.ssh/config"
}

# En KDE, los atajos de Vicinae salen del .desktop del paquete vicinae y lo arranca ~/.config/autostart.
# En GNOME hay que registrarlo todo con gsettings.
configure_vicinae_gnome() {
  step "Vicinae en GNOME"
  # Arranca el servidor con la sesión gráfica. Sin --now: por SSH no hay sesión gráfica donde arrancarlo.
  if systemctl --user is-enabled --quiet vicinae.service 2>/dev/null; then
    info "servicio ya habilitado"
  else
    run systemctl --user enable vicinae.service
  fi
  # Sin sesión gráfica, gsettings no guarda los cambios (y no avisa)
  if [[ -z ${DBUS_SESSION_BUS_ADDRESS:-} ]]; then
    warn "sin sesión gráfica (¿SSH?): la extensión y los atajos de Vicinae se aplicarán al ejecutar install.sh desde el escritorio"
    return
  fi
  # La instala custom-packages; GNOME la carga al volver a entrar a la sesión
  gsettings_add org.gnome.shell enabled-extensions vicinae@dagimg-dot
  # Los mismos atajos que en KDE. GNOME usa Super+Espacio para cambiar el idioma del teclado: se deja solo en la
  # tecla de idioma del teclado.
  if [[ $(gsettings get org.gnome.desktop.wm.keybindings switch-input-source) == *"'<Super>space'"* ]]; then
    run gsettings set org.gnome.desktop.wm.keybindings switch-input-source "['XF86Keyboard']"
    run gsettings set org.gnome.desktop.wm.keybindings switch-input-source-backward "['<Shift>XF86Keyboard']"
  fi
  gnome_shortcut vicinae Vicinae 'vicinae toggle' '<Super>space'
  gnome_shortcut vicinae-clipboard 'Vicinae clipboard' \
    'vicinae deeplink vicinae://launch/clipboard/history?toggle=true' '<Super><Shift>v'
}

# La llave que ssh/.ssh/config usa para github.com. Sin passphrase, para que el script no se detenga a pedirla.
# Se sube a GitHub con `gh auth login -p ssh`, en los pasos manuales del final.
create_ssh_key() {
  step "Llave SSH para GitHub"
  if [[ -f $HOME/.ssh/id_ed25519 ]]; then
    info "ya existe"
  else
    run ssh-keygen -q -t ed25519 -N '' -C "$USER@${HOSTNAME%%.*}" -f "$HOME/.ssh/id_ed25519"
    info "creada: ~/.ssh/id_ed25519"
  fi
}

# --- 3. Fuente y terminal ---

install_font() {
  step "Fuente JetBrainsMono Nerd Font"
  if [[ $OS == Darwin ]]; then
    if brew list --cask font-jetbrains-mono-nerd-font >/dev/null 2>&1; then
      info "ya instalada"
    else
      run brew install --cask font-jetbrains-mono-nerd-font
    fi
    return
  fi
  local font_dir="$HOME/.local/share/fonts/JetBrainsMonoNerdFont"
  if compgen -G "$font_dir/*.ttf" >/dev/null; then
    info "ya instalada"
  else
    run mkdir -p "$font_dir"
    run bash -o pipefail -c "curl -fsSL https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz | tar -xJ -C '$font_dir'"
    run fc-cache -f
  fi
}

# Ptyxis guarda su configuración en dconf, no en archivos: se aplica con gsettings. Usa la misma fuente que Konsole
# y abre las pestañas y ventanas nuevas en la carpeta de la actual.
configure_ptyxis() {
  step "Ptyxis (terminal de GNOME)"
  if ! gsettings list-keys org.gnome.Ptyxis >/dev/null 2>&1; then
    warn "Ptyxis no está instalado: se omite su configuración"
    return
  fi
  if [[ -z ${DBUS_SESSION_BUS_ADDRESS:-} ]]; then
    warn "sin sesión gráfica (¿SSH?): la configuración de Ptyxis se aplicará al ejecutar install.sh desde el escritorio"
    return
  fi
  gsettings_set org.gnome.Ptyxis use-system-font false
  gsettings_set org.gnome.Ptyxis font-name "'JetBrainsMono Nerd Font Mono 11'"
  # Si Ptyxis nunca se abrió no hay perfil todavía: se crea uno y queda como predeterminado
  local profile
  profile=$(gsettings get org.gnome.Ptyxis default-profile-uuid | tr -d "'")
  if [[ -z $profile ]]; then
    profile=$(tr -d - </proc/sys/kernel/random/uuid)
    run gsettings set org.gnome.Ptyxis profile-uuids "['$profile']"
    run gsettings set org.gnome.Ptyxis default-profile-uuid "'$profile'"
  fi
  gsettings_set "org.gnome.Ptyxis.Profile:/org/gnome/Ptyxis/Profiles/$profile/" preserve-directory "'always'"
}

# --- 4. Oh My Zsh, Powerlevel10k y plugins ---

install_oh_my_zsh() {
  step "Oh My Zsh"
  if [[ -d $HOME/.oh-my-zsh ]]; then
    info "ya instalado"
  else
    # --keep-zshrc: no toca el ~/.zshrc (que ya es el symlink al repo)
    run bash -c 'sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended --keep-zshrc'
  fi
}

install_powerlevel10k() {
  step "Powerlevel10k"
  local p10k_dir="$HOME/.oh-my-zsh/custom/themes/powerlevel10k"
  if [[ -d $p10k_dir ]]; then
    info "ya instalado"
  else
    run git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$p10k_dir"
  fi
}

link_zsh_plugins() {
  step "Plugins de zsh (del gestor de paquetes)"
  local share plugin dir
  if [[ $OS == Darwin ]]; then share="$(brew --prefix)/share"; else share=/usr/share; fi
  for plugin in zsh-autosuggestions zsh-syntax-highlighting; do
    dir="$HOME/.oh-my-zsh/custom/plugins/$plugin"
    run mkdir -p "$dir"
    run ln -sfn "$share/$plugin/$plugin.zsh" "$dir/$plugin.plugin.zsh"
  done
}

# --- 5. nvm y Node ---

install_node() {
  step "nvm y Node LTS"
  export NVM_DIR="$HOME/.nvm"
  if [[ -s $NVM_DIR/nvm.sh ]]; then
    info "nvm ya instalado"
  else
    # PROFILE=/dev/null: que no escriba en ~/.zshrc (lo carga el plugin nvm de Oh My Zsh)
    run bash -o pipefail -c "curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/$NVM_VERSION/install.sh | PROFILE=/dev/null bash"
  fi
  if [[ $DRY_RUN == yes ]]; then
    info "[dry-run] nvm install --lts"
    info "[dry-run] nvm alias default 'lts/*'"
    return
  fi
  set +u
  # shellcheck source=/dev/null
  . "$NVM_DIR/nvm.sh"
  nvm install --lts
  # Sin esto el default queda fijo en la primera versión instalada y no sigue a la LTS nueva
  nvm alias default 'lts/*'
  set -u
}

# --- 6. Claude Code ---

install_claude_code() {
  step "Claude Code"
  if [[ -x $HOME/.local/bin/claude ]]; then
    info "ya instalado"
  else
    # Con ~/.local/bin en el PATH el instalador no tiene que agregarlo a la config de la shell (ya lo hace .zshrc)
    run env PATH="$HOME/.local/bin:$PATH" bash -o pipefail -c 'curl -fsSL https://claude.ai/install.sh | bash'
  fi
}

install_claude_skills() {
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
}

# settings.json no está en el repo (Claude Code lo reescribe), así que el hook se registra aquí
register_herdr_hook() {
  step "Hook de herdr para Claude"
  local claude_settings="$HOME/.claude/settings.json" herdr_hook merged
  # shellcheck disable=SC2016  # $HOME queda literal en settings.json; lo expande la shell que lanza el hook
  herdr_hook='$HOME/.claude/hooks/herdr-orchestrator.sh'
  if [[ -f $claude_settings ]] && jq -e --arg c "$herdr_hook" '.hooks.SessionStart[]?.hooks[]? | select(.command == $c)' "$claude_settings" >/dev/null; then
    info "ya registrado"
  elif [[ $DRY_RUN == yes ]]; then
    info "[dry-run] registrar $herdr_hook en $claude_settings"
  else
    [[ -f $claude_settings ]] || echo '{}' >"$claude_settings"
    merged="$(jq --arg c "$herdr_hook" '.hooks.SessionStart += [{hooks: [{type: "command", command: $c}]}]' "$claude_settings")"
    printf '%s\n' "$merged" >"$claude_settings"
  fi
}

# --- 7. Extensiones de VSCodium ---

install_codium_extensions() {
  step "Extensiones de VSCodium"
  local codium_cmd installed ext ext_args=()
  if [[ $OS == Darwin ]]; then codium_cmd=(codium); else codium_cmd=(flatpak run com.vscodium.codium); fi
  if [[ $OS == Darwin ]] && ! command -v codium >/dev/null; then
    warn "VSCodium no está instalado: se omiten las extensiones"
    return
  fi
  if [[ $OS == Linux ]] && ! flatpak info com.vscodium.codium >/dev/null 2>&1; then
    warn "VSCodium no está instalado: se omiten las extensiones"
    return
  fi
  installed=$("${codium_cmd[@]}" --list-extensions 2>/dev/null || true)
  # Todas en una sola llamada: en Fedora cada llamada arranca el flatpak de nuevo (lento y con muchos avisos)
  while IFS= read -r ext; do
    [[ -z $ext ]] && continue
    if grep -qixF "$ext" <<<"$installed"; then
      info "ya instalada: $ext"
    else
      ext_args+=(--install-extension "$ext")
    fi
  done < "$DOTFILES/vscodium/extensions"
  if (( ${#ext_args[@]} )); then run "${codium_cmd[@]}" "${ext_args[@]}"; fi
}

# --- 8. Shell por defecto ---

set_default_shell() {
  step "Shell por defecto"
  if [[ "$(basename "${SHELL:-}")" == zsh ]]; then
    info "ya es zsh"
  else
    # Con sudo, chsh no pide otra vez la contraseña
    sudo_once
    run sudo chsh -s "$(command -v zsh)" "$USER"
  fi
}

# --- 9. Pasos manuales ---

# $1 = estado de `git status --porcelain` al empezar, para avisar si algún instalador modificó archivos del repo
print_manual_steps() {
  local repo_status_before=$1
  step "Listo. Pasos manuales pendientes:"
  cat <<EOF
    - gh auth login -p ssh   (navegador; ofrece subir ~/.ssh/id_ed25519.pub a GitHub: acepta)
    - Llaves SSH de los servidores: copiarlas a ~/.ssh/, y crear ~/.ssh/config.d/hosts con los HostName
    - Crear ~/.secrets (600) con los tokens y ~/.zshrc.local con lo de este equipo
    - Abrir una terminal nueva para cargar zsh
EOF
  if [[ $OS == Darwin ]]; then
    echo "    - p10k configure, si los íconos no se ven bien"
    echo "    - Docker: abrir Docker Desktop una vez para aceptar la licencia"
  fi
  if is_gnome; then
    echo "    - GNOME: cerrar sesión y volver a entrar, para que cargue la extensión de Vicinae y arranque su servidor"
  fi
  if [[ $DOCKER_GROUP_ADDED == yes ]]; then
    echo "    - Docker: cerrar sesión y volver a entrar para usar docker sin sudo"
  fi
  if [[ -d $BACKUP_DIR ]]; then
    echo "    - Revisar los archivos respaldados en ${BACKUP_DIR/#$HOME/\~}"
  fi
  if [[ "$(git -C "$DOTFILES" status --porcelain 2>/dev/null || true)" != "$repo_status_before" ]]; then
    warn "Algún instalador modificó archivos del repo: revisa 'git -C ${DOTFILES/#$HOME/\~} diff'"
  fi
}

main() {
  parse_args "$@"
  readonly DRY_RUN
  trap on_exit EXIT
  start_log "$@"
  detect_system
  readonly OS KDE
  step "Sistema: $OS · KDE: $KDE · dry-run: $DRY_RUN"
  local repo_status_before
  repo_status_before=$(git -C "$DOTFILES" status --porcelain 2>/dev/null || true)

  if [[ $OS == Darwin ]]; then install_mac_packages; else install_fedora_packages; fi
  install_custom_packages
  install_herdr

  link_dotfiles
  if is_gnome; then configure_vicinae_gnome; fi
  create_ssh_key

  install_font
  if is_gnome; then configure_ptyxis; fi

  install_oh_my_zsh
  install_powerlevel10k
  link_zsh_plugins
  install_node
  install_claude_code
  install_claude_skills
  register_herdr_hook
  install_codium_extensions
  set_default_shell

  print_manual_steps "$repo_status_before"
}

main "$@"
