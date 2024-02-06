#!/usr/bin/env bash

create_backup() {
  FILE="$1"
  BACKUP="${2:-true}"  # Default value is true if not provided
  BACKUP_FILE="${FILE}.bak"

  if [ ! -f "$BACKUP_FILE" ] && [ "$BACKUP" = true ] && [ -f "$FILE" ]; then
      echo "Creating a backup file $BACKUP_FILE for the original $FILE. You can further restore in case of error."
      sudo cp "$FILE" "$BACKUP_FILE"
  fi
}

restore_backup() {
  FILE="$1"
  BACKUP_FILE="${FILE}.bak"

  if [ -f "$BACKUP_FILE" ]; then
      echo "Restoring backup file $BACKUP_FILE for the original $FILE."
      sudo cp "$BACKUP_FILE" "$FILE"
  fi
}

copy_local() {
  SRC_FILE="$1"
  DEST_FILE="$2"
  EXECUTABLE="${3:-false}"
  USE_SUDO="${4:-true}"

  if [ -f "$DEST_FILE" ]; then
    restore_backup "$DEST_FILE"
    create_backup "$DEST_FILE"
  fi

  if [ "$USE_SUDO" = "true" ]; then
    sudo mkdir -p "$(sudo dirname "$DEST_FILE")"
    cat "$SRC_FILE" | sudo tee "$DEST_FILE" > /dev/null
  else
    mkdir -p "$(dirname "$DEST_FILE")"
    cat "$SRC_FILE" > "$DEST_FILE"
  fi

  if [ "$EXECUTABLE" = "true" ]; then
    if [ "$USE_SUDO" = "true" ]; then
      sudo chmod +x "$DEST_FILE"
    else
      chmod +x "$DEST_FILE"
    fi
  fi

  echo "File $DEST_FILE copied."
}


ADMIN_ALERT_FLAG=0

show_admin_password_alert() {
  if [ $ADMIN_ALERT_FLAG -ne 0 ]; then
    return 0
  fi

  ADMIN_ALERT_FLAG=1
  zenity --info --no-wrap \
    --text="Installation process may require your administrative password. Make sure to enter it when prompted in the terminal."
}

ask_reboot() {
  if zenity --question --title="Reboot" --no-wrap \
    --text="To make the configuration take effect, you need to reboot your machine. Do you want to proceed now?"; then
    sudo reboot
  fi
}
