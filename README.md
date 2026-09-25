# .dotfiles

Mi configuración personal para Fedora (KDE y GNOME) y macOS: la shell, git, ssh, el editor, la terminal y la lista de todo lo que instalo. Con un `git clone` y un `./install.sh`, un equipo recién formateado queda como los demás.

Si llegaste aquí buscando ideas para tus propios dotfiles, siéntete libre de copiar lo que te sirva. Está pensado para leerse: cada decisión tiene su porqué más abajo.

## Qué incluye

| Paquete | Qué configura | Dónde se instala |
|---|---|---|
| `zsh` | zsh con Oh My Zsh, Powerlevel10k, nvm y alias | Todos |
| `git` | `.gitconfig` (usa `gh` para las credenciales de GitHub) | Todos |
| `ssh` | `~/.ssh/config` con los alias de mis servidores, **sin IPs ni llaves** | Todos |
| `claude` | Reglas globales de Claude Code (`~/.claude/rules/`) | Todos |
| `vscodium` | `settings.json` de VSCodium y la lista de extensiones | Equipos con escritorio |
| `konsole` | Perfil de Konsole (zsh + JetBrainsMono Nerd Font) | Solo KDE |
| `vicinae` | Configuración del lanzador Vicinae | Solo KDE |
| `hyper`, `raycast` | Terminal y lanzador del Mac | Solo Mac *(pendiente)* |

Además de los archivos de configuración, `install.sh` instala:

