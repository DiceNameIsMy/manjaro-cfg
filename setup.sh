#!/bin/bash

Red='\033[0;31m'
Green='\033[0;32m'
NC='\033[0m' # No Color

set -e

handle_error() {
        echo -e "${Red}An error occured on line $1${NC}" >&2
        exit 1
}

trap 'handle_error $LINENO' ERR

setup_ssh() {
	local email=""
	read -p "Your email: " email
	ssh-keygen -t ed25519 -C "$email"

	echo -e "${Green}An ssh key has been generated.${NC}"
}

# Packages to install
pacman_pkgs=(git)
classic_snap_pkgs=(obsidian code clion)
snap_pkgs=(transmission)
aur_pkgs=(libfido2 google-chrome)

if [[ $USER == "root" ]]; then
	echo -e "${Red}Do not run this script with sudo, as it might misconfigure user specific stuff like ssh keys!${NC}"
	exit 1
fi

# Update the system
sudo pacman -Syu

# Enable snapd
sudo pamac install snapd libpamac-snap-plugin
sudo systemctl enable --now snapd.socket
sudo ln -s -f /var/lib/snapd/snap /snap
sudo systemctl enable --now snapd.apparmor

# Ask for enabling the AUR packages
echo -e "${Green}Please enable using AUR packages by opening Add/Remove Software." \
	"Navigate to the Preferences page -> Third Party, and enable AUR support." \
	"Hit Enter when done.${NC}"
read line > /dev/null

# Install packages
sudo pacman -Syu --needed ${pacman_pkgs}

sudo pamac install ${aur_pkgs[@]}

for pkg in ${classic_snap_pkgs[@]}; do
	sudo snap install $pkg --classic
done

for pkg in ${snap_pkgs[@]}; do
    sudo snap install $pkg
done

echo -e "${Green}Packages has been successfully installed.${NC}"

configure_ssh=n
read -p "Would you like to configure an SSH key? [y/n]:" configure_ssh
if [[ "$configure_ssh" == "y" ]]; then
	setup_ssh
fi

# GNOME configuration
dconf write /org/gnome/desktop/interface/color-scheme "'prefer-dark'"
dconf write /org/gnome/desktop/interface/enable-hot-corners "false"
dconf write /org/gnome/shell/last-selected-power-profile "'performance'"
dconf write /org/gnome/settings-daemon/plugins/power/power-saver-profile-on-low-battery "false"
dconf write /org/gnome/settings-daemon/plugins/power/power-button-action "'interactive'"
dconf write /org/gnome/desktop/peripherals/touchpad/tap-to-click "true"

# Shortcut: Ctrl+Alt+T => terminal
dconf write /org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/binding "'<Control><Alt>t'"
dconf write /org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/command "'gnome-terminal'"
dconf write /org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/name "'terminal'"
dconf write /org/gnome/settings-daemon/plugins/media-keys/custom-keybindings "['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/']"

# Background image
shared_img_folder="/home/${USER}/.local/share/background"
shared_img_name="wallpaper_space_velvet.jpg"
shared_img_path="${shared_img_folder}/${shared_img_name}"

mkdir -p "$shared_img_folder"

script_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
cp ${script_dir}/background/wallpaper_space_velvet.jpg ${shared_img_path}

dconf write /org/gnome/desktop/background/picture-uri "'file:///${shared_img_path}'"
dconf write /org/gnome/desktop/background/picture-uri-dark "'file:///${shared_img_path}'"
dconf write /org/gnome/desktop/screensaver/picture-uri "'file:///${shared_img_path}'"

#

echo -e "${Green}Setup is completed. Don't forget to add your SSH keys where needed!${NC}"
