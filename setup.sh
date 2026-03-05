
#!/bin/bash

PROJECT=$(basename $(pwd))

echo "=== Synapse Setup Generator ==="

# Check if matrix.conf already exists
if [[ -f "matrix.conf" ]]; then
    echo "  WARNING: matrix.conf already exists!"
    while true; do
        read -p "  Overwrite? (y/N): " OVERWRITE
        OVERWRITE="${OVERWRITE:-n}"
        case "$OVERWRITE" in
            [yYjJ]) break ;;
            [nN])   echo "Aborted."; exit 0 ;;
            *)      echo "Please enter y or n." ;;
        esac
    done
    echo ""
fi

# SERVER_NAME
while [[ -z "$SERVER_NAME" ]]; do
    read -p "Server Name (e.g. example.com): " SERVER_NAME
    [[ -z "$SERVER_NAME" ]] && echo "Required field!"
done

# ELEMENT_BASE_URL
while [[ -z "$ELEMENT_BASE_URL" ]]; do
    read -p "Element Base URL (e.g. https://synapse.example.com): " ELEMENT_BASE_URL
    [[ -z "$ELEMENT_BASE_URL" ]] && echo "Required field!"
done

# REPORT_STATS (default: n)
while true; do
    read -p "Report anonymous stats? (y/N): " STATS_INPUT
    STATS_INPUT="${STATS_INPUT:-n}"
    case "$STATS_INPUT" in
        [yYjJ]) REPORT_STATS="yes"; break ;;
        [nN])   REPORT_STATS="no";  break ;;
        *)      echo "Please enter y or n." ;;
    esac
done

# SYNAPSE_FEDERATION_BIND (default: empty = 0.0.0.0)
while true; do
    read -p "Federation Bind Address IPv4/IPv6 (default: 0.0.0.0): " SYNAPSE_FEDERATION_BIND
    if [[ -z "$SYNAPSE_FEDERATION_BIND" ]]; then
        break
    elif [[ "$SYNAPSE_FEDERATION_BIND" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        VALID=true
        IFS='.' read -ra OCTETS <<< "$SYNAPSE_FEDERATION_BIND"
        for OCT in "${OCTETS[@]}"; do
            [[ "$OCT" -gt 255 ]] && VALID=false && break
        done
        $VALID && break || echo "Invalid IPv4 address."
    elif [[ "$SYNAPSE_FEDERATION_BIND" =~ ^([0-9a-fA-F]{0,4}:){2,7}[0-9a-fA-F]{0,4}$ ]]; then
        break
    else
        echo "Please enter a valid IPv4 or IPv6 address, or leave empty."
    fi
done

# SYNAPSE_FEDERATION_PORT (default: 8008)
while true; do
    read -p "Federation Port (default: 8008): " SYNAPSE_FEDERATION_PORT
    if [[ -z "$SYNAPSE_FEDERATION_PORT" ]]; then
        SYNAPSE_FEDERATION_PORT=8008
        break
    elif [[ "$SYNAPSE_FEDERATION_PORT" =~ ^[0-9]+$ ]] && [[ "$SYNAPSE_FEDERATION_PORT" -ge 1 && "$SYNAPSE_FEDERATION_PORT" -le 65535 ]]; then
        break
    else
        echo "Please enter a valid port (1-65535)."
    fi
done

# ELEMENT_BIND (default: empty = 0.0.0.0)
while true; do
    read -p "Element Web Bind Address IPv4/IPv6 (default: 0.0.0.0): " ELEMENT_BIND
    if [[ -z "$ELEMENT_BIND" ]]; then
        break
    elif [[ "$ELEMENT_BIND" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        VALID=true
        IFS='.' read -ra OCTETS <<< "$ELEMENT_BIND"
        for OCT in "${OCTETS[@]}"; do
            [[ "$OCT" -gt 255 ]] && VALID=false && break
        done
        $VALID && break || echo "Invalid IPv4 address."
    elif [[ "$ELEMENT_BIND" =~ ^([0-9a-fA-F]{0,4}:){2,7}[0-9a-fA-F]{0,4}$ ]]; then
        break
    else
        echo "Please enter a valid IPv4 or IPv6 address, or leave empty."
    fi
done

# ELEMENT_PORT (default: 8080)
while true; do
    read -p "Element Web Port (default: 8080): " ELEMENT_PORT
    if [[ -z "$ELEMENT_PORT" ]]; then
        ELEMENT_PORT=8080
        break
    elif [[ "$ELEMENT_PORT" =~ ^[0-9]+$ ]] && [[ "$ELEMENT_PORT" -ge 1 && "$ELEMENT_PORT" -le 65535 ]]; then
        break
    else
        echo "Please enter a valid port (1-65535)."
    fi
done

# EMAIL CONFIG
while true; do
    read -p "Enable email functionality? (y/N): " EMAIL_INPUT
    EMAIL_INPUT="${EMAIL_INPUT:-n}"
    case "$EMAIL_INPUT" in
        [yYjJ]) ENABLE_EMAIL=true; break ;;
        [nN])   ENABLE_EMAIL=false; break ;;
        *)      echo "Please enter y or n." ;;
    esac
done

if [[ "$ENABLE_EMAIL" == true ]]; then
    while [[ -z "$SMTP_HOST" ]]; do
        read -p "SMTP Host (e.g. mail.example.com): " SMTP_HOST
        [[ -z "$SMTP_HOST" ]] && echo "Required field!"
    done

    while true; do
        read -p "SMTP Port (default: 587): " SMTP_PORT
        if [[ -z "$SMTP_PORT" ]]; then
            SMTP_PORT=587
            break
        elif [[ "$SMTP_PORT" =~ ^[0-9]+$ ]] && [[ "$SMTP_PORT" -ge 1 && "$SMTP_PORT" -le 65535 ]]; then
            break
        else
            echo "Please enter a valid port (1-65535)."
        fi
    done

    while [[ -z "$SMTP_USER" ]]; do
        read -p "SMTP Username (e.g. matrix@example.com): " SMTP_USER
        [[ -z "$SMTP_USER" ]] && echo "Required field!"
    done

    while [[ -z "$SMTP_PASS" ]]; do
        read -s -p "SMTP Password: " SMTP_PASS
        echo ""
        [[ -z "$SMTP_PASS" ]] && echo "Required field!"
    done

    while [[ -z "$SMTP_FROM" ]]; do
        read -p "From address (e.g. Matrix <noreply@example.com>): " SMTP_FROM
        [[ -z "$SMTP_FROM" ]] && echo "Required field!"
    done
fi

# Generate homeserver.yaml via docker run
echo ""
echo "Generating homeserver.yaml..."
echo ""

docker run -it --rm \
    --mount type=volume,src=${PROJECT}_synapse-data,dst=/data \
    -e SYNAPSE_SERVER_NAME=$SERVER_NAME \
    -e SYNAPSE_REPORT_STATS=$REPORT_STATS \
    matrixdotorg/synapse:latest generate

# Append email config to homeserver.yaml if enabled
if [[ "$ENABLE_EMAIL" == true ]]; then
    echo ""
    echo "Appending email config to homeserver.yaml..."
    docker run --rm \
        --mount type=volume,src=${PROJECT}_synapse-data,dst=/data \
        alpine sh -c "cat >> /data/homeserver.yaml << YAML

email:
  smtp_host: ${SMTP_HOST}
  smtp_port: ${SMTP_PORT}
  smtp_user: ${SMTP_USER}
  smtp_pass: ${SMTP_PASS}
  require_transport_security: true
  notif_from: '${SMTP_FROM}'
  app_name: Matrix
YAML"
fi

# Generate DB password
DBPASS=$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 32)