- Los paquetes de `packages/` (ver [Listas de paquetes](#listas-de-paquetes)).
- La fuente JetBrainsMono Nerd Font.
- Oh My Zsh, Powerlevel10k y los plugins `zsh-autosuggestions` y `zsh-syntax-highlighting`.
- nvm con Node LTS.
- Claude Code con las skills de Context7 (modo CLI) y herdr.
- Las extensiones de VSCodium.

## Estructura

```
.dotfiles/
├── zsh/            .zshrc, .p10k.zsh y .config/zsh/{aliases,linux,mac}.zsh
├── git/            .gitconfig
├── ssh/            .ssh/config
├── claude/         .claude/rules/markdown.md
├── vscodium/       settings.json (una sola copia para Linux y Mac) + extensions
├── konsole/        perfil de Konsole
├── vicinae/        settings.json de Vicinae
├── packages/       listas de lo que se instala en cada sistema
├── install.sh      instala y enlaza todo
└── README.md
```

Cada carpeta de primer nivel (salvo `packages/`) es un **paquete de [GNU Stow](https://www.gnu.org/software/stow/)**. Dentro de un paquete, los archivos están en la misma ruta que tendrían dentro de `~`. Por ejemplo, `zsh/.config/zsh/aliases.zsh` termina enlazado en `~/.config/zsh/aliases.zsh`.

## Instalación

### En un equipo nuevo

```bash
# 1. Clonar el repo en ~/.dotfiles (tiene que ser esa ruta)
git clone https://github.com/etejedaw/dotfiles.git ~/.dotfiles

# 2. Ver qué va a hacer, sin cambiar nada
~/.dotfiles/install.sh --dry-run

# 3. Instalar
~/.dotfiles/install.sh
```

En un equipo nuevo todavía no hay llave SSH, por eso el clone va por HTTPS. Si el repo fuera privado, primero `gh auth login` y después `gh repo clone etejedaw/dotfiles ~/.dotfiles`.

`install.sh` se puede ejecutar todas las veces que quieras: cada paso revisa si ya está hecho antes de hacerlo. Pide `sudo` cuando lo necesita (para `dnf`), pero **no** se ejecuta como root.

Si en `~` ya existe un archivo real donde tiene que ir un symlink (por ejemplo, el `.zshrc` que trae el sistema), el script no lo borra: lo mueve a `~/.dotfiles-backup/<fecha>/`.

Durante la instalación, Context7 abre el navegador para iniciar sesión. Es normal.

### Pasos manuales

Hay cosas que no pueden (o no deben) estar en un repo público. Al terminar, `install.sh` las lista:

- **GitHub:** `gh auth login` (HTTPS y navegador).
- **Llaves SSH:** copiarlas a `~/.ssh/` desde el gestor de contraseñas, o generar nuevas y registrar la pública donde corresponda.
- **IPs de los servidores:** crear `~/.ssh/config.d/hosts` (ver [SSH](#ssh)).
- **Secretos y cosas de un solo equipo:** en `~/.zshrc.local`, que se carga al final de `.zshrc` y no está en el repo.
- **Docker (Fedora):** `sudo systemctl enable --now docker && sudo usermod -aG docker $USER`.
- **AFFiNE (Fedora):** no está en Flathub, se instala a mano.
- **Mac:** `p10k configure` si los íconos no se ven bien.

## Cómo funciona

### Stow y los symlinks

Stow crea un symlink en `~` por cada archivo de un paquete. Como `~/.zshrc` apunta a `~/.dotfiles/zsh/.zshrc`, cualquier cambio que hagas en tu configuración (a mano o desde la interfaz de un programa) queda directamente en el repo. Solo falta hacer commit.

Los comandos siempre llevan `--no-folding`. Sin esa opción, Stow enlaza carpetas enteras (por ejemplo, todo `~/.config/zsh/`) y lo que un programa cree después en esa carpeta terminaría dentro del repo.

```bash
cd ~/.dotfiles
stow -t ~ --no-folding -n -v zsh   # simulacro: muestra qué haría
stow -t ~ --no-folding zsh         # crea los symlinks
stow -t ~ --no-folding -R zsh      # los rehace (después de agregar archivos al paquete)
stow -t ~ -D zsh                   # los quita
```

Para comprobar que quedó bien: `ls -la ~/.zshrc` tiene que mostrar `-> .dotfiles/zsh/.zshrc`.

### Qué se instala en cada equipo

`install.sh` decide según el sistema y el escritorio. El escritorio se detecta por lo que hay instalado (`plasmashell` o `gnome-shell`), así que funciona igual si lo ejecutas por SSH.

| | Fedora KDE | Fedora GNOME | Fedora Server | Mac |
|---|---|---|---|---|
| `zsh git ssh claude` | ✓ | ✓ | ✓ | ✓ |
| `vscodium` | ✓ | ✓ | | ✓ |
| `konsole vicinae` | ✓ | | | |
| `hyper raycast` | | | | ✓ |
| Apps de Flathub | ✓ | ✓ | | |

### zsh

`.zshrc` es común a todos los sistemas y carga tres archivos de `~/.config/zsh/`:

- `linux.zsh` o `mac.zsh`, según `uname`. Se cargan **antes** de Oh My Zsh, porque definen rutas que Oh My Zsh necesita al arrancar (los highlighters y el `FPATH` de Homebrew).
- `aliases.zsh`, **después** de Oh My Zsh, para que mis alias (`ll`, `la`…) pisen los que trae.

Al final se carga `~/.zshrc.local` si existe. Ahí van los tokens y todo lo que es de un solo equipo.

### SSH

`ssh/.ssh/config` tiene los alias de los servidores con su usuario y su llave, pero **no** sus IPs. Las IPs viven fuera del repo, en `~/.ssh/config.d/`, que el config carga con `Include`. SSH combina los bloques `Host` con el mismo nombre, así que basta con esto:

```sshconfig
# ~/.ssh/config.d/hosts  (fuera del repo, permisos 600)
Host home-server
	HostName 192.168.x.x
```

Los alias siguen la convención `<ámbito>-<máquina>`: `home-*` para los equipos de la casa, `vps-*` para los VPS y `client-*` para servidores de clientes. Los clientes van enteros en su propio archivo de `config.d/` (por ejemplo `config.d/client-acme`) y nunca entran al repo.

`IdentitiesOnly yes` hace que cada host reciba solo su llave. Sin eso, con varias llaves en el agente, los servidores cortan la conexión por demasiados intentos fallidos.

### VSCodium

Hay **un solo** `settings.json`, en la ruta de Linux (flatpak). La ruta del Mac es un symlink a ese mismo archivo. Al enlazar, cada sistema ignora la ruta del otro:

```bash
stow -t ~ --no-folding --ignore='Library' vscodium   # Linux
stow -t ~ --no-folding --ignore='\.var' vscodium     # Mac
```

`vscodium/extensions` es solo una lista (no la lee VSCodium) y `.stow-local-ignore` evita que se enlace en `~`.

Ojo: VSCodium no detecta los cambios que no hace él mismo. Después de un `git pull` que cambie `settings.json`, recarga la ventana (`Developer: Reload Window`).

### Listas de paquetes

Todas son texto plano: un paquete por línea, y se ignoran los comentarios (`#`) y las líneas vacías.

| Archivo | Se instala en | Con |
|---|---|---|
| `packages/common` | Todos los equipos. Solo nombres que son iguales en dnf y en brew | `dnf` / `brew` |
| `packages/dnf` | Fedora | `dnf install` |
| `packages/dnf-repos` | Fedora: repos externos que se agregan antes (Docker, gh) | `dnf config-manager addrepo` |
| `packages/flatpak` | Fedora con escritorio | `flatpak install flathub` |
| `packages/brew` | Mac (fórmulas y casks) | `brew install` |
| `packages/equivalencias.md` | Qué programa cumple cada función en cada sistema | — |

## Instalación manual (sin `install.sh`)

Si por alguna razón no puedes usar el script, estos son los mismos pasos a mano. Ejecútalos en orden.

### 1. Paquetes

**Fedora:**

```bash
cd ~/.dotfiles
sudo dnf install -y dnf5-plugins
# Repos externos (solo si no están ya en /etc/yum.repos.d/)
for url in $(sed 's/#.*//' packages/dnf-repos); do sudo dnf config-manager addrepo --from-repofile="$url"; done
sudo dnf install -y $(sed 's/#.*//' packages/common packages/dnf)
# Apps gráficas (solo con escritorio)
flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak install --user -y flathub $(sed 's/#.*//' packages/flatpak)
```

**Mac:**

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/opt/homebrew/bin/brew shellenv)"
cd ~/.dotfiles
brew install $(sed 's/#.*//' packages/common packages/brew)
```

### 2. Symlinks

Si Stow se queja de un conflicto, es porque ya existe un archivo real en `~`: muévelo a otro lado (o bórralo si no lo necesitas) y vuelve a intentar.

```bash
cd ~/.dotfiles
mkdir -p ~/.ssh/config.d && chmod 700 ~/.ssh ~/.ssh/config.d
stow -t ~ --no-folding zsh git ssh claude
chmod 600 ~/.dotfiles/ssh/.ssh/config

# Linux con escritorio
stow -t ~ --no-folding --ignore='Library' vscodium
# Solo KDE
stow -t ~ --no-folding konsole vicinae

# Mac
stow -t ~ --no-folding --ignore='\.var' vscodium
```

### 3. Fuente

```bash
# Fedora
mkdir -p ~/.local/share/fonts/JetBrainsMonoNerdFont
curl -fsSL https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz | tar -xJ -C ~/.local/share/fonts/JetBrainsMonoNerdFont
fc-cache -f

# Mac
brew install --cask font-jetbrains-mono-nerd-font
```

### 4. Oh My Zsh, Powerlevel10k y plugins

```bash
# --keep-zshrc: que no reemplace el .zshrc (ya es el symlink al repo)
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended --keep-zshrc

git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/.oh-my-zsh/custom/themes/powerlevel10k

# Plugins: vienen del gestor de paquetes y Oh My Zsh los carga a través de un symlink
SHARE=/usr/share                      # Fedora
# SHARE="$(brew --prefix)/share"      # Mac
for p in zsh-autosuggestions zsh-syntax-highlighting; do
  mkdir -p ~/.oh-my-zsh/custom/plugins/$p
  ln -sfn "$SHARE/$p/$p.zsh" ~/.oh-my-zsh/custom/plugins/$p/$p.plugin.zsh
done
```

### 5. nvm y Node

```bash
# PROFILE=/dev/null: que no escriba en .zshrc (nvm lo carga el plugin de Oh My Zsh)
curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.8/install.sh | PROFILE=/dev/null bash
. ~/.nvm/nvm.sh && nvm install --lts
```

### 6. Claude Code y sus skills

```bash
curl -fsSL https://claude.ai/install.sh | bash
npx -y skills@latest add herdrdev/herdr --skill herdr -g -a claude-code -y
npx -y ctx7@latest setup --claude --cli -y     # abre el navegador para iniciar sesión
```

### 7. Extensiones de VSCodium

```bash
# Fedora (flatpak)
xargs -n1 flatpak run com.vscodium.codium --install-extension < ~/.dotfiles/vscodium/extensions
# Mac
xargs -n1 codium --install-extension < ~/.dotfiles/vscodium/extensions
```

### 8. Shell por defecto

```bash
chsh -s "$(command -v zsh)"
```

Después, los [pasos manuales](#pasos-manuales) y abrir una terminal nueva.

## Uso diario

- **Cambiaste algo en un equipo:** como es un symlink, ya estás editando el repo. `git add`, `git commit` y `git push`.
- **En los demás equipos:** `git pull`. Si el cambio agregó un paquete de Stow o un programa nuevo, vuelve a ejecutar `./install.sh`.
- **Instalaste un programa nuevo:** agrégalo a su lista en `packages/` y, si reemplaza a otro en otro sistema, a `packages/equivalencias.md`.
- **Instalaste o quitaste una extensión de VSCodium:** regenera la lista con `flatpak run com.vscodium.codium --list-extensions > ~/.dotfiles/vscodium/extensions` (en Mac, `codium --list-extensions`).

## Agregar configuración nueva

### Un archivo a un paquete que ya existe

Por ejemplo, una regla nueva de Claude:

```bash
mv ~/.claude/rules/mi-regla.md ~/.dotfiles/claude/.claude/rules/
cd ~/.dotfiles && stow -t ~ --no-folding -R claude
```

### Un programa nuevo

Supongamos que quieres versionar la configuración de `btop`, que vive en `~/.config/btop/btop.conf`:

1. Crea el paquete copiando la ruta relativa a `~`:
   ```bash
   mkdir -p ~/.dotfiles/btop/.config/btop
   mv ~/.config/btop/btop.conf ~/.dotfiles/btop/.config/btop/
   ```
2. Enlázalo y comprueba el symlink:
   ```bash
   cd ~/.dotfiles && stow -t ~ --no-folding btop
   ls -la ~/.config/btop/btop.conf
   ```
3. Cambia algo desde el propio programa y revisa `git status`: el cambio tiene que aparecer en el repo. Si no aparece, el programa reemplazó el symlink por un archivo nuevo al guardar, y hay que buscar otra forma (por ejemplo, un archivo de configuración aparte que el programa importe).
4. Agrega el paquete a `install.sh` (ver [más abajo](#agregar-un-paquete-de-stow)).
5. Antes del commit, revisa que el archivo no tenga tokens, IPs ni rutas personales: el repo es público.

**Solo versiona tu configuración.** Nada de cachés, logs, bases de datos, historiales ni archivos que el programa reescribe solo. Si un archivo aparece modificado en `git status` sin que hayas cambiado nada, probablemente no debería estar en el repo.

### Algo que cambia según el sistema

- **Una línea de zsh:** va en `linux.zsh` o `mac.zsh`.
- **Un archivo en rutas distintas en cada sistema:** un solo paquete con las dos rutas, donde una es un symlink relativo a la otra, y un `--ignore` distinto en cada sistema (como `vscodium`).
- **Un programa que solo existe en un sistema:** su propio paquete, que `install.sh` enlaza solo donde corresponde.

## Editar `install.sh`

### Cómo está organizado

El script va de arriba abajo en secciones numeradas (`# --- 1. Paquetes ---`, `# --- 2. Symlinks con Stow ---`…). Antes de la primera sección:

- **Variables:** `DOTFILES` (la carpeta del repo), `NVM_VERSION`, `BACKUP_DIR`…
- **Detección:** `OS` (`Darwin` o `Linux`), `DESKTOP` y `KDE` (`yes` o `no`).
- **Funciones de ayuda:**

| Función | Para qué |
|---|---|
| `step "texto"` | Título de un paso |
| `info "texto"` / `warn "texto"` | Mensajes normales y avisos |
| `run comando…` | Ejecuta el comando, o solo lo muestra con `--dry-run`. **Todo lo que cambie algo tiene que pasar por `run`** |
| `list archivo` | Lee una lista de `packages/` sin comentarios |
| `stow_pkg paquete [regex]` | Respalda los conflictos y enlaza el paquete. El segundo argumento es opcional y se pasa a `--ignore` |

### Agregar un paquete de Stow

En la sección `2. Symlinks con Stow`, agrégalo a la línea que corresponda:

```bash
for pkg in zsh git ssh claude btop; do stow_pkg "$pkg"; done          # todos los equipos
for pkg in konsole vicinae; do stow_pkg "$pkg"; done                  # solo KDE
```

### Agregar un paso

Cada paso tiene la misma forma: comprueba si ya está hecho y, si no, lo hace a través de `run`. Así el script se puede ejecutar varias veces sin romper nada.

```bash
step "Mi herramienta"
if command -v mi-herramienta >/dev/null; then
  info "ya instalada"
else
  run bash -c 'curl -fsSL https://ejemplo.com/install.sh | bash'
fi
```

- **Instaladores con `curl … | bash`:** ponlos entre comillas dentro de `run bash -c '…'`, para que con `--dry-run` no se descarguen.
- **Instaladores que escriben en `.zshrc`:** muchos lo hacen (nvm, por ejemplo). Como `.zshrc` es un archivo del repo, busca en su documentación cómo evitarlo, como el `PROFILE=/dev/null` de nvm. Si alguno se cuela igual, al terminar el script avisa que hay archivos del repo modificados.
- **Pasos que dependen del sistema:** usa `[[ $OS == Darwin ]]`, `[[ $DESKTOP == yes ]]` o `[[ $KDE == yes ]]`.

### Probar los cambios

```bash
bash -n install.sh                # sintaxis
npx -y shellcheck install.sh      # errores comunes de bash
./install.sh --dry-run            # qué haría en este equipo
```

## Lo que queda fuera, a propósito

- **Llaves SSH, IPs y servidores de clientes:** en el gestor de contraseñas y en `~/.ssh/config.d/`.
- **Tokens y secretos:** en `~/.zshrc.local`.
- **Código de terceros:** Oh My Zsh, Powerlevel10k, los plugins y nvm. Los instala `install.sh`.
- **Configuración completa de KDE** (`kwinrc`, `plasma-*`…): cambia sola todo el tiempo.
- **Historiales, cachés y logs.**

## Licencia

[GPL-3.0](LICENSE).
