# dotfiles

bspwm desktop for Ubuntu 24.04 with Catppuccin Latte colours: frosted
(blurred) windows, a floating pill-style polybar, rofi menus, and the
Alacritty + zsh + tmux + Neovim (LazyVim) terminal stack. Apps use Ubuntu's
Yaru-blue theme.

Tested on an Ubuntu 24.04 notebook (Intel + NVIDIA) and in a QEMU/KVM VM.

## Install

```bash
git clone https://github.com/gabrieldelmonte/dotfiles.git ~/.config/dotfiles
cd ~/.config/dotfiles
./setup.sh          # as your user, not with sudo
```

Then log out and pick **bspwm** from the gear menu on the login screen.
`setup.sh` installs the packages, fonts (MartianMono Nerd Font), Neovim,
oh-my-zsh, TPM, greenclip and touchegg, then symlinks everything into place.
Existing files are moved to `*.bak-<date>`; existing Alacritty / nvim / tmux /
zsh configs are kept unless you pass `--force-shell`.

## Keys

Press **Super + \\** (or **Super + /**) for a searchable cheat sheet of every
desktop and tmux binding. The essentials:

| Keys | Action |
|---|---|
| Super + Enter | Terminal |
| Super + Space | App launcher |
| Super + E | Files (Nautilus) |
| Super + I | Settings |
| Super + P | Power mode (Performance / Balanced / Power Saver) |
| Super + V | Clipboard history |
| Super + X | Power menu |
| Alt + Tab | Switch window |
| Super + Shift + I | Screen layout (arandr); remembered per set of monitors and restored at login and on plug |
| 3-finger swipe | Switch desktops (up: window list) |
| Super + 1…9, 0 | Desktops 1–10 |
| Super + Shift + 1…9, 0 | Move window to desktop 1–10 |
| Super + M / Super + Z | Maximize / restore (keeps gaps and rounded corners) |
| Super + F | Toggle fullscreen |
| Super + Shift + X | Lock screen |

## Layout

| Path | What |
|---|---|
| `bspwm/` | WM config, monitor hotplug and layouts (desktops 1–0 numbered left to right across screens), mouse/touchpad settings (from GNOME's), brightness, low-battery warnings |
| `sxhkd/sxhkdrc` | Keybindings (`## Section` / `# description` feed the cheat sheet) |
| `polybar/` | Bar — **generated** by `scripts/gen-polybar.py`, edit that instead |
| `picom/` `rofi/` `dunst/` | Compositor, menus, notifications |
| `gtk-3.0/` `gtk-4.0/` | Yaru-blue; Catppuccin app styling kept in `gtk-catppuccin.css` |
| `alacritty/` `nvim/` `tmux/` `zsh/` | Terminal stack |
| `touchegg/` | Touchpad gestures (3 fingers: switch desktops / window list) |
| `applications/` | Launcher entries (Settings under bspwm, hide duplicate Slack) |
| `lockscreen/` | Lock screen: xsecurelock saver + auth module (see below) |
| `wallpapers/` | Lock-screen video (`lockscreen.mp4` links to the file in use) |

## Bar

Left: desktops and system stats (CPU usage and temperature, GPU, RAM).
Centre: clock. Right: keyboard layout, volume, brightness, battery, network,
Bluetooth, tray, power mode, do-not-disturb bell and power menu. Clicking the
stats opens btop, the network opens nmtui, the gauge opens the power mode menu.

## Lock screen

Built on xsecurelock (which keeps doing the actual locking and password
checking via PAM), with two replaceable parts in `lockscreen/`:

- `saver_video` plays `wallpapers/lockscreen.mp4` with mpv; `ui.lua` draws a
  large clock and date on top of it.
- `auth_card` (+ `auth_card.py`) replaces xsecurelock's grey password box:
  while you type, the video blurs and a GNOME-style card shows your initial,
  name and the password as dots. If it ever fails, xsecurelock's own dialog
  takes over, so you can always unlock.

To use another video, point the link at it:
`ln -sfn my-video.mp4 wallpapers/lockscreen.mp4`.

## Private settings

`zsh/zshrc` sources `~/.zshrc.local` last. Put machine-specific or work
aliases and PATHs there; it is not part of this repo.

## Notes

- Don't change the theme with GNOME Tweaks under bspwm: it replaces the
  `gtk-*/settings.ini` symlinks. Edit the files here instead.
- On machines with only software rendering (VMs), bspwmrc switches picom to
  the xrender backend automatically.