# Write matrix.conf
cat > matrix.conf << CONF
# Generated by $(whoami) on $(date '+%Y-%m-%d %H:%M:%S')
# ------------------------------------------------------------
# Docker configuration
# ------------------------------------------------------------
# Policy of containers being restarted
RESTART_POLICY=unless-stopped

# ------------------------------------------------------------
# Synapse configuration
# ------------------------------------------------------------
# Version of synapse docker image being pulled
SYNAPSE_VERSION=latest

# Server name (e.g. matrix.example.com)
SYNAPSE_SERVER_NAME=${SERVER_NAME}

# Enable reporting anonymous statistics to developers (yes/no)
SYNAPSE_REPORT_STATS=${REPORT_STATS}

# Federation bind address and port
# SYNAPSE_FEDERATION_BIND: IP to bind federation listener to (empty = 0.0.0.0)
# SYNAPSE_FEDERATION_PORT: Port for federation traffic (default: 8008)
SYNAPSE_FEDERATION_BIND=${SYNAPSE_FEDERATION_BIND}
SYNAPSE_FEDERATION_PORT=${SYNAPSE_FEDERATION_PORT}

# ------------------------------------------------------------
# Element Web configuration
# ------------------------------------------------------------
# ELEMENT_BIND: IP to bind Element Web to (empty = 0.0.0.0)
# ELEMENT_PORT: Port for Element Web (default: 8080)
ELEMENT_BIND=${ELEMENT_BIND}
ELEMENT_PORT=${ELEMENT_PORT}

# ------------------------------------------------------------
# SQL database configuration
# ------------------------------------------------------------
DBNAME=synapse
DBUSER=synapse
# Generated by setup.sh
DBPASS=${DBPASS}
CONF

chmod 600 matrix.conf

# Symlink .env -> matrix.conf
ln -sf matrix.conf .env

# Write element-config.json
cat > element-config.json << JSON
{
    "default_server_config": {
        "m.homeserver": {
            "base_url": "${ELEMENT_BASE_URL}",
            "server_name": "${SERVER_NAME}"
        }
    },
    "brand": "Element",
    "disable_custom_urls": false,
    "disable_guests": true,
    "disable_login_language_selector": false,
    "default_theme": "dark"
}
JSON

echo ""
echo "=== Done ==="
echo "  matrix.conf created and linked to .env"
echo "  Permissions set to 600"
echo "  element-config.json created"
[[ "$ENABLE_EMAIL" == true ]] && echo "  Email config appended to homeserver.yaml"
echo ""
echo "  DBPASS: ${DBPASS}"
echo "  (save this, it won't be shown again)"
