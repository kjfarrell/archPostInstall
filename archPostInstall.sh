#!/bin/bash

phase1=(
  "fish" "openssh" "sudo" "base" "base-devel" "wget" "pacman-contrib" "python-pip" "alacritty" "neovim"
)

phase2=(
  "xorg" "xorg-xinit" "gdm" "qtile" "pacman-contrib" "nerd-fonts-ubuntu-mono" 
  "tealdeer" "man" "exa" "ripgrep" "fd"
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

# Create user
read -p "Enter Username: " uservar
read -sp "Enter password: " passvar

# Block comment
: <<'END'
END

useradd -m -G "wheel" -s /bin/fish $uservar
echo "$uservar:$passvar" | chpasswd

# Update System
pacman -Syu 

# Install Phase1
pacman -S --noconfirm --needed ${phase1[@]} 
pip install psutil

# Start sshd
systemctl enable sshd
systemctl start sshd

# Edit pacman.conf colours and threads
sed 's/#Color/Color/' </etc/pacman.conf >/etc/pacman.conf.new
sed 's/#ParallelDownloads/ParallelDownloads/' </etc/pacman.conf.new >/etc/pacman.conf

# Install sudo, enable wheel access
sed 's/# %wheel ALL=(ALL) NOPASSWD: ALL/%wheel ALL=(ALL) NOPASSWD: ALL/' </etc/sudoers >/etc/sudoers.new

mv -f /etc/sudoers.new /etc/sudoers
rm -f /etc/sudoers.new

# Add nobody to wheel, stops passwords for makepkg
usermod -a -G wheel nobody 

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

# Permission changes to make Yay work
mkdir /.cache
chmod 777 /.cache

# Install Phase2
sudo -u nobody yay -S --noconfirm ${phase2[@]}

#End stuff


# Set some aliases


# Dotfiles
git clone https://github.com/antoniosarosi/dotfiles.git
cp -fr dotfiles/.config/qtile /home/$uservar/.config/qtile
chown -R $uservar /home/$uservar/.config/qtile
chgrp -R $uservar /home/$uservar/.config/qtile

rm -rf "${tmpdir}"

#End stuff
systemctl enable gdm
systemctl start gdm


