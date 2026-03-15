#!/bin/sh

# Default to 1000 if not provided
USER_ID=${PUID:-1000}
GROUP_ID=${PGID:-1000}
USER_NAME="megauser"

echo "Setting up user with UID $USER_ID and GID $GROUP_ID..."

# 1. Handle Group
if ! getent group "$GROUP_ID" >/dev/null; then
    addgroup -g "$GROUP_ID" "$USER_NAME"
else
    EXISTING_GROUP=$(getent group "$GROUP_ID" | cut -d: -f1)
    echo "GID $GROUP_ID already exists ($EXISTING_GROUP), using it."
    USER_NAME_GROUP=$EXISTING_GROUP
fi

# 2. Handle User
if ! getent passwd "$USER_ID" >/dev/null; then
    adduser -D -u "$USER_ID" -G "${USER_NAME_GROUP:-$USER_NAME}" "$USER_NAME"
else
    USER_NAME=$(getent passwd "$USER_ID" | cut -d: -f1)
    echo "UID $USER_ID already exists ($USER_NAME), using it."
fi

# 3. Ensure the app directory and MEGA config directory are owned by the user
chown -R "$USER_ID:$GROUP_ID" /usr/src/app
mkdir -p /home/"$USER_NAME"/.megaCmd
chown -R "$USER_ID:$GROUP_ID" /home/"$USER_NAME"

# 4. Execute the CMD as the specific user
exec su-exec "$USER_ID:$GROUP_ID" "$@"
