#!/bin/sh

# Default to 1000 if not provided
USER_ID=${PUID:-1000}
GROUP_ID=${PGID:-1000}
USER_NAME="megauser"

# 1. Handle Group
if ! getent group "$GROUP_ID" >/dev/null; then
    addgroup -g "$GROUP_ID" "$USER_NAME"
    GROUP_NAME="$USER_NAME"
else
    GROUP_NAME=$(getent group "$GROUP_ID" | cut -d: -f1)
    echo "GID $GROUP_ID already exists ($GROUP_NAME), using it."
fi

# 2. Handle User
if ! getent passwd "$USER_ID" >/dev/null; then
    adduser -D -u "$USER_ID" -G "$GROUP_NAME" "$USER_NAME"
else
    USER_NAME=$(getent passwd "$USER_ID" | cut -d: -f1)
    echo "UID $USER_ID already exists ($USER_NAME), using it."
fi

# 3. Dynamic Chown
# We ensure the download dir and app dir belong to the runtime UID/GID
mkdir -p "$DOWNLOAD_DIR"
# chown -R "$USER_ID:$GROUP_ID" "$DOWNLOAD_DIR" # It might not be empty
chown -R "$USER_ID:$GROUP_ID" /usr/src/app

# Ensure MEGA config directory exists for this user
mkdir -p /home/"$USER_NAME"/.megaCmd
chown -R "$USER_ID:$GROUP_ID" /home/"$USER_NAME"

# 4. Execute the CMD as the specific user
exec su-exec "$USER_ID:$GROUP_ID" "$@"