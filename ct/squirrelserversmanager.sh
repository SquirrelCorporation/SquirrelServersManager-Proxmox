#!/usr/bin/env bash
source <(curl -s https://raw.githubusercontent.com/SquirrelCorporation/SquirrelServersManager-Proxmox/main/misc/build.func)
# Copyright (c) 2021-2024 tteck
# Author: tteck (tteckster)
# License: MIT
# https://github.com/tteck/Proxmox/raw/main/LICENSE

function header_info {
clear
cat <<"EOF"
   _____             _                __   _____                                   __  ___
  / ___/____ ___  __(_)____________  / /  / ___/___  ______   _____  __________   /  |/  /___ _____  ____ _____ ____  _____
  \__ \/ __ `/ / / / / ___/ ___/ _ \/ /   \__ \/ _ \/ ___/ | / / _ \/ ___/ ___/  / /|_/ / __ `/ __ \/ __ `/ __ `/ _ \/ ___/
 ___/ / /_/ / /_/ / / /  / /  /  __/ /   ___/ /  __/ /   | |/ /  __/ /  (__  )  / /  / / /_/ / / / / /_/ / /_/ /  __/ /
/____/\__, /\__,_/_/_/  /_/   \___/_/   /____/\___/_/    |___/\___/_/  /____/  /_/  /_/\__,_/_/ /_/\__,_/\__, /\___/_/
        /_/                                                                                             /____/
Installer v1.1.2
EOF
}
header_info
echo -e "Loading..."
APP="Squirrel Servers Manager"
var_disk="10"
var_cpu="2"
var_ram="4096"
var_os="alpine"
var_version="3.19"
variables
color
catch_errors

function default_settings() {
  CT_TYPE="1"
  PW=""
  CT_ID=$NEXTID
  HN=$NSAPP
  DISK_SIZE="$var_disk"
  CORE_COUNT="$var_cpu"
  RAM_SIZE="$var_ram"
  BRG="vmbr0"
  NET="dhcp"
  GATE=""
  APT_CACHER=""
  APT_CACHER_IP=""
  DISABLEIP6="no"
  MTU=""
  SD=""
  NS=""
  MAC=""
  VLAN=""
  SSH="no"
  VERB="no"
  echo_default
}

function update_script() {
  header_info
  if [[ ! -d /opt/squirrelserversmanager ]]; then msg_error "No ${APP} Installation Found!"; exit; fi

  # Display warning and wait for user input
  echo -e "\n\033[1;33mWARNING:\033[0m It is highly recommended that you temporary set the container memory to 4096MB for the duration of the update"
  echo -e "Press any key to continue or Ctrl+C to cancel..."
  read -n 1 -s -r

  msg_info "Stopping ${APP}..."
  pm2 stop "squirrelserversmanager-frontend"
  pm2 stop "squirrelserversmanager-backend"
  msg_ok "${APP} stopped"

  msg_info "Updating SSM SharedLib..."
  cd /opt/squirrelserversmanager
  git pull
  cd /opt/squirrelserversmanager/shared-lib
  npm ci
  npm run build
  msg_ok "SSM SharedLib updated"

  msg_info "Updating SSM Server..."
  cd /opt/squirrelserversmanager/server
  npm ci
  npm run build
  msg_ok "SSM Server updated"

  msg_info "Updating SSM Client..."
  cd /opt/squirrelserversmanager/client
  npm ci
  npm run build
  msg_ok "SSM Client updated"

  msg_info "Restarting ${APP}..."
  pm2 flush
  pm2 restart "squirrelserversmanager-frontend"
  pm2 restart "squirrelserversmanager-backend"

  msg_ok "Successfully Updated ${APP}"
  exit
}


start
build_container
description
msg_info "Setting Container to Normal Resources"
pct set "$CTID" -memory 2048
pct set "$CTID" -cores 2
msg_ok "Set Container to Normal Resources"
msg_ok "Completed Successfully!\n"
echo -e "${APP} should be reachable by going to the following URL.
         ${BL}http://${IP}:80${CL} \n"
