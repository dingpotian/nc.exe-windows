#!/bin/bash
#set -e
install_for_ubuntu() {
set -e

echo "cd /opt/"
mkdir -p /opt/
cd /opt/

echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-4.4.gpg ] https://repo.mongodb.org/apt/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME")/mongodb-org/4.4 multiverse" |  tee /etc/apt/sources.list.d/mongodb-org-4.4.list

if ! command -v curl &> /dev/null; then
  echo "install curl ..."
  apt-get install curl -y
fi

curl -fsSL https://www.mongodb.org/static/pgp/server-4.4.asc | \
gpg -o /usr/share/keyrings/mongodb-server-4.4.gpg \
--dearmor

echo "Updating package list..."
apt-get update -y
apt install software-properties-common
add-apt-repository ppa:deadsnakes/ppa
apt update -y && apt-get upgrade -y

echo "Installing dependencies..."
apt-get install -y python3.6 mongodb-org rabbitmq-server python3.6-dev g++ git nginx fontconfig \
unzip wget gnupg lsb-release python3.6-distutils -y

if [ ! -f /usr/local/bin/pip3.6 ]; then
  echo "install pip3.6"
  curl https://bootstrap.pypa.io/pip/3.6/get-pip.py -o get-pip.py
  python3.6 get-pip.py
  rm -rf get-pip.py
fi

if ! command -v alien &> /dev/null; then
  echo "install alien..."
  apt-get install alien -y
fi

if ! command -v nmap &> /dev/null; then
  echo "install nmap-7.93-1 ..."
  wget https://nmap.org/dist/nmap-7.93-1.x86_64.rpm
  alien ./nmap-7.93-1.x86_64.rpm
  dpkg -i nmap_7.93-2_amd64.deb 
  rm -f nmap-7.93-1.x86_64.rpm
fi

if ! command -v nuclei &> /dev/null; then
  echo "install nuclei_3.3.6 ..."
  wget https://github.com/projectdiscovery/nuclei/releases/download/v3.3.6/nuclei_3.3.6_linux_amd64.zip
  unzip nuclei_3.3.6_linux_amd64.zip && mv nuclei /usr/bin/ && rm -f nuclei_3.3.6_linux_amd64.zip
  nuclei -ut
fi

if ! command -v wih &> /dev/null; then
  echo "install wih ..."
  wget https://raw.githubusercontent.com/msmoshang/arl_files/master/wih/wih_linux_amd64 -O /usr/bin/wih
  chmod +x /usr/bin/wih
  wih --version
fi

echo "start services ..."
systemctl enable mongod
systemctl start mongod
systemctl enable rabbitmq-server
systemctl start rabbitmq-server

# Assuming check_and_install_pyyaml is a function defined elsewhere in your script
check_and_install_pyyaml

if [ ! -d ARL ]; then
  echo "git clone ARL proj"
  git clone https://github.com/msmoshang/ARL
fi

if [ ! -d "ARL-NPoC" ]; then
  echo "git clone ARL-NPoC proj"
  git clone https://github.com/Aabyss-Team/ARL-NPoC
fi

cd ARL-NPoC
echo "install poc requirements ..."
pip3.6 install -r requirements.txt
pip3.6 install -e .
cd ../

if [ ! -f /usr/local/bin/ncrack ]; then
  echo "Download ncrack ..."
  wget https://raw.githubusercontent.com/msmoshang/arl_files/master/ncrack -O /usr/local/bin/ncrack
  chmod +x /usr/local/bin/ncrack
fi

mkdir -p /usr/local/share/ncrack
if [ ! -f /usr/local/share/ncrack/ncrack-services ]; then
  echo "Download ncrack-services ..."
  wget https://raw.githubusercontent.com/msmoshang/arl_files/master/ncrack-services -O /usr/local/share/ncrack/ncrack-services
fi

