#!/bin/bash


echo "=== Synapse Admin User Creator ==="
echo ""

CONTAINER=synapse

# Check if container is running
if ! docker compose ps synapse 2>/dev/null | grep -q "Up"; then
    echo "  ERROR: ${CONTAINER} is not running."
    echo "  Start the stack first with: docker compose up -d"
    exit 1
fi

echo "  ${CONTAINER} is running."
echo ""

# USERNAME
while [[ -z "$ADMIN_USER" ]]; do
    read -p "Username: " ADMIN_USER
    [[ -z "$ADMIN_USER" ]] && echo "Required field!"
done

# Generate password
ADMIN_PASS=$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 32)

echo ""
echo "Creating admin user '${ADMIN_USER}'..."
echo ""

docker compose exec synapse register_new_matrix_user \
    -u "$ADMIN_USER" \
    -p "$ADMIN_PASS" \
    -a \
    -c /data/homeserver.yaml \
    http://localhost:8008

if [[ $? -eq 0 ]]; then
    echo ""
    echo "=== Done ==="
    echo "  Admin user '${ADMIN_USER}' created successfully."
    echo ""
    echo "  Password: ${ADMIN_PASS}"
    echo "  (save this, it won't be shown again)"
else
    echo ""
    echo "  ERROR: User creation failed."
    exit 1
fi
