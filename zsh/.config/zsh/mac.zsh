# brew en el PATH: en un Mac nuevo nada lo carga (no hay ~/.zprofile). Solo si falta, porque shellenv duplica rutas
if ! command -v brew >/dev/null && [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv zsh)"
fi

# HOMEBREW_PREFIX lo define `brew shellenv`; si falta, se consulta a brew
BREW_PREFIX="${HOMEBREW_PREFIX:-$(brew --prefix)}"

# Autocompletado de los paquetes de brew (gh, etc.)
FPATH="$BREW_PREFIX/share/zsh/site-functions:${FPATH}"

# zsh-syntax-highlighting instalado con brew
export ZSH_HIGHLIGHT_HIGHLIGHTERS_DIR=$BREW_PREFIX/share/zsh-syntax-highlighting/highlighters
