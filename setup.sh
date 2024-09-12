#!/bin/bash

# Packages to install
readonly PACMAN_PKGS=(wine winetricks wine-mono wine_gecko)
readonly CLASSIC_SNAP_PKGS=(obsidian code clion bash-language-server)
readonly SNAP_PKGS=(transmission)
readonly AUR_PKGS=(libfido2 brave-browser)

readonly Red='\033[0;31m'
readonly Green='\033[0;32m'
readonly NoColor='\033[0m'
readonly SCRIPT_DIR="$(dirname "$(realpath "$0")")"

set -e

log_error() {
    echo -e "${Red}$1${NoColor}" >&2
}

log_info() {
    echo -e "${Green}$1${NoColor}"
}

handle_error() {
	log_error "An error occured on line $1"
	exit 1
}

trap 'handle_error $LINENO' ERR

setup_packages() {
	log_info "Updating system..."
	sudo pacman -Syu

	log_info "Enabling snapd..."
	sudo pamac install base-devel snapd libpamac-snap-plugin
	sudo systemctl enable --now snapd.socket
	sudo ln -s -f /var/lib/snapd/snap /snap
	sudo systemctl enable --now snapd.apparmor

	# Ask for enabling the AUR packages
    log_info "Please enable AUR packages in Add/Remove Software."
    log_info "Navigate to Preferences -> Third Party, and enable AUR support."
	read -p "Press Enter when done..."

	# Install packages
	sudo pacman -Syu --needed ${PACMAN_PKGS[@]}

	for pkg in ${AUR_PKGS[@]}; do
		sudo pamac build "$pkg"
	done

	for pkg in ${CLASSIC_SNAP_PKGS[@]}; do
		sudo snap install "$pkg" --classic
	done

	for pkg in ${SNAP_PKGS[@]}; do
		sudo snap install "$pkg"
	done

	log_info "Packages has been successfully installed."
}

setup_git() {
	configure_git=n
    read -p "Would you like to configure git with an SSH key? [y/n]:" configure_git
    if [[ "$configure_git" != "y" ]]; then
		return
    fi

	local name=""
	local email=""
	read -p "Your name: " name
	read -p "Your email: " email

	ssh-keygen -t ed25519 -C "$email"

	log_info "An ssh key has been generated."

	# Git config
	git config --global user.name "$name"
	git config --global user.email "$email"
}


setup_gnome() {
	# WARNING: Might be outdated

	# Fonts
	sudo pamac install ttf-jetbrains-mono-nerd
	dconf write /org/gnome/desktop/interface/font-name "'JetBrainsMono Nerd Font 11'"

	# Pinned apps
	dconf write /org/gnome/shell/favorite-apps "['google-chrome.desktop', 'obsidian_obsidian.desktop', 'org.gnome.Nautilus.desktop', 'code_code.desktop']"

	# Shortcut: Ctrl+Alt+T => terminal
	dconf write /org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/binding "'<Control><Alt>t'"
	dconf write /org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/command "'gnome-terminal'"
	dconf write /org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/name "'terminal'"
	dconf write /org/gnome/settings-daemon/plugins/media-keys/custom-keybindings "['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/']"

	# Super+Up => Maximize window
	dconf write /org/gnome/desktop/wm/keybindings/maximize "['<Super>Up']"

	# Super+Tab => Switch windows (not Applications)
	dconf write /org/gnome/desktop/wm/keybindings/switch-applications "@as []"
	dconf write /org/gnome/desktop/wm/keybindings/switch-applications-backward "@as []"
	dconf write /org/gnome/desktop/wm/keybindings/switch-windows "['<Alt>Tab']"
	dconf write /org/gnome/desktop/wm/keybindings/switch-windows-backward "['<Shift><Alt>Tab']"

	# Etc...
	dconf write /org/gnome/desktop/interface/color-scheme "'prefer-dark'"
	dconf write /org/gnome/desktop/interface/enable-hot-corners "false"
	dconf write /org/gnome/shell/last-selected-power-profile "'performance'"
	dconf write /org/gnome/settings-daemon/plugins/power/power-saver-profile-on-low-battery "false"
	dconf write /org/gnome/settings-daemon/plugins/power/power-button-action "'interactive'"
	dconf write /org/gnome/desktop/peripherals/touchpad/tap-to-click "true"

	# Background image
	shared_img_folder="/home/${USER}/.local/share/background"
	shared_img_name="wallpaper_space_velvet.jpg"
	shared_img_path="${shared_img_folder}/${shared_img_name}"

	# Copy an image
	mkdir -p "$shared_img_folder"
	cp ${SCRIPT_DIR}/background/wallpaper_space_velvet.jpg ${shared_img_path}

	dconf write /org/gnome/desktop/background/picture-uri "'file:///${shared_img_path}'"
	dconf write /org/gnome/desktop/background/picture-uri-dark "'file:///${shared_img_path}'"
	dconf write /org/gnome/desktop/screensaver/picture-uri "'file:///${shared_img_path}'"

	log_info "GNOME Configuration has finished."
}

setup_kde() {
	wallpapers_folder="/home/${USER}/.local/share/background"
	wallpaper_name="wallpaper_space_velvet.jpg"
	wallpaper_path="${wallpapers_folder}/${wallpaper_name}"

	# Copy an image
	mkdir -p "$wallpapers_folder"
	cp ${SCRIPT_DIR}/background/${wallpaper_name} ${wallpaper_path}

config_script=$(cat <<EOF
	var allDesktops = desktops();
	for (i = 0; i < allDesktops.length; i++) {
		d = allDesktops[i];
		d.wallpaperPlugin = "org.kde.image";
		d.currentConfigGroup = Array("Wallpaper", "org.kde.image", "General");
		d.writeConfig("Image", "file://${wallpaper_path}");
	}
EOF
)

	qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "${config_script}"

	log_info "KDE Configuration has finished."
}

setup_gui() {

    log_info "Configuring the desktop environment"
    if [ "$XDG_CURRENT_DESKTOP" = "GNOME" ]; then
        log_info "GNOME desktop detected."
        setup_gnome

    elif [[ "$XDG_CURRENT_DESKTOP" == "KDE" ]]; then
        log_info "KDE desktop detected."
        setup_kde

    else
        log_error "Unknown desktop environment. Skipping."
    fi

}

main() {

    if [[ $USER == "root" ]]; then
        log_error "Do not run this script with sudo, as it might misconfigure user specific stuff like ssh keys!"
        exit 1
    fi

    setup_packages

	setup_git

	setup_gui
	
    log_info "Setup is completed."\
        "\nDon't forget to add your SSH keys where needed!" \
        "\nTo configure wine, visit https://linuxconfig.org/install-wine-on-manjaro"
}

main
