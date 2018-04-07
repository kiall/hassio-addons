#!/bin/bash
set -e

CERT_DIR=/data/letsencrypt
WORK_DIR=/data/workdir
CONFIG_PATH=/data/options.json

# Let's Encrypt
LE_TERMS=$(jq --raw-output '.lets_encrypt.accept_terms' $CONFIG_PATH)
LE_DOMAINS=$(jq --raw-output '.domains[]' $CONFIG_PATH)
LE_UPDATE="0"

# CloudFlare
CF_EMAIL=$(jq --raw-output '.cloudflare.email' $CONFIG_PATH)
CF_KEY=$(jq --raw-output '.cloudflare.key' $CONFIG_PATH)

# Common
WAIT_TIME=$(jq --raw-output '.seconds' $CONFIG_PATH)

# Function that performe a renewal
function le_renew() {
    local domain_args=()
  
    # Prepare domain for Let's Encrypt
    for domain in $LE_DOMAINS; do
        domain_args+=("--domain" "$domain")
    done
    
    CF_EMAIL=$CF_EMAIL CF_KEY=$CF_KEY dehydrated --cron --hook ./hooks.sh --challenge dns-01 "${domain_args[@]}" --out "$CERT_DIR" --config "$WORK_DIR/config" || true
    LE_UPDATE="$(date +%s)"
}

# Register/generate certificate if terms accepted
if [ "$LE_TERMS" == "true" ]; then
    # Init folder structs
    mkdir -p "$CERT_DIR"
    mkdir -p "$WORK_DIR"
    
    # Generate new certs
    if [ ! -d "$CERT_DIR/live" ]; then
        # Create empty dehydrated config file so that this dir will be used for storage
        touch "$WORK_DIR/config"
        
        CF_EMAIL=$CF_EMAIL CF_KEY=$CF_KEY dehydrated --register --accept-terms --config "$WORK_DIR/config"
    fi
fi

# Run Forever
while true; do
    now="$(date +%s)"
    if [ "$LE_TERMS" == "true" ] && [ $((now - LE_UPDATE)) -ge 43200 ]; then
        le_renew
    fi
    
    sleep "$WAIT_TIME"
done