mkdir -p /data/GeoLite2
if [ ! -f /data/GeoLite2/GeoLite2-ASN.mmdb ]; then
  echo "download GeoLite2-ASN.mmdb ..."
  wget https://git.io/GeoLite2-ASN.mmdb -O /data/GeoLite2/GeoLite2-ASN.mmdb
fi

if [ ! -f /data/GeoLite2/GeoLite2-City.mmdb ]; then
  echo "download GeoLite2-City.mmdb ..."
  wget https://git.io/GeoLite2-City.mmdb -O /data/GeoLite2/GeoLite2-City.mmdb
fi

cd ARL

if [ ! -f rabbitmq_user ]; then
  echo "add rabbitmq user"
  rabbitmqctl add_user arl arlpassword
  rabbitmqctl add_vhost arlv2host
  rabbitmqctl set_user_tags arl arltag
  rabbitmqctl set_permissions -p arlv2host arl ".*" ".*" ".*"
  echo "init arl user"
  rand_pass
  mongo 127.0.0.1:27017/arl docker/mongo-init.js
  touch rabbitmq_user
fi

echo "install arl requirements ..."
pip3.6 install -r requirements.txt
if [ ! -f app/config.yaml ]; then
  echo "create config.yaml"
  cp app/config.yaml.example app/config.yaml
fi

if [ ! -f /usr/bin/phantomjs ]; then
  echo "install phantomjs"
  ln -s `pwd`/app/tools/phantomjs /usr/bin/phantomjs
fi

add_check_nginx_log_format

if [ ! -f /etc/nginx/sites-available/arl.conf ]; then
  echo "copy arl.conf"
  cp misc/arl.conf /etc/nginx/sites-available/arl.conf
  ln -s /etc/nginx/sites-available/arl.conf /etc/nginx/sites-enabled/
fi

if [ ! -f /etc/ssl/certs/dhparam.pem ]; then
  echo "download dhparam.pem"
  curl https://ssl-config.mozilla.org/ffdhe2048.txt > /etc/ssl/certs/dhparam.pem
fi

echo "gen cert ..."
chmod +x ./docker/worker/gen_crt.sh
./docker/worker/gen_crt.sh

nginx -s reload

cd /opt/ARL/

if [ ! -f /etc/systemd/system/arl-web.service ]; then
  echo "copy arl-web.service"
  cp misc/arl-web.service /etc/systemd/system/
fi

if [ ! -f /etc/systemd/system/arl-worker.service ]; then
  echo "copy arl-worker.service"
  cp misc/arl-worker.service /etc/systemd/system/
fi

if [ ! -f /etc/systemd/system/arl-worker-github.service ]; then
  echo "copy arl-worker-github.service"
  cp misc/arl-worker-github.service /etc/systemd/system/
fi

if [ ! -f /etc/systemd/system/arl-scheduler.service ]; then
  echo "copy arl-scheduler.service"
  cp misc/arl-scheduler.service /etc/systemd/system/
fi

nginx -s reload

echo "massdns run"
cd /opt/ARL/app/tools/
chmod +x massdns

echo "start arl services ..."
systemctl enable arl-web
systemctl start arl-web
systemctl enable arl-worker
systemctl start arl-worker
systemctl enable arl-worker-github
systemctl start arl-worker-github
systemctl enable arl-scheduler
systemctl start arl-scheduler
systemctl enable nginx
systemctl start nginx

echo "restart services"
systemctl start mongod
systemctl start rabbitmq-server
systemctl start arl-web
systemctl start arl-worker
systemctl start arl-worker-github
systemctl start arl-scheduler

echo "status services"
systemctl --no-pager status mongod
systemctl --no-pager status rabbitmq-server
systemctl --no-pager status arl-web
systemctl --no-pager status arl-worker
systemctl --no-pager status arl-worker-github
systemctl --no-pager status arl-scheduler

echo "install done"
}

# 调用函数
install_for_ubuntu