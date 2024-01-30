#!/bin/bash

# set -e

copy_local() {
  SRC_FILE="$1"
  DEST_FILE="$2"
  EXECUTABLE="${3:-false}"

  if [ -f "$DEST_FILE" ]; then
    create_backup "$DEST_FILE"
  fi

  sudo mkdir -p "$(dirname "$DEST_FILE")"
  cat "$SRC_FILE" | sudo tee "$DEST_FILE"

  if [ "$EXECUTABLE" = "true" ]; then
    sudo chmod +x "$DEST_FILE"
  fi
}

configure_xdm() {
  XDM_CONF_FILE="/var/lib/AccountsService/users/gamer"

  {
    echo "[User]"
    echo "Session=gamescope-session"
    echo "Icon=/home/gamer/.face"
    echo "SystemAccount=false"
  } | sudo tee "$XDM_CONF_FILE"
}

# # Clean-up legacy version
# sudo rm -rf "/usr/bin/gnome-session-select"
# sudo rm -rf "/usr/bin/steamos-session-select"
# sudo rm -rf "/usr/share/wayland-sessions/gnome-wayland-oneshot.desktop"
# sudo rm -rf "/usr/share/wayland-sessions/gnome-oneshot.desktop"
# sudo rm -rf "/usr/share/wayland-sessions/gamescope-custom.desktop"
# sudo rm -rf "$HOME/.local/share/applications/Return to Gamemode.desktop"
#
# # Copying local files
# copy_local "rootfs/usr/bin/export-gpu" "/usr/bin/export-gpu" true
# copy_local "rootfs/lib/systemd/user/gamescope-session@.service" "/lib/systemd/user/gamescope-session@.service" true
# copy_local "rootfs/usr/bin/gamescope-custom-session" "/usr/bin/gamescope-custom-session" true
# copy_local "rootfs/usr/bin/return-to-gamemode" "/usr/bin/return-to-gamemode" true
# copy_local "rootfs/usr/share/wayland-sessions/gamescope-session.desktop" "/usr/share/wayland-sessions/gamescope-session.desktop"
# copy_local "rootfs/usr/share/applications/return-to-gamemode.desktop" "/usr/share/applications/return-to-gamemode.desktop"
# copy_local "rootfs/usr/share/gamescope-custom/gamescope-script" "/usr/share/gamescope-custom/gamescope-script" true
#
# copy_local "rootfs/home/local/share/steamos/cursors/steamos-cursor-config" "$HOME/.local/share/steamos/cursors/steamos-cursor-config"
# copy_local "rootfs/home/local/share/steamos/cursors/steamos-cursor.png" "$HOME/.local/share/steamos/cursors/steamos-cursor.png"
#
# # Rebuilding application database
# sudo update-desktop-database
#
# # Configuring X Session
# sh /usr/bin/export-gpu
# configure_xdm
#
# sudo reboot -f

print() {
  MESSAGE="$1"
  echo >&2 "$MESSAGE"
}

ask_reboot() {
  if zenity --question --title="Reboot" \
    --text="To make the configuration take effect, you need to reboot your machine. Do you want to proceed now?"; then
    sudo reboot
  fi
}

create_backup() {
    FILE="$1"
    BACKUP="${2:-true}"  # Default value is true if not provided
    BACKUP_FILE="${FILE}.bak"

    if [ ! -f "$BACKUP_FILE" ] && [ "$BACKUP" = true ] && [ -f "$FILE" ]; then
        print "Creating a backup file $BACKUP_FILE for the original $FILE. You can further restore in case of error."
        sudo cp "$FILE" "$BACKUP_FILE"
    fi
}

install() {
  # Accept any number of package names as arguments
  PACKAGES=("$@")

  for package in "${PACKAGES[@]}"; do
    sudo zypper -n in "$package"

    # Check the exit status of the last command
    if [ $? -ne 0 ]; then
      echo "Error: Failed to install $package"
      # Handle the error (exit or other actions as needed)
      exit 1
    fi
  done
}

configure_gamescope() {
  configure_steam
  install "gamescope" "mangoapp" "vkbasalt"

  if [ $? -ne 0 ]; then
    zenity --warning --text="Something went wrong with installation process. Please check terminal log and try again."
  fi
}

configure_steam() {
  zenity --info --text="Installation process may require your administrative password. Make sure to enter it when prompted in the terminal."
  install "steam" "steam-devices"

  if [ $? -ne 0 ]; then
    zenity --warning --text="Something went wrong with installation process. Please check terminal log and try again."
    exit 1
  fi

  if [ $? -eq 0 ]; then
    # Wait for Steam completion
    steam --silent 2>&1 &
    zenity --info --text="Please wait for the completion of the Steam initial setup, and then close the login window. There is no need to log in."
  fi

  if [ $? -eq 0 ]; then
    # Fix Steam download speed
    mkdir -p $HOME/.local/share/Steam
    rm -f $HOME/.local/share/Steam/steam_dev.cfg
    bash -c 'printf "@nClientDownloadEnableHTTP2PlatformLinux 0\n@fDownloadRateImprovementToAddAnotherConnection 1.0\n" > $HOME/.local/share/Steam/steam_dev.cfg'
  fi
}

configure_grub() {
  zenity --info --text="Configuration process may require your administrative password. Make sure to enter it when prompted in the terminal."

  GRUB_FILE="/etc/default/grub"
  OPTIMIZED_CMD="amd_iommu=off amdgpu.gttsize=8128 spi_amd.speed_dev=1 rd.luks.options=discard rhgb mitigations=auto quiet"

  create_backup "$GRUB_FILE"

  sudo sed -i 's/GRUB_TIMEOUT=8/GRUB_TIMEOUT=0/g' "$GRUB_FILE"
  sudo sed -i 's/GRUB_TIMEOUT=[0-9]*/GRUB_TIMEOUT=0/g' "$GRUB_FILE"
  sudo sed -i "s/GRUB_CMDLINE_LINUX=.*/GRUB_CMDLINE_LINUX=\"\"/" "$GRUB_FILE"
  sudo sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT=\"$OPTIMIZED_CMD\"/" "$GRUB_FILE"

  echo 'GRUB_TIMEOUT_STYLE=hidden' | sudo tee -a "$GRUB_FILE" 1>/dev/null
  echo 'GRUB_HIDDEN_TIMEOUT=1' | sudo tee -a "$GRUB_FILE" 1>/dev/null

  if [ -d /sys/firmware/efi ]; then
    sudo grub2-mkconfig -o /etc/grub2-efi.cfg
  else
    sudo grub2-mkconfig -o /etc/grub2.cfg
  fi

  if [ $? -ne 0 ]; then
    zenity --warning --text="Something went wrong with configuration process. Please check terminal log and try again."
    exit 1
  fi

  if [ $? -eq 0 ]; then
    ask_reboot
  fi
}

# Check zenity availability
if ! command -v zenity > /dev/null; then
  	print "zenity not installed. Script will proceed with installation."
    install "zenity"
fi

RESULT=$(zenity --list --radiolist \
          --title='Choose an option form list below' \
          --column="Install" --column="Id" --column="Description" \
          TRUE gamescope "Install and configure Gamescope (this will install Steam either)" \
          FALSE steam "Install and configure standalone Steam" \
          FALSE grub "Hide GRUB (for quiet and optmized boot)")

if [ -n "$RESULT" ]; then
  case $RESULT in
    "gamescope") configure_gamescope;;
    "steam") configure_steam;;
    "grub") configure_grub;;
  esac

  if [ $? -eq 0 ]; then
    print "Installation process completed for $RESULT"
  fi
fi
