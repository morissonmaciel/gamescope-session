#!/usr/bin bash

show_admin_password_alert() {
    zenity --info --no-wrap \
        --text="Installation process may require your administrative password. Make sure to enter it when prompted in the terminal."
}

ask_reboot() {
    if zenity --question --title="Reboot" --no-wrap \
        --text="To make the configuration take effect, you need to reboot your machine. Do you want to proceed now?"; then
        sudo reboot
    fi
}
