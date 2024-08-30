#!/bin/sh

# Verificación de argumentos
if [ "$#" -ne 4 ]; then
    echo "Wrong number of arguments"
    exit 1
fi


DOMAIN_APP=$1
DOMAIN_CHAT=$2

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
        server_name $DOMAIN_APP;
        client_max_body_size 1000M;
        location / {
            proxy_pass http://citas:8080;
            proxy_redirect off;
            proxy_set_header Host \$host;
        }
        ssl_certificate /etc/letsencrypt/live/$DOMAIN_APP/fullchain.pem;
        ssl_certificate_key /etc/letsencrypt/live/$DOMAIN_APP/privkey.pem;
        ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
        ssl_ciphers HIGH:!aNULL:!MD5;
    }
    server {
        listen 443 ssl;
        server_name $DOMAIN_CHAT;
        client_max_body_size 1000M;
        location / {
          proxy_pass http://citas:8080/chat;
          proxy_redirect off;
          proxy_set_header Host \$host;
        }
        location /chat {
          proxy_pass http://citas:8080;
          proxy_redirect off;
          proxy_set_header Host \$host;
        }
        location /styles {
          rewrite ^/chat(.*) /\$1 break;
          proxy_pass http://citas:8080;
          proxy_redirect off;
          proxy_set_header Host \$host;
        }
        location /scripts {
          rewrite ^/chat(.*) /\$1 break;
          proxy_pass http://citas:8080;
          proxy_redirect off;
          proxy_set_header Host \$host;
        }
        location /files {
          rewrite ^/chat(.*) /\$1 break;
          proxy_pass http://citas:8080;
          proxy_redirect off;
          proxy_set_header Host \$host;
        }
        ssl_certificate /etc/letsencrypt/live/$DOMAIN_CHAT/fullchain.pem;
        ssl_certificate_key /etc/letsencrypt/live/$DOMAIN_CHAT/privkey.pem;
        ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
        ssl_ciphers HIGH:!aNULL:!MD5;
    }
}
EOL

#sidecar docker-compose
cat <<EOL > ./sidecar/docker-compose.yml

services:
  sidecar:
    image: nginx:1.26.0-alpine3.19-slim
    container_name: sidecar-nginx
    restart: always
    volumes:
      - /etc/letsencrypt/live/$DOMAIN_APP/fullchain.pem:/etc/letsencrypt/live/$DOMAIN_APP/fullchain.pem
      - /etc/letsencrypt/live/$DOMAIN_APP/privkey.pem:/etc/letsencrypt/live/$DOMAIN_APP/privkey.pem
      - /etc/letsencrypt/live/$DOMAIN_CHAT/fullchain.pem:/etc/letsencrypt/live/$DOMAIN_CHAT/fullchain.pem
      - /etc/letsencrypt/live/$DOMAIN_CHAT/privkey.pem:/etc/letsencrypt/live/$DOMAIN_CHAT/privkey.pem
      - ./nginx.conf:/etc/nginx/nginx.conf
    ports:
      - "443:443"
      - "80:80"
    mem_limit: 30m  # Limitar la memoria a 30 MB
    networks:
      - bot_network
networks:
  bot_network:
    external: true
EOL

#app docker-compose
cat <<EOL > ./app/docker-compose.yml

services:
  citas:
    image: alexfer/chatbotinfocitas:1.1.0
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
    mem_limit: 500m  # Limitar la memoria a 500 MB
    networks:
      - bot_network
networks:
  bot_network:
    external: true
EOL

#db docker-compose
cat <<EOL > ./db/docker-compose.yml

services:
  chatbotinfocitas_mongo:
    image: mongo:7.0.3
    container_name: chatbotinfocitas_mongo
    environment:
      MONGO_INITDB_ROOT_USERNAME: $DBUSER
      MONGO_INITDB_ROOT_PASSWORD: $DBPASS
      MONGO_INITDB_DATABASE: chatbotinfocitas
    volumes:
      - ./mongo-data:/data/db
    ports:
      - "27017:27017"
    mem_limit: 160m  # Limitar la memoria a 160 MB
    restart: always
    networks:
      - bot_network
volumes:
  mongo-data:
networks:
  bot_network:
    external: true

EOL
