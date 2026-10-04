#!/usr/bin/env bash
# setup.sh — bspwm + Catppuccin Latte desktop for Ubuntu 24.04
#
# Run as your normal user (NOT with sudo); it calls sudo itself when needed.
# Safe to re-run: every step checks before it changes anything.
#
#   WM configs  (bspwm sxhkd polybar picom rofi dunst gtk) are always linked;
#               an existing real file/folder is moved to <name>.bak-<date> first.
#   Your shell  (alacritty nvim tmux zsh) is only linked when you do not have
#               one yet, so an existing setup on the notebook is left alone.
#               Pass --force-shell to link them anyway (with .bak-<date> backups).
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$HOME/.config"
FORCE_SHELL=false
[[ ${1:-} == --force-shell ]] && FORCE_SHELL=true

info()  { printf '\033[0;34m[INFO]\033[0m  %s\n' "$*"; }
ok()    { printf '\033[0;32m[ OK ]\033[0m  %s\n' "$*"; }
warn()  { printf '\033[1;33m[WARN]\033[0m  %s\n' "$*"; }
err()   { printf '\033[0;31m[ ERR]\033[0m  %s\n' "$*" >&2; }

if [[ $EUID -eq 0 ]]; then
    err "Do not run this with sudo — configs would land in /root. Run: ./setup.sh"
    exit 1
fi

# ============================================================
# 1. Packages
# ============================================================
PACKAGES=(
    # WM, compositor, bar, launcher, notifications
    bspwm sxhkd picom polybar rofi dunst libnotify-bin
    # Terminal stack
    alacritty zsh tmux git curl btop
    # Neovim/LazyVim helpers (nvim itself is installed from upstream below)
    build-essential ripgrep fd-find unzip xclip
    # Files
    thunar thunar-volman thunar-archive-plugin file-roller gvfs-backends
    # Wallpaper, screenshots, lock screen
    feh flameshot i3lock xss-lock imagemagick ubuntu-wallpapers-noble
    # Audio, brightness, network, polkit
    playerctl udiskie
    pulseaudio-utils wireplumber pavucontrol brightnessctl network-manager-gnome policykit-1-gnome blueman
    # Look & feel
    fonts-noto fonts-noto-color-emoji papirus-icon-theme lxappearance
    # X11 utilities
    x11-utils x11-xserver-utils xinput xdotool mesa-utils arandr
)

info "Installing packages..."
sudo apt-get update -qq
sudo apt-get install -y "${PACKAGES[@]}"
ok "Packages installed"

# ============================================================
# 2. MartianMono Nerd Font (bar, rofi, dunst, terminal)
# ============================================================
# (no `fc-list | grep -q`: grep exits early, fc-list gets SIGPIPE and pipefail fails)
if [[ $(fc-list : family) == *"MartianMono Nerd Font"* ]]; then
    ok "MartianMono Nerd Font already installed"
else
    info "Installing MartianMono Nerd Font..."
    font_dir="$HOME/.local/share/fonts/MartianMono"
    mkdir -p "$font_dir"
    tmp=$(mktemp -d)
    curl -fsSL -o "$tmp/m.tar.xz" \
        https://github.com/ryanoasis/nerd-fonts/releases/latest/download/MartianMono.tar.xz
    tar -xf "$tmp/m.tar.xz" -C "$font_dir"
    rm -rf "$tmp"
    fc-cache -f >/dev/null
    ok "MartianMono Nerd Font installed"
fi

