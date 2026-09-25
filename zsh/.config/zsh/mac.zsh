# HOMEBREW_PREFIX lo define `brew shellenv`; si falta, se consulta a brew
BREW_PREFIX="${HOMEBREW_PREFIX:-$(brew --prefix)}"

# Autocompletado de los paquetes de brew (gh, etc.)
FPATH="$BREW_PREFIX/share/zsh/site-functions:${FPATH}"

# zsh-syntax-highlighting instalado con brew
export ZSH_HIGHLIGHT_HIGHLIGHTERS_DIR=$BREW_PREFIX/share/zsh-syntax-highlighting/highlighters
