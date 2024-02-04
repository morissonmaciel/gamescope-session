#!/bin/bash

# set -e

print() {
  MESSAGE="$1"
  echo >&2 "$MESSAGE"
}

replace_or_append() {
  KEY="$1"
  NEW_VALUE="$2"
  FILE="$3"

  if [ -f "$FILE" ]; then
    sudo grep -Fq "$TEXT=" "$FILE" && \
        sudo sed -i "s/\<$KEY\>=.*/$KEY=$NEW_VALUE/g" "$FILE" || \
          echo "$KEY=$NEW_VALUE" | sudo tee -a "$FILE"
  fi
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
        print "Restoring backup file $BACKUP_FILE for the original $FILE."
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

enable_steam_lan_transfer() {
  SHOW_ALERT="${1:-true}"

  if [ "$SHOW_ALERT" = "true" ]; then
    show_admin_password_alert
  fi

  NORMAL_LIST=(
    "rootfs/etc/firewalld/services/steam-lan-streaming.xml"
    "rootfs/etc/firewalld/services/steam-lan-transfer.xml"
  )

  for file_path in "${NORMAL_LIST[@]}"; do
    copy_local "$file_path" "${file_path/rootfs/}" false

    if [ $? -ne 0 ]; then
      show_something_wrong
      exit 1
    fi
  done

  # Reload firewalld to make sure it recognizes the new service
  sudo firewall-cmd --reload

  # Add the custom service to the public zone
  sudo firewall-cmd --zone=public --add-service=steam-lan-streaming --permanent
  sudo firewall-cmd --zone=public --add-service=steam-lan-transfer --permanent

  # Reload firewalld again to apply the changes
  sudo firewall-cmd --reload
}

configure_gamescope() {
  configure_steam
  install "gamescope" "mangoapp" "vkbasalt"

  if [ $? -ne 0 ]; then
    show_something_wrong
    exit 1
  fi

  # Configuring gamescope-session
  EXECUTABLE_LIST=(
    "rootfs/lib/systemd/user/gamescope-session-plus@.service"
    "rootfs/usr/bin/export-gpu"
    "rootfs/usr/bin/gamescope-session-plus"
    "rootfs/usr/bin/steamos-restart-sddm"
    "rootfs/usr/bin/steamos-select-branch"
    "rootfs/usr/share/gamescope-session-plus/gamescope-session-plus"
    "rootfs/usr/share/gamescope-session-plus/sessions.d/steam"
    "rootfs/usr/share/gamescope-session-plus/device-quirks"
  )

  NORMAL_LIST=(
    "rootfs/usr/share/wayland-sessions/gamescope-session.desktop"
  )

  for file_path in "${EXECUTABLE_LIST[@]}"; do
    copy_local "$file_path" "${file_path/rootfs/}" true

    if [ $? -ne 0 ]; then
      show_something_wrong
      exit 1
    fi
  done

  for file_path in "${NORMAL_LIST[@]}"; do
    copy_local "$file_path" "${file_path/rootfs/}" false

    if [ $? -ne 0 ]; then
      show_something_wrong
      exit 1
    fi
  done

  # Copying files from special folders
  mkdir -p "$( dirname "$HOME/.config/environment.d/10-gamescope-session-custom.conf" )"
  cp "rootfs/home/config/environment.d/10-gamescope-session-custom.conf" \
    "$HOME/.config/environment.d/10-gamescope-session-custom.conf"

  # Configure polkit rules and actions once it is needed by SteamOS
  configure_polkit_helpers false

  # Rebuilding application database
  sudo update-desktop-database

  # Ask for reboot to see new sessions
  ask_reboot
}

configure_polkit_helpers() {
  SHOW_ALERT="${1:-true}"

  if [ "$SHOW_ALERT" = "true" ]; then
    show_admin_password_alert
  fi

  # Adding current user to wheel group
  sudo usermod -a -G wheel $USER

  EXECUTABLE_LIST=(
    "rootfs/usr/bin/steamos-polkit-helpers/jupiter-dock-updater"
    "rootfs/usr/bin/steamos-polkit-helpers/steamos-poweroff-now"
    "rootfs/usr/bin/steamos-polkit-helpers/steamos-reboot-now"
    "rootfs/usr/bin/steamos-polkit-helpers/steamos-restart-sddm"
    "rootfs/usr/bin/steamos-polkit-helpers/steamos-select-branch"
    "rootfs/usr/bin/steamos-polkit-helpers/steamos-set-hostname"
    "rootfs/usr/bin/steamos-polkit-helpers/steamos-set-timezone"
    "rootfs/usr/bin/steamos-polkit-helpers/steamos-update"
  )

  for file_path in "${EXECUTABLE_LIST[@]}"; do
    copy_local "$file_path" "${file_path/rootfs/}" true

    if [ $? -ne 0 ]; then
      show_something_wrong
      exit 1
    fi
  done

  NORMAL_LIST=(
    "rootfs/etc/polkit-1/rules.d/40-system-tweaks.rules"
    "rootfs/usr/share/polkit-1/actions/org.valve.steamos.policy"
    "rootfs/usr/share/polkit-1/rules.d/org.valve.steamos.rules"
  )

  for file_path in "${NORMAL_LIST[@]}"; do
    copy_local "$file_path" "${file_path/rootfs/}" false

    if [ $? -ne 0 ]; then
      show_something_wrong
      exit 1
    fi
  done

  for file_path in "${DELETED[@]}"; do
    if [ -f file_path ]; then
      sudo rm -rf "${file_path/rootfs/}"
    fi
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

  if [ $? -eq 0 ]; then
    enable_steam_lan_transfer false
  fi
}

configure_grub() {
  show_admin_password_alert

  GRUB_FILE="/etc/default/grub"
  QUIET_CMD="quiet splash loglevel=2 acpi=nodefer"
  OPTIMIZED_CMD=""

  # Restore the previous backup to avoid GRUB misbehavior
  restore_backup "$GRUB_FILE"
  create_backup "$GRUB_FILE"

  sudo sed -i "s/GRUB_TIMEOUT=[0-9]*/GRUB_TIMEOUT=0/g" "$GRUB_FILE"
  sudo sed -i "s/GRUB_HIDDEN_TIMEOUT=[0-9]*/GRUB_HIDDEN_TIMEOUT=0/g" "$GRUB_FILE"
  sudo sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT=\"$QUIET_CMD\"/g" "$GRUB_FILE"
  sudo sed -i "s/GRUB_CMDLINE_LINUX=.*/GRUB_CMDLINE_LINUX=\"$OPTIMIZED_CMD\"/g" "$GRUB_FILE"
  sudo sed -i "s/GRUB_TIMEOUT_STYLE=.*/GRUB_TIMEOUT_STYLE=hidden/g" "$GRUB_FILE" || echo "GRUB_TIMEOUT_STYLE=hidden" | sudo tee -a "$GRUB_FILE"
  sudo sed -i "s/GRUB_DISABLE_SUBMENU=.*/GRUB_DISABLE_SUBMENU=true/g" "$GRUB_FILE" || echo "GRUB_DISABLE_SUBMENU=true" | sudo tee -a "$GRUB_FILE"
  sudo sed -i "s/GRUB_HIDDEN_TIMEOUT_QUIET=.*/GRUB_HIDDEN_TIMEOUT_QUIET=true/g" "$GRUB_FILE" || echo "GRUB_HIDDEN_TIMEOUT_QUIET=true" | sudo tee -a "$GRUB_FILE"

  # Update grub manually
  sudo grub2-mkconfig -o /boot/grub2/grub.cfg

  if [ $? -ne 0 ]; then
    show_something_wrong
    exit 1
  fi

  if [ $? -eq 0 ]; then
    ask_reboot
  fi
}

configure_autostart() {
  SHOW_ALERT="${1:-true}"

  if [ "$SHOW_ALERT" = "true" ]; then
    show_admin_password_alert
  fi

  # Install SDDM as display manager
  install "sddm"
  sudo update-alternatives --set default-displaymanager /usr/lib/X11/displaymanagers/sddm

  # Copy Autologin Service files
  EXECUTABLE_LIST=(
    "rootfs/lib/systemd/system/steamos-autologin.service"
    "rootfs/usr/libexec/steamos-autologin"
    "rootfs/usr/bin/gnome-session-oneshot"
    "rootfs/usr/bin/return-to-gamemode"
    "rootfs/usr/bin/steamos-session-select"
  )

  for file_path in "${EXECUTABLE_LIST[@]}"; do
    copy_local "$file_path" "${file_path/rootfs/}" true

    if [ $? -ne 0 ]; then
      show_something_wrong
      exit 1
    fi
  done

  NORMAL_LIST=(
    "rootfs/etc/default/desktop-wayland"
    "rootfs/etc/sddm.conf.d/steamos.conf"
    "rootfs/usr/share/wayland-sessions/gnome-wayland-oneshot.desktop"
    "rootfs/usr/share/applications/return-to-gamemode.desktop"
  )

  for file_path in "${NORMAL_LIST[@]}"; do
    copy_local "$file_path" "${file_path/rootfs/}" false

    if [ $? -ne 0 ]; then
      show_something_wrong
      exit 1
    fi
  done

  # Enabling necessary autologin service
  sudo systemctl enable /lib/systemd/system/steamos-autologin.service

  # create symbolic link for Steam auto start
  cp "/usr/share/applications/steam.desktop" "$HOME/.config/autostart/Steam.desktop"
  chmod +x "$HOME/.config/autostart/Steam.desktop"

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
          FALSE grub "Hide GRUB (for quiet and optmized boot)" \
          FALSE autostart "Configure autostart for Gamescope Session / Steam on Desktop" \
          FALSE polkit "Configure SteamOS polkit helpers" \
          FALSE steam_firewall "Steam LAN transfer over firewall")

if [ -n "$RESULT" ]; then
  case $RESULT in
    "gamescope") configure_gamescope;;
    "steam") configure_steam;;
    "grub") configure_grub;;
    "autostart") configure_autostart;;
    "polkit") configure_polkit_helpers;;
    "steam_firewall") enable_steam_lan_transfer;;
  esac

  if [ $? -eq 0 ]; then
    print "Installation process completed for $RESULT"
  fi
fi
