# Variables y PATH de brew: nada más los carga (no hay ~/.zprofile). /etc/paths.d/homebrew solo agrega brew al PATH
if [[ -z $HOMEBREW_PREFIX && -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv zsh)"
fi

# HOMEBREW_PREFIX lo define `brew shellenv`; si falta, se consulta a brew
BREW_PREFIX="${HOMEBREW_PREFIX:-$(brew --prefix)}"

# Autocompletado de los paquetes de brew (gh, etc.)
FPATH="$BREW_PREFIX/share/zsh/site-functions:${FPATH}"

# zsh-syntax-highlighting instalado con brew
export ZSH_HIGHLIGHT_HIGHLIGHTERS_DIR=$BREW_PREFIX/share/zsh-syntax-highlighting/highlighters
