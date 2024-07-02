#!/bin/bash

# Log file
LOG_FILE="/var/log/user_management.log"
# Secure file for storing passwords
PASSWORD_FILE="/var/secure/user_passwords.csv"

# Function to generate random passwords
generate_password() {
    < /dev/urandom tr -dc A-Za-z0-9 | head -c 16
}

# Check if the necessary files exist
if [ ! -f "$1" ]; then
    echo "User file not found!"
    exit 1
fi

# Ensure log and password files exist
touch $LOG_FILE
mkdir -p $(dirname $PASSWORD_FILE)
touch $PASSWORD_FILE
chmod 600 $PASSWORD_FILE

# Read the user file line by line
while IFS=';' read -r username groups; do
    # Trim whitespace
    username=$(echo "$username" | xargs)
    groups=$(echo "$groups" | xargs)

    # Check if the user already exists
    if id "$username" &>/dev/null; then
        echo "User $username already exists. Skipping..." | tee -a $LOG_FILE
        continue
    fi

    # Create user with home directory
    useradd -m -s /bin/bash "$username"
    if [ $? -ne 0 ]; then
        echo "Failed to create user $username" | tee -a $LOG_FILE
        continue
    fi

    # Create a personal group with the same name as the username
    groupadd "$username"

    # Set up user groups
    IFS=',' read -r -a group_array <<< "$groups"
    for group in "${group_array[@]}"; do
        group=$(echo "$group" | xargs)
        # Check if the group exists, if not create it
        if ! getent group "$group" > /dev/null; then
            groupadd "$group"
        fi
        # Add user to group
        usermod -aG "$group" "$username"
    done

    # Generate a random password
    password=$(generate_password)

    # Set the password for the user
    echo "$username:$password" | chpasswd

    # Log the actions
    echo "Created user $username with groups $groups" | tee -a $LOG_FILE
    echo "$username:$password" >> $PASSWORD_FILE

done < "$1"

# Set appropriate permissions on the log and password files
chmod 600 $PASSWORD_FILE
chmod 644 $LOG_FILE

echo "User creation script completed successfully."
