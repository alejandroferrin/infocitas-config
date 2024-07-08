#!/bin/sh

# Verificación de argumentos
if [ "$#" -ne 7 ]; then
    echo "Wrong number of arguments"
    exit 1
fi

DOCKER_USER=$1
DOCKER_PASS=$2

DOMAIN_APP=$3
DOMAIN_CHAT=$4

APP=$5
DBUSER=$6
DBPASS=$7

# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo curl -L https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

#Docker login
docker login -u $DOCKER_USER -p $DOCKER_PASS

#Create docker network
docker network create bot_network

# Install certbot:
sudo apt-get install certbot

#Generate certificates for https
certbot certonly -d $DOMAIN_APP --noninteractive --standalone --agree-tos --register-unsafely-without-email
certbot certonly -d $DOMAIN_CHAT --noninteractive --standalone --agree-tos --register-unsafely-without-email

#Crar carpetas
mkdir db
mkdir app
mkdir sidecar

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
          proxy_set_header Host $host;
        }
        location /chat {
          proxy_pass http://citas:8080;
          proxy_redirect off;
          proxy_set_header Host $host;
        }
        location /styles {
          rewrite ^/chat(.*) /$1 break;
          proxy_pass http://citas:8080;
          proxy_redirect off;
          proxy_set_header Host $host;
        }
        location /scripts {
          rewrite ^/chat(.*) /$1 break;
          proxy_pass http://citas:8080;
          proxy_redirect off;
          proxy_set_header Host $host;
        }
        location /files {
          rewrite ^/chat(.*) /$1 break;
          proxy_pass http://citas:8080;
          proxy_redirect off;
          proxy_set_header Host $host;
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
    restart: always
    networks:
      - bot_network
volumes:
  mongo-data:
networks:
  bot_network:
    external: true

EOL
