# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export ZSH="$HOME/.oh-my-zsh"
ZSH_CONFIG_DIR="$HOME/.config/zsh"

# El tema lo provee powerlevel10k. Debe quedar vacio.
ZSH_THEME=""

CASE_SENSITIVE="false"
HYPHEN_INSENSITIVE="true"

zstyle ':omz:update' mode auto
zstyle ':omz:update' frequency 7

plugins=(
  git
  git-flow
  git-auto-fetch
  nvm
  npm
  gh
  aws
  jsontools
  fzf
  zsh-autosuggestions
  zsh-syntax-highlighting  # siempre al final
)

# nvm (script oficial en ~/.nvm) — autoswitch por .nvmrc sin ruido en pantalla
export NVM_DIR="$HOME/.nvm"
zstyle ':omz:plugins:nvm' autoload yes
zstyle ':omz:plugins:nvm' silent-autoload yes

# git-auto-fetch — fetch en segundo plano al mostrar el prompt, como mucho cada 120s por repo
GIT_AUTO_FETCH_INTERVAL=120

# Config por sistema — antes de oh-my-zsh.sh, porque define
# ZSH_HIGHLIGHT_HIGHLIGHTERS_DIR y FPATH (compinit corre dentro de oh-my-zsh)
case "$(uname)" in
  Darwin) [[ -f $ZSH_CONFIG_DIR/mac.zsh ]]   && source $ZSH_CONFIG_DIR/mac.zsh ;;
  Linux)  [[ -f $ZSH_CONFIG_DIR/linux.zsh ]] && source $ZSH_CONFIG_DIR/linux.zsh ;;
esac

source $ZSH/oh-my-zsh.sh

# powerlevel10k — despues de oh-my-zsh.sh
source $ZSH/custom/themes/powerlevel10k/powerlevel10k.zsh-theme
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# ./node_modules/.bin  — binarios de devDependencies del proyecto actual (ng, nest, sls, etc.)
#                        Permite usarlos directo sin npx, siempre toma la versión local del proyecto.
# $HOME/.local/bin     — binarios instalados por el usuario (pipx, scripts propios, etc.)
# $PATH                — el resto del PATH existente va al final, con menor prioridad
export PATH="./node_modules/.bin:$HOME/.local/bin:$PATH"

# Aliases — despues de oh-my-zsh.sh, para pisar los que trae (ll, la, etc.)
[[ -f $ZSH_CONFIG_DIR/aliases.zsh ]] && source $ZSH_CONFIG_DIR/aliases.zsh

# Tokens y contraseñas (solo export, permisos 600). NO está en el repo.
[[ -f ~/.secrets ]] && source ~/.secrets

# Alias, funciones y cosas de un solo equipo. NO está en el repo.
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local

# Quita las rutas repetidas de PATH y FPATH (brew shellenv y /etc/paths.d agregan las mismas).
# Va al final: con `PATH=...` zsh no las quita, solo al aplicar -U sobre el array ya armado.
typeset -U path fpath
