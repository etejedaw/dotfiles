# eza: ls con iconos
alias ls='eza --icons --group-directories-first'
alias ll='eza --icons --group-directories-first -l --git'
alias la='eza --icons --group-directories-first -la --git'
alias lt='eza --icons --tree --level=2'

# bat: cat con colores y números de línea. Si la salida va a un pipe o a un archivo, se comporta igual que cat.
alias cat='bat --paging=never'

alias zshconfig="nano ~/.zshrc"
alias p10k-update='git -C ~/.oh-my-zsh/custom/themes/powerlevel10k pull'
alias yolo='claude --dangerously-skip-permissions'
