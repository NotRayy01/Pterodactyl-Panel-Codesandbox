#!/bin/bash

# Variables
DB_PASS="StrongDBPass123"
DB_ROOT_PASS="StrongRootPass123"
APP_URL="https://pterodactyl.example.com"
TIMEZONE="Asia/Kolkata"
EMAIL="noreply@example.com"

# Create folders
mkdir -p pterodactyl/panel
cd pterodactyl/panel || exit

# Create docker-compose.yml
cat > docker-compose.yml <<EOL
version: '3.8'

x-common:
  database:
    &db-environment
    MYSQL_PASSWORD: &db-password "${DB_PASS}"
    MYSQL_ROOT_PASSWORD: "${DB_ROOT_PASS}"
  panel:
    &panel-environment
    APP_URL: "${APP_URL}"
    APP_TIMEZONE: "${TIMEZONE}"
    APP_SERVICE_AUTHOR: "${EMAIL}"
    TRUSTED_PROXIES: "*"
  mail:
    &mail-environment
    MAIL_FROM: "${EMAIL}"
    MAIL_DRIVER: "smtp"
    MAIL_HOST: "mail"
    MAIL_PORT: "1025"
    MAIL_USERNAME: ""
    MAIL_PASSWORD: ""
    MAIL_ENCRYPTION: "true"

services:
  database:
    image: mariadb:10.5
    restart: always
    command: --default-authentication-plugin=mysql_native_password
    volumes:
      - "./data/database:/var/lib/mysql"
    environment:
      <<: *db-environment
      MYSQL_DATABASE: "panel"
      MYSQL_USER: "pterodactyl"

  cache:
    image: redis:alpine
    restart: always

  panel:
    image: ghcr.io/pterodactyl/panel:latest
    restart: always
    ports:
      - "8030:80"
      - "4433:443"
    links:
      - database
      - cache
    volumes:
      - "./data/var:/app/var"
      - "./data/nginx:/etc/nginx/http.d"
      - "./data/certs:/etc/letsencrypt"
      - "./data/logs:/app/storage/logs"
    environment:
      <<: [*panel-environment, *mail-environment]
      DB_PASSWORD: *db-password
      APP_ENV: "production"
      APP_ENVIRONMENT_ONLY: "false"
      CACHE_DRIVER: "redis"
      SESSION_DRIVER: "redis"
      QUEUE_DRIVER: "redis"
      REDIS_HOST: "cache"
      DB_HOST: "database"
      DB_PORT: "3306"

networks:
  default:
    ipam:
      config:
        - subnet: 172.20.0.0/16
EOL

# Create necessary data folders
mkdir -p ./data/{database,var,nginx,certs,logs}

# Run docker compose
docker-compose up -d

# Create first user interactively
docker-compose run --rm panel php artisan p:user:make
