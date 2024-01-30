#!/bin/bash

# set -e

create_backup() {
    FILE="$1"
    BACKUP="${2:-true}"  # Default value is true if not provided

    if [ "$BACKUP" = true ] && [ -f "$FILE" ]; then
        BACKUP_FILE="${FILE}.old"
        sudo rm -rf "$BACKUP_FILE"
        #sudo cp "$FILE" "$BACKUP_FILE"
    fi
}

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
  :
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
          FALSE grub "Configure GRUB (for quiet and optmized boot)")

if [ -n "$RESULT" ]; then
  case $RESULT in
    "gamescope") configure_gamescope;;
    "steam") configure_steam;;
    "grub") configure_grub;;
  esac

  if [ $? -eq 0 ]; then
    zenity --info --text="Installation process completed for $RESULT"
  fi
fi
