#!/bin/sh

# Default to 1000 if not provided
USER_ID=${PUID:-1000}
GROUP_ID=${PGID:-1000}
USER_NAME="megauser"

# 1. Handle Group
if ! getent group "$GROUP_ID" >/dev/null; then
    # Debian uses --gid instead of -g
    addgroup --gid "$GROUP_ID" "$USER_NAME"
    GROUP_NAME="$USER_NAME"
else
    GROUP_NAME=$(getent group "$GROUP_ID" | cut -d: -f1)
    echo "GID $GROUP_ID already exists ($GROUP_NAME), using it."
fi

# 2. Handle User
if ! getent passwd "$USER_ID" >/dev/null; then
    # Debian flags:
    # --disabled-password: skips the password prompt
    # --gecos "": skips the "Full Name/Room Number" prompts
    # --uid: set specific UID
    # --ingroup: set primary group
    adduser --disabled-password --gecos "" --uid "$USER_ID" --ingroup "$GROUP_NAME" "$USER_NAME"
else
    USER_NAME=$(getent passwd "$USER_ID" | cut -d: -f1)
    echo "UID $USER_ID already exists ($USER_NAME), using it."
fi

# 3. Dynamic Chown
mkdir -p "$DOWNLOAD_DIR"
# Ensure the app dir belongs to the runtime UID/GID
chown -R "$USER_ID:$GROUP_ID" /usr/src/app

# Ensure MEGA config directory exists for this user
# Note: Debian usually creates /home/$USER_NAME automatically, but we make sure
mkdir -p /home/"$USER_NAME"/.megaCmd
chown -R "$USER_ID:$GROUP_ID" /home/"$USER_NAME"

# 4. Execute the CMD as the specific user
exec gosu "$USER_ID:$GROUP_ID" "$@"