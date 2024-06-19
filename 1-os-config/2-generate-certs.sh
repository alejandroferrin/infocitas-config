#!/bin/sh

# Verificación de argumentos
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 domain_name"
    exit 1
fi

DOMAIN=$1

certbot certonly -d $DOMAIN --noninteractive --standalone --agree-tos --register-unsafely-without-email