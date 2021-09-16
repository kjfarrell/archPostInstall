#!/bin/bash

phase1=(
  "fish" "openssh" "sudo" "base" "base-devel" "wget" "pacman-contrib" "python-pip" "alacritty" "neovim"
)

phase2=(
  "xorg" "xorg-xinit" "gdm" "qtile" "pacman-contrib" "nerd-fonts-ubuntu-mono" 
  "tealdeer" "man" "exa" "ripgrep" "fd" "starship" "neofetch" "google-chrome"
)

# Run as root
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi 

# Create temp file and cd into it.
tmpdir="$(command mktemp -d)"
command cd "${tmpdir}"
echo ${tmpdir}
chmod 777 "${tmpdir}"

# Permission changes to make Paru work
mkdir /.cache
chmod 777 /.cache

# Create user
read -p "Enter Username: " uservar
read -sp "Enter password: " passvar



useradd -m -G "wheel" -s /bin/fish $uservar
echo "$uservar:$passvar" | chpasswd

# Edit pacman.conf colours and threads
sed 's/#Color/Color/' </etc/pacman.conf >/etc/pacman.conf.new
sed 's/#ParallelDownloads/ParallelDownloads/' </etc/pacman.conf.new >/etc/pacman.conf

# Update System
pacman -Syu --noconfirm

# Install Phase1
pacman -S --noconfirm --needed ${phase1[@]} 
pip install psutil

# Start sshd
systemctl enable sshd
systemctl start sshd

# Install sudo, enable wheel access
sed 's/# %wheel ALL=(ALL) NOPASSWD: ALL/%wheel ALL=(ALL) NOPASSWD: ALL/' </etc/sudoers >/etc/sudoers.new
mv -f /etc/sudoers.new /etc/sudoers
rm -f /etc/sudoers.new

# Add nobody to wheel, stops passwords for makepkg
usermod -a -G wheel nobody 
# Block comment
: <<'END'

# Install Yay and dependancies
if ! builtin type -p 'yay' >/dev/null 2>&1; then
    echo 'Install yay.'
    dl_url="$(
        curl -sfLS 'https://api.github.com/repos/Jguer/yay/releases/latest' | grep 'browser_download_url' | tail -1 | cut -d '"' -f 4
    )"
    command wget "${dl_url}"
    command tar xzvf yay_*_x86_64.tar.gz
    command cd yay_*_x86_64 || return 1
    sudo -u nobody ./yay -Sy yay-bin --noconfirm
fi
END

#mkdir "${tmpdir}/paru"
#chmod 777 "{$tmpdir}/paru"
sudo -u $uservar git clone https://aur.archlinux.org/paru.git
cd paru
sudo -u $uservar makepkg -si --noconfirm

# Install Phase2
sudo -u nobody paru -S --noconfirm ${phase2[@]}

# Dotfiles
#mkdir /home/$uservar/.config
git clone https://github.com/kjfarrell/dotfiles.git
cp -r dotfiles/.config/ /home/$uservar/
chown -R $uservar /home/$uservar/.config/
chgrp -R $uservar /home/$uservar/.config/

rm -rf "${tmpdir}"

#End stuff
systemctl enable gdm
systemctl start gdm
