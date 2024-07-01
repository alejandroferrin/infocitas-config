#!/bin/sh

# Verificación de argumentos
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 domain_name"
    exit 1
fi

DOMAIN_APP=$1
DOMAIN_CHAT=$2

certbot certonly -d $DOMAIN_APP --noninteractive --standalone --agree-tos --register-unsafely-without-email
certbot certonly -d $DOMAIN_CHAT --noninteractive --standalone --agree-tos --register-unsafely-without-email