# ============================================================
# 3. Neovim (LazyVim needs >= 0.11; Ubuntu ships 0.9)
# ============================================================
nvim_ok() {
    command -v nvim >/dev/null || return 1
    local v; v=$(nvim --version | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
    [[ ${v%%.*} -gt 0 || ${v#*.} -ge 11 ]]
}
if nvim_ok; then
    ok "Neovim $(nvim --version | head -1 | cut -d' ' -f2) already installed"
else
    info "Installing Neovim (latest stable) to /opt/nvim..."
    tmp=$(mktemp -d)
    curl -fsSL -o "$tmp/nvim.tar.gz" \
        https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz
    sudo rm -rf /opt/nvim
    sudo mkdir -p /opt/nvim
    sudo tar -xzf "$tmp/nvim.tar.gz" -C /opt/nvim --strip-components=1
    sudo ln -sfn /opt/nvim/bin/nvim /usr/local/bin/nvim
    rm -rf "$tmp"
    ok "Neovim $(nvim --version | head -1 | cut -d' ' -f2) installed"
fi

# ============================================================
# 4. oh-my-zsh + plugins, tmux plugin manager
# ============================================================
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    info "Installing oh-my-zsh..."
    had_zshrc=false; [ -e "$HOME/.zshrc" ] && had_zshrc=true
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c \
        "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    # The installer drops its template .zshrc when there was none; remove it
    # so the zshrc from these dotfiles gets linked below.
    $had_zshrc || rm -f "$HOME/.zshrc"
fi
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
for plugin in zsh-autosuggestions zsh-syntax-highlighting; do
    [ -d "$ZSH_CUSTOM/plugins/$plugin" ] || \
        git clone -q --depth 1 "https://github.com/zsh-users/$plugin" "$ZSH_CUSTOM/plugins/$plugin"
done
ok "oh-my-zsh ready"

if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
    git clone -q --depth 1 https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
fi
ok "tmux plugin manager ready"

if [[ $(getent passwd "$USER" | cut -d: -f7) != */zsh ]]; then
    sudo chsh -s "$(command -v zsh)" "$USER"
    ok "Login shell changed to zsh (takes effect on next login)"
fi

# ============================================================
# 4b. Clipboard history (greenclip) and touchpad gestures (touchegg 2.x)
# ============================================================
# Neither is usable from the Ubuntu archive: greenclip is not packaged, and
# Ubuntu's "touchegg" is the abandoned 1.x. Both come from their GitHub releases.
if ! command -v greenclip >/dev/null; then
    mkdir -p "$HOME/.local/bin"
    curl -fsSL -o "$HOME/.local/bin/greenclip" \
        https://github.com/erebe/greenclip/releases/latest/download/greenclip
    chmod +x "$HOME/.local/bin/greenclip"
    ok "greenclip installed to ~/.local/bin"
fi
if ! dpkg-query -W -f='${Version}' touchegg 2>/dev/null | grep -q '^2\.'; then
    info "Installing touchegg 2.x..."
    url=$(curl -fsSL https://api.github.com/repos/JoseExposito/touchegg/releases/latest \
          | grep -oE 'https://[^"]+_amd64\.deb' | head -1 || true)
    if [ -n "$url" ]; then
        curl -fsSL -o /tmp/touchegg.deb "$url"
        sudo apt-get install -y /tmp/touchegg.deb && rm -f /tmp/touchegg.deb
        sudo systemctl enable --now touchegg.service
        ok "touchegg installed"
    else
        warn "Could not fetch touchegg (GitHub rate limit?). Re-run later."
    fi
fi

# ============================================================
# 5. adw-gtk3 — only needed for the optional Catppuccin app theme
#    (gtk-*/gtk-catppuccin.css). The default app theme is Ubuntu's Yaru.
# ============================================================
if [ -d "$HOME/.themes/adw-gtk3" ]; then
    ok "adw-gtk3 already installed"
else
    info "Installing adw-gtk3..."
    mkdir -p "$HOME/.themes"
    url=$(curl -fsSL https://api.github.com/repos/lassekongo83/adw-gtk3/releases/latest \
          | grep -oE 'https://[^"]+\.tar\.xz' | head -1 || true)
    if [ -n "$url" ]; then
        curl -fsSL "$url" | tar -xJ -C "$HOME/.themes"
        ok "adw-gtk3 installed"
    else
        warn "Could not fetch adw-gtk3 (GitHub rate limit?). Re-run later."
    fi
fi

# ============================================================
# 6. Symlink configs
# ============================================================
# link <source in dotfiles> <destination>
link() {
    local src="$DOTFILES_DIR/$1" dst="$2"
    mkdir -p "$(dirname "$dst")"
    if [ -e "$dst" ] && [ ! -L "$dst" ]; then
        local bak; bak="$dst.bak-$(date +%Y%m%d-%H%M%S)"
        mv "$dst" "$bak"
        warn "  backed up $dst → $bak"
    fi
    ln -sfn "$src" "$dst"
    ok "  $1 → $dst"
}

# Like link, but leaves an existing config alone unless --force-shell.
link_if_absent() {
    local dst="$2"
    if [ -L "$dst" ] && [ "$(readlink -f "$dst")" = "$(readlink -f "$DOTFILES_DIR/$1")" ]; then
        ok "  $1 → $dst"
    elif [ -e "$dst" ] && ! $FORCE_SHELL; then
        info "  keeping your existing $dst"
    else
        link "$1" "$dst"
    fi
}

info "Linking WM configs..."
for c in bspwm sxhkd polybar picom rofi dunst; do
    link "$c" "$CONFIG_DIR/$c"
done

# GTK: link the files, not the folders — gtk-3.0 also holds your file
# manager bookmarks. An old whole-folder symlink is replaced by a real folder.
for d in gtk-3.0 gtk-4.0; do
    [ -L "$CONFIG_DIR/$d" ] && rm "$CONFIG_DIR/$d"
    mkdir -p "$CONFIG_DIR/$d"
    link "$d/gtk.css"      "$CONFIG_DIR/$d/gtk.css"
    link "$d/settings.ini" "$CONFIG_DIR/$d/settings.ini"
done
link Xresources "$HOME/.Xresources"
link touchegg/touchegg.conf "$CONFIG_DIR/touchegg/touchegg.conf"

# Launcher entries (e.g. GNOME Settings, which hides itself outside GNOME)
for f in "$DOTFILES_DIR"/applications/*.desktop; do
    link "applications/$(basename "$f")" "$HOME/.local/share/applications/$(basename "$f")"
done

info "Linking shell configs..."
link_if_absent alacritty      "$CONFIG_DIR/alacritty"
link_if_absent nvim           "$CONFIG_DIR/nvim"
link_if_absent tmux/tmux.conf "$HOME/.tmux.conf"
link_if_absent zsh/zshrc      "$HOME/.zshrc"

# Install tmux plugins now that .tmux.conf exists (no-op if already there).
"$HOME/.tmux/plugins/tpm/bin/install_plugins" >/dev/null 2>&1 || \
    warn "tmux plugins not installed yet — press prefix + I inside tmux"

# Execute bits (may fail on a virtiofs/9p share — then set them on the host)
chmod +x "$DOTFILES_DIR"/bspwm/*.sh "$DOTFILES_DIR"/bspwm/bspwmrc \
         "$DOTFILES_DIR"/polybar/launch.sh "$DOTFILES_DIR"/polybar/scripts/*.sh \
         "$DOTFILES_DIR"/rofi/scripts/* 2>/dev/null || \
    warn "chmod failed (shared mount?) — run it from the host side"

# ============================================================
# 7. GTK / desktop settings
# ============================================================
if command -v gsettings >/dev/null; then
    # App theme: Ubuntu's Yaru, as in GNOME. For the Catppuccin app theme use
    # "adw-gtk3", "Papirus-Light" and gtk-*/gtk-catppuccin.css instead.
    # Yaru with the blue accent ("Yaru" alone is Ubuntu's orange). Under bspwm,
    # GTK apps read gtk-*/settings.ini, not these keys: change both together.
    gsettings set org.gnome.desktop.interface gtk-theme    "Yaru-blue"
    gsettings set org.gnome.desktop.interface color-scheme "default"
    gsettings set org.gnome.desktop.interface icon-theme   "Yaru-blue"
    gsettings set org.gnome.desktop.interface font-name    "Ubuntu Sans Medium 11"
    # The bar already shows the keyboard layout; hide IBus's duplicate tray icon.
    gsettings set org.freedesktop.ibus.panel show-icon-on-systray false 2>/dev/null || true
    # IBus grabs Super+Space (switch input method) before sxhkd can see it.
    # Layouts switch with Alt+Shift (XKB) under bspwm; GNOME uses its own
    # switch-input-source shortcut, so this does not affect GNOME.
    gsettings set org.freedesktop.ibus.general.hotkey triggers "[]" 2>/dev/null || true
    if [ -d /usr/share/icons/catppuccin-latte-light-cursors ] || \
       [ -d "$HOME/.icons/catppuccin-latte-light-cursors" ] || \
       [ -d "$HOME/.local/share/icons/catppuccin-latte-light-cursors" ]; then
        gsettings set org.gnome.desktop.interface cursor-theme "catppuccin-latte-light-cursors"
    fi
    ok "GTK settings applied"
fi

mkdir -p "$HOME/Pictures/Screenshots"

# ============================================================
# 8. Login session
# ============================================================
if [ ! -f /usr/share/xsessions/bspwm.desktop ]; then
    sudo tee /usr/share/xsessions/bspwm.desktop >/dev/null <<'EOF'
[Desktop Entry]
Name=bspwm
Comment=Binary space partitioning window manager
Exec=bspwm
Type=XSession
EOF
fi
ok "bspwm session available in the login screen"

echo
ok "Done! Log out, click the gear icon on the login screen, choose 'bspwm'."
cat <<'EOF'

  Super+Enter         terminal              Super+Space      app launcher
  Super+E             file manager          Super+X          power menu
  Super+Q             close window          Super+Shift+X    lock
  Super+H/J/K/L       focus                 Super+Shift+HJKL swap
  Super+1..0          desktop               Super+Shift+1..0 send to desktop
  Super+F / Shift+F   fullscreen / float    Super+M          monocle
  Print               screenshot            Super+Alt+R      reload bspwm
EOF
