#!/bin/sh

# Verificación de argumentos
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 domain_name localhost"
    exit 1
fi

DOMAIN=$1
APP=$2
DBUSER=$3
DBPASS=$4


#sidecar nginx config
cat <<EOL > ./sidecar/nginx.conf
worker_processes  1;
events { worker_connections  1024; }
http {
    include mime.types;
    default_type application/octet-stream;
    sendfile on;
    keepalive_timeout  65;
    server {
        listen 80 default_server;
        return 301 https://\$host\$request_uri;
    }
    server {
        listen 443 ssl;
        server_name $DOMAIN1;
        client_max_body_size 1000M;
        location / {
            proxy_pass http://citas:8080;
            proxy_redirect off;
            proxy_set_header Host \$host;
        }
        ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
        ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
        ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
        ssl_ciphers HIGH:!aNULL:!MD5;
    }
}
EOL

#sidecar docker-compose
cat <<EOL > ./sidecar/docker-compose.yml
version: '3.8'

services:
  sidecar:
    image: nginx:1.26.0-alpine3.19-slim
    container_name: sidecar-nginx
    restart: always
    volumes:
      - /etc/letsencrypt/live/$DOMAIN/fullchain.pem:/etc/letsencrypt/live/$DOMAIN/fullchain.pem
      - /etc/letsencrypt/live/$DOMAIN/privkey.pem:/etc/letsencrypt/live/$DOMAIN/privkey.pem
      - ./nginx.conf:/etc/nginx/nginx.conf
    ports:
      - "443:443"
      - "80:80"
    networks:
      - bot_network
networks:
  bot_network:
    external: true
EOL

#app docker-compose
cat <<EOL > ./app/docker-compose.yml
version: '3.8'

services:
  citas:
    image: alexfer/chatbotinfocitas:1.0.0
    container_name: chatbotinfocitas_spring
    environment:
      - SPRING_DATA_MONGODB_HOST=chatbotinfocitas_mongo
      - SPRING_DATA_MONGODB_USERNAME=$DBUSER
      - SPRING_DATA_MONGODB_PASSWORD=$DBPASS
      - SPRING_DATA_MONGODB_DATABASE=chatbotinfocitas
      - SPRING_PROFILES_ACTIVE=docker
    restart: always
    ports:
      - "8080:8080"
    networks:
      - bot_network
networks:
  bot_network:
    external: true
EOL

#db docker-compose
cat <<EOL > ./db/docker-compose.yml
version: '3.8'

services:
  chatbotinfocitas_mongo:
    image: mongo:7.0.3
    container_name: chatbotinfocitas_mongo
    environment:
      MONGO_INITDB_ROOT_USERNAME: $DBUSER
      MONGO_INITDB_ROOT_PASSWORD: $DBPASS
      MONGO_INITDB_DATABASE: chatbotinfocitas
    volumes:
      - mongo-data:/data/db
    ports:
      - "27017:27017"
    restart: always
    networks:
      - bot_network
volumes:
  mongo-data:
networks:
  bot_network:
    external: true

EOL
