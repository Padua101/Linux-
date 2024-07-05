#!/bin/bash

# File paths
INPUT_FILE="$1"
LOG_FILE="/var/log/user_management.log"
PASSWORD_FILE="/var/secure/user_passwords.txt"

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Function to generate a random password
generate_password() {
    tr -dc 'A-Za-z0-9!@#$%^&*' < /dev/urandom | head -c 12
}

# Check if input file is provided
if [ -z "$INPUT_FILE" ]; then
    echo "Usage: $0 <input_file>"
    exit 1
fi

# Check if input file exists
if [ ! -f "$INPUT_FILE" ]; then
    echo "Input file not found: $INPUT_FILE"
    exit 1
fi

# Ensure log and password files are accessible
touch "$LOG_FILE" "$PASSWORD_FILE" || { echo "Unable to access log or password file"; exit 1; }
chmod 600 "$PASSWORD_FILE"

# Read input file
while IFS=';' read -r username groups
do
    username=$(echo "$username" | tr -d '[:space:]')
    groups=$(echo "$groups" | tr -d '[:space:]')

    # Check if user already exists
    if id "$username" &>/dev/null; then
        log_message "User $username already exists. Skipping."
        continue
    fi

    # Create user and their personal group
    useradd -m -U "$username"
    if [ $? -ne 0 ]; then
        log_message "Failed to create user $username"
        continue
    fi

    # Add user to additional groups
    IFS=',' read -ra group_array <<< "$groups"
    for group in "${group_array[@]}"; do
        groupadd -f "$group"
        usermod -aG "$group" "$username"
    done

    # Generate and set password
    password=$(generate_password)
    echo "$username:$password" | chpasswd
    echo "$username:$password" >> "$PASSWORD_FILE"

    # Set home directory permissions
    chown -R "$username:$username" "/home/$username"
    chmod 700 "/home/$username"

    log_message "User $username created successfully with groups: $groups"
done < "$INPUT_FILE"

echo "User creation process completed. Check $LOG_FILE for details."
