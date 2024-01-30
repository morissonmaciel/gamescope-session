#!/bin/bash

# set -e

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

show_admin_password_alert() {
  zenity --info --no-wrap \
    --text="Installation process may require your administrative password. Make sure to enter it when prompted in the terminal."
}

show_something_wrong() {
  zenity --warning --no-wrap \
    --text="Something went wrong with installation process. Please check terminal log and try again."
}

ask_reboot() {
  if zenity --question --title="Reboot" --no-wrap \
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

restore_backup() {
    FILE="$1"
    BACKUP_FILE="${FILE}.bak"

    if [ -f "$BACKUP_FILE" ]; then
        print "Restorinng backup file $BACKUP_FILE for the original $FILE."
        sudo cp "$BACKUP_FILE" "$FILE"
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

copy_local() {
  SRC_FILE="$1"
  DEST_FILE="$2"
  EXECUTABLE="${3:-false}"

  if [ -f "$DEST_FILE" ]; then
    restore_backup "$DEST_FILE"
    create_backup "$DEST_FILE"
  fi

  sudo mkdir -p "$(dirname "$DEST_FILE")"
  cat "$SRC_FILE" | sudo tee "$DEST_FILE"

  if [ "$EXECUTABLE" = "true" ]; then
    sudo chmod +x "$DEST_FILE"
  fi

  print "File $DEST_FILE copied."
}

# MAIN FUNCS -------------------------------------------------------------------

configure_gamescope() {
  configure_steam
  install "gamescope" "mangoapp" "vkbasalt"

  if [ $? -ne 0 ]; then
    show_something_wrong
    exit 1
  fi

  # Configuring gamescope-session
  EXECUTABLE_LIST=(
    "rootfs/usr/share/gamescope-custom/gamescope-script"
    "rootfs/usr/bin/export-gpu"
    "rootfs/usr/bin/gamescope-custom-session"
    "rootfs/usr/bin/return-to-gamemode"
  )

  NORMAL_LIST=(
    "rootfs/usr/share/wayland-sessions/gamescope-session.desktop"
    "rootfs/usr/share/applications/return-to-gamemode.desktop"
  )

  for file_path in "${EXECUTABLE_LIST[@]}"; do
    copy_local "$file_path" "${file_path/rootfs\//}" true
  done

  for file_path in "${NORMAL_LIST[@]}"; do
    copy_local "$file_path" "${file_path/rootfs\//}" false
  done
}

configure_steam() {
  show_admin_password_alert
  install "steam" "steam-devices"

  if [ $? -ne 0 ]; then
    show_something_wrong
    exit 1
  fi

  if [ $? -eq 0 ]; then
    # Wait for Steam completion
    steam --silent 2>&1 &
    zenity --info --no-wrap \
      --text="Please wait for the completion of the Steam initial setup, and then close the login window. There is no need to log in."
  fi

  if [ $? -eq 0 ]; then
    # Fix Steam download speed
    mkdir -p $HOME/.local/share/Steam
    rm -f $HOME/.local/share/Steam/steam_dev.cfg
    bash -c 'printf "@nClientDownloadEnableHTTP2PlatformLinux 0\n@fDownloadRateImprovementToAddAnotherConnection 1.0\n" > $HOME/.local/share/Steam/steam_dev.cfg'
  fi
}

configure_grub() {
  show_admin_password_alert

  GRUB_FILE="/etc/default/grub"
  QUIET_CMD="quiet splash loglevel=2 acpi=nodefer"
  OPTIMIZED_CMD="amd_iommu=off amdgpu.gttsize=8128 spi_amd.speed_dev=1 rd.luks.options=discard rhgb"

  # Restore the previous backup to avoid GRUB misbehavior
  restore_backup "$GRUB_FILE"
  create_backup "$GRUB_FILE"

  sudo sed -i "s/GRUB_TIMEOUT=[0-9]*/GRUB_TIMEOUT=0/g" "$GRUB_FILE"
  sudo sed -i "s/GRUB_HIDDEN_TIMEOUT=[0-9]*/GRUB_HIDDEN_TIMEOUT=0/g" "$GRUB_FILE"
  sudo sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT=\"$QUIET_CMD\"/" "$GRUB_FILE"
  sudo sed -i "s/GRUB_CMDLINE_LINUX=.*/GRUB_CMDLINE_LINUX=\"$OPTIMIZED_CMD\"/" "$GRUB_FILE"
  sudo sed -i "s/GRUB_TIMEOUT_STYLE=.*/GRUB_TIMEOUT_STYLE=hidden/" "$GRUB_FILE" || echo "GRUB_TIMEOUT_STYLE=hidden" | sudo tee -a "$GRUB_FILE"
  sudo sed -i "s/GRUB_DISABLE_SUBMENU=.*/GRUB_DISABLE_SUBMENU=true/" "$GRUB_FILE" || echo "GRUB_DISABLE_SUBMENU=true" | sudo tee -a "$GRUB_FILE"
  sudo sed -i "s/GRUB_HIDDEN_TIMEOUT_QUIET=.*/GRUB_HIDDEN_TIMEOUT_QUIET=true/" "$GRUB_FILE" || echo "GRUB_HIDDEN_TIMEOUT_QUIET=true" | sudo tee -a "$GRUB_FILE"

  if [ -d /sys/firmware/efi ]; then
    sudo grub2-mkconfig -o /etc/grub2-efi.cfg
  else
    sudo grub2-mkconfig -o /etc/grub2.cfg
  fi

  if [ $? -ne 0 ]; then
    show_something_wrong
    exit 1
  fi

  if [ $? -eq 0 ]; then
    ask_reboot
  fi
}

# MAIN SECTION -----------------------------------------------------------------

# Check zenity availability
if ! command -v zenity > /dev/null; then
  	print "zenity not installed. Script will proceed with installation."
    install "zenity"
fi

RESULT=$(zenity --list --radiolist \
          --title='Choose an option form list below' \
          --column="Install" --column="Id" --column="Description" \
          TRUE gamescope "Install and configure Gamescope Session (this will install Steam either)" \
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
