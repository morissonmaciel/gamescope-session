#!/usr/bin/env bash

source setup/common.sh

install() {
  local package=$1
  sudo zypper -n in $package
}

# Function to install packages from a file
install_packages_from_file() {
  # Accepts file path as argument
  local file_path=$1
  local packages=()

  if [ ! -f "$file_path" ]; then
    echo "No packages to install"
    return 1
  fi

  # Read file path contents line by line
  while IFS= read -r line; do
      # Split each line by whitespace
      read -ra parts <<< "$line"
      # Store everything in an array
      packages+=("${parts[@]}")
  done < "$file_path"

  # Concatenate entire array separating each item by whitespace
  local concatenated_packages="${packages[*]}"

  # Echo all packages to be installed
  echo "Packages to be installed: $concatenated_packages"

  # Prepare command string concatenating "zypper -n in $concatenated_packages"
  local command="sudo zypper -n in $concatenated_packages"

  # Execute command
  echo "Executing command: $command"
  eval "$command"
}

# Function to execute additional scripts
execute_script() {
  # Accepts the script name as argument
  local script_file=$1

  if [ ! -f "$script_file" ]; then
    echo "No script to execute"
    return 1
  fi

  echo "Executing $script_file..."

  # Prepare command
  local command="bash $script_file"
  eval "$command"
}

# Function to copy files and set permissions based on type
copy_installation_files() {
    local file_path="$1"

    if [ ! -f "$file_path" ]; then
      echo "No batch files to be copied"
      return 1
    fi

    while IFS=';' read -r source_file dest_file executable; do
        # Decode executable
        case "$executable" in
            executable) executable=true ;;
            normal) executable=false ;;
            *) executable=false ;;
        esac
        # Replace $HOME in dest_file with the actual home folder path
        dest_file="${dest_file/\$HOME/$HOME}"
        # Copy source file to destination file, replacing it if it already exists
        copy_local "$source_file" "$dest_file" "$executable"
    done < "$file_path"
}

# Function to convert options key into script file
convert_key_to_script() {
    # Convert spaces to underscores
    local input=$(echo "$1" | sed 's/ /_/g')
    # Convert to lowercase
    input="${input,,}"
    echo "$input"
}

# Function to parse setup options file
parse_options_file() {
    # Accepts file path as argument
    local file_path=$1
    local options=""
    while IFS= read -r line; do
      options+="FALSE $(echo $line | sed 's/;/ /g') "
    done < "$file_path"
    echo "${options[@]}"
}

# Function to display Zenity checklist
show_checklist() {
    # Accepts file path as argument
    local options_file="$1"
    local dialog_options=$(parse_options_file "$options_file")

    # Define Zenity command as a string
    local zenity_command="zenity --list --checklist --title='Setup Options' --text='Select options to install:' --column='Select' --column='Option' --column='Description' $dialog_options --separator=' '"

    # Execute Zenity command and capture output
    local choices=$(eval "$zenity_command")

    # Process choices
    for choice in $choices; do
        # Extract key from the choice
        key=$(echo "$choice" | cut -d '|' -f 1)

        config_id=$(convert_key_to_script "$key")
        pkg_file="setup/$config_id/$config_id.pkg"
        batch_file="setup/$config_id/$config_id.batch"
        script_file="setup/$config_id/$config_id.install"

        echo "Starting $key setup..."

        copy_installation_files $batch_file
        install_packages_from_file $pkg_file
        execute_script $script_file
    done
}

# Main function
main() {
    show_admin_password_alert

    # Check zenity availability
    if ! command -v zenity > /dev/null; then
      	print "zenity not installed. Script will proceed with installation."
        install "zenity"
    fi

    # Fetch installation options
    local setup_file="setup/setup-options"
    if [[ -f $setup_file ]]; then
      show_checklist "$setup_file"
    else
      echo "Setup options file not found!"
      exit 1
    fi
}

# Execute main function
main
