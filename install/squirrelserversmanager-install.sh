#!/usr/bin/env bash

# Copyright (c) 2021-2024 tteck
# Author: tteck (tteckster)
# License: MIT
# https://github.com/tteck/Proxmox/raw/main/LICENSE
source /dev/stdin <<< "$FUNCTIONS_FILE_PATH"

color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

# Generate a random string
generate_random_string() {
    local LENGTH=$1
  tr -dc A-Za-z0-9 </dev/urandom | head -c ${LENGTH} 2>/dev/null || true
}

msg_info "Installing Dependencies"
$STD apk add git
$STD apk add nodejs
$STD apk add npm
$STD apk add ansible
$STD apk add nmap
$STD apk add sudo
$STD apk add openssh
$STD apk add sshpass
$STD apk add py3-pip
$STD apk add expect
$STD apk add libcurl
$STD apk add gcompat
$STD apk add curl
$STD apk add newt
$STD apk add docker
$STD apk add docker-cli-compose
$STD rm -f /usr/lib/python3.12/EXTERNALLY-MANAGED
$STD git --version
$STD node --version
$STD npm --version
msg_ok "Installed Dependencies"

msg_info "Installing Redis"
$STD apk add redis
msg_ok "Installed Redis"

msg_info "Installing Nginx"
$STD apk add nginx
rm -rf /etc/nginx/http.d/default.conf
cat <<'EOF'> /etc/nginx/http.d/default.conf
server {
  listen 80;
  server_name localhost;
  access_log off;
  error_log off;

 location /api/socket.io/ {
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
      proxy_set_header Host $host;

      proxy_pass http://127.0.0.1:3000/socket.io/;

      proxy_http_version 1.1;
      proxy_set_header Upgrade $http_upgrade;
      proxy_set_header Connection "upgrade";
  }

  location /api/ {
    proxy_pass http://127.0.0.1:3000/;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
  }

  location / {
    proxy_pass http://127.0.0.1:8000/;

    # WebSocket support
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";

    error_page 501 502 503 404 /custom.html;
    location = /custom.html {
            root /usr/share/nginx/html;
    }
  }
}

EOF
msg_ok "Installed Nginx"

msg_info "Installing MongoDB Database"
DB_NAME=ssm
DB_PORT=27017
echo 'http://dl-cdn.alpinelinux.org/alpine/v3.9/main' >> /etc/apk/repositories
echo 'http://dl-cdn.alpinelinux.org/alpine/v3.9/community' >> /etc/apk/repositories
$STD apk update
$STD apk add mongodb mongodb-tools
msg_ok "Installed MongoDB Database"


msg_info "Starting Services"
$STD rc-service redis start
$STD rc-update add redis default
$STD rc-service mongodb start
$STD rc-update add mongodb default
msg_ok "Started Services"

msg_info "Setting Up Squirrel Servers Manager (could take several minutes)"
$STD git clone --branch release https://github.com/SquirrelCorporation/SquirrelServersManager.git /opt/squirrelserversmanager
SECRET=$(generate_random_string 32)
SALT=$(generate_random_string 16)
VAULT_PWD=$(generate_random_string 32)
PROMETHEUS_PASSWORD=$(generate_random_string 32)
PROMETHEUS_USERNAME="ssm_prometheus_user"
cat <<EOF > /opt/squirrelserversmanager/.env
# SECRETS
SECRET=$SECRET
SALT=$SALT
VAULT_PWD=$VAULT_PWD
# MONGO
DB_HOST=127.0.0.1
DB_NAME=ssm
DB_PORT=27017
# REDIS
REDIS_HOST=127.0.0.1
REDIS_PORT=6379
# SSM CONFIG
SSM_INSTALL_PATH=/opt/squirrelserversmanager
SSM_DATA_PATH=/opt/squirrelserversmanager/data
# PROMETHEUS
PROMETHEUS_HOST=http://127.0.0.1:9090
#PROMETHEUS_BASE_URL=/api/v1
PROMETHEUS_USERNAME=$PROMETHEUS_USERNAME
PROMETHEUS_PASSWORD=$PROMETHEUS_PASSWORD
EOF
export NODE_ENV=production
export $(grep -v '^#' /opt/squirrelserversmanager/.env | xargs)
$STD npm install -g npm@latest
$STD npm install -g @umijs/max
$STD npm install -g typescript
$STD npm install pm2 -g
$STD pip install ansible-runner ansible-runner-http
msg_ok "Squirrel Servers Manager Has Been Setup"

msg_info "Installing Prometheus Database"
curl -LJO https://github.com/prometheus/prometheus/releases/download/v3.2.0/prometheus-3.2.0.linux-amd64.tar.gz
mkdir -p /opt/prometheus
tar x -f prometheus-3.2.0.linux-amd64.tar.gz -C /opt/prometheus --strip-components=1
rm -f prometheus-3.2.0.linux-amd64.tar.gz
mkdir -p /etc/prometheus/
cat <<EOF > /etc/prometheus/prometheus.yml
global:
  scrape_interval: 15s  # How often Prometheus scrapes targets

scrape_configs:
  - job_name: 'server-metrics' # Server pulling statistics
    basic_auth:
      username: "$PROMETHEUS_USERNAME"
      password: "$PROMETHEUS_PASSWORD"
    static_configs:
      - targets:
          - '127.0.0.1:3000'
EOF
$STD pm2 start --name="squirrelserversmanager-prometheus" /opt/prometheus/prometheus -- --config.file=/etc/prometheus/prometheus.yml
msg_ok "Installed Prometheus Database"

msg_info "Building Squirrel Servers Manager Lib"
cd /opt/squirrelserversmanager/shared-lib
$STD npm ci
$STD npm run build
msg_ok "Squirrel Servers Manager Lib built"

msg_info "Building & Running Squirrel Servers Manager Client (could take several minutes)"
cd /opt/squirrelserversmanager/client
$STD npm ci
$STD npm run build
$STD pm2 start --name="squirrelserversmanager-frontend" npm -- run serve
msg_ok "Squirrel Servers Manager Client Built & Ran"

msg_info "Building & Running Squirrel Servers Manager Server (could take several minutes)"
cd /opt/squirrelserversmanager/server
$STD npm ci
$STD npm run build
$STD pm2 start --name="squirrelserversmanager-backend" node -- ./dist/src/index.js
msg_ok "Squirrel Servers Manager Server Built & Ran"

msg_info "Starting Squirrel Servers Manager"
$STD pm2 startup
$STD pm2 save
mkdir -p /usr/share/nginx/html/
cp /opt/squirrelserversmanager/proxy/www/index.html /usr/share/nginx/html/custom.html

$STD rc-service nginx start
$STD rc-update add nginx default
msg_ok "Squirrel Servers Manager Started"

motd_ssh
customize
