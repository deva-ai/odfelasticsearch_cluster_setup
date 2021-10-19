#!/bin/bash
#check the function before executing
#author=ai
d=********************************************

baseDir=`pwd`

echo $d" This is odfe three node cluster formation "$d

check_root() {
  if [[ "x$(id -u)" != 'x0' ]]; then
    echo '<<<============ Error: this script can only be executed by root ==============>>>'
    exit 1
  fi
}

check_os() {
  if [ ! -e /etc/lsb-release ]; then
    echo '<<<============ Error: sorry, this installer works only on ubuntu ==============>>>'
    exit 1
  fi
}

clearCache() {
  sync; echo 1 > /proc/sys/vm/drop_caches
}

installElastic() {
  sudo apt update
  if [ ! -d /usr/share/elasticsearch/ ]; then
    yes "" | sudo add-apt-repository ppa:openjdk-r/ppa
    sudo apt update
    sudo apt install -y openjdk-11-jdk unzip
    wget -qO - https://d3g5vo6xdbdb9a.cloudfront.net/GPG-KEY-opendistroforelasticsearch | sudo apt-key add -
    echo "deb https://d3g5vo6xdbdb9a.cloudfront.net/apt stable main" | sudo tee -a   /etc/apt/sources.list.d/opendistroforelasticsearch.list
    wget https://artifacts.elastic.co/downloads/elasticsearch/elasticsearch-oss-7.10.2-amd64.deb -O /tmp/elasticsearch-oss-7.10.2-amd64.deb -O /tmp/elasticsearch-oss-7.10.2-amd64.deb
    sudo dpkg -i /tmp/elasticsearch-oss-7.10.2-amd64.deb
    sudo apt-get update
    sudo apt install -y opendistroforelasticsearch
    echo $d" opendistroforelasticsearch is installed wait for 30sec to setup files "$d
    sleep 30
    clearCache
    $nodetype
  else
    echo $d" Please check elasticsearch file directory's are there "$d
    service elasticsearch status


  fi
}

installKibana() {
  if [ ! -d /usr/share/kibana/ ]; then
    sudo apt install -y opendistroforelasticsearch-kibana
    if [ $(cat /etc/kibana/kibana.yml | grep -c "server.rewriteBasePath:") -eq 0 ]; then
      echo "server.rewriteBasePath: true" >> /etc/kibana/kibana.yml
    fi
    if [ $(cat /etc/kibana/kibana.yml | grep -c "server.basePath:") -eq 0 ]; then
      echo "server.basePath: \"/kibana\"" >> /etc/kibana/kibana.yml
    fi
    sed -i "/elasticsearch.username:/c\elasticsearch.username: admin" /etc/kibana/kibana.yml
    sed -i "/elasticsearch.password:/c\elasticsearch.password: admin" /etc/kibana/kibana.yml
    echo "server.host: 0.0.0.0" >> /etc/kibana/kibana.yml
    echo "logging.dest: /var/log/kibana/kibana.log" >> /etc/kibana/kibana.yml
    mkdir -p /var/log/kibana
    touch /var/log/kibana/kibana.log
    chmod -R 777 /var/log/kibana/kibana.log
    systemctl enable kibana
    echo $d" Starting kibana service "$d
    systemctl start kibana
  fi
}

master() {
  echo $d" Setup Cluster "$d
  systemctl enable elasticsearch.service
  sudo systemctl start elasticsearch.service
  sudo systemctl status elasticsearch.service
  echo $d" waitong for 60sec elasticsearch service will comes up "$d
  sleep 60
  echo "cluster.name: odfe-cluster" >> /etc/elasticsearch/elasticsearch.yml
  echo "node.name: masternode" >> /etc/elasticsearch/elasticsearch.yml
  echo "node.master: true" >> /etc/elasticsearch/elasticsearch.yml
  echo "node.data: false" >> /etc/elasticsearch/elasticsearch.yml
  echo "node.ingest: false" >> /etc/elasticsearch/elasticsearch.yml
  echo "network.host: 0.0.0.0" >> /etc/elasticsearch/elasticsearch.yml
  echo "discovery.seed_hosts: [\"$masternode\", \"$datanode1\", \"$datanode2\"]" >> /etc/elasticsearch/elasticsearch.yml
  sleep 5
  sudo systemctl restart elasticsearch.service
  if [ $? -eq 0 ]; then
    echo "elasticsearch service started"
  else
    sed -i 's/node.data: false/node.data: true/' /etc/elasticsearch/elasticsearch.yml
    sudo systemctl start elasticsearch.service
    if [ $? -eq 0 ]; then
      echo "elasticsearch service started"
    else
      echo "failed to start elasticsearch service"
      exit 1
    fi
  fi
  sleep 60
  installKibana
  cd $baseDir
}

datanode1() {
  echo $d" Setup Cluster "$d
  echo "cluster.name: odfe-cluster" >> /etc/elasticsearch/elasticsearch.yml
  echo "node.name: datanode-1" >> /etc/elasticsearch/elasticsearch.yml
  echo "node.master: true" >> /etc/elasticsearch/elasticsearch.yml
  echo "node.data: true" >> /etc/elasticsearch/elasticsearch.yml
  echo "node.ingest: true" >> /etc/elasticsearch/elasticsearch.yml
  echo "network.host: 0.0.0.0" >> /etc/elasticsearch/elasticsearch.yml
  echo "discovery.seed_hosts: [\"$masternode\", \"$datanode1\", \"$datanode2\"]" >> /etc/elasticsearch/elasticsearch.yml
  sleep 10
  systemctl enable elasticsearch.service
  sudo systemctl start elasticsearch.service
  checkClusterstatus
}

datanode2() {
  echo $d" Setup Cluster "$d
  echo "cluster.name: odfe-cluster" >> /etc/elasticsearch/elasticsearch.yml
  echo "node.name: datanode-3" >> /etc/elasticsearch/elasticsearch.yml
  echo "node.master: true" >> /etc/elasticsearch/elasticsearch.yml
  echo "node.data: true" >> /etc/elasticsearch/elasticsearch.yml
  echo "node.ingest: true" >> /etc/elasticsearch/elasticsearch.yml
  echo "network.host: 0.0.0.0" >> /etc/elasticsearch/elasticsearch.yml
  echo "discovery.seed_hosts: [\"$masternode\", \"$datanode1\", \"$datanode2\"]" >> /etc/elasticsearch/elasticsearch.yml
  sleep 10
  systemctl enable elasticsearch.service
  sudo systemctl start elasticsearch.service
}

checkClusterstatus() {
  echo $d" Cluster status "$d
  curl -XGET https://$masternode:9200/_cat/nodes?v -u 'admin:admin' --insecure
}


install() {
  check_root
  check_os
  installElastic
  clearCache
}
if [ $# -ne 4 ]; then
  echo $d" please pass the master & data node IP's and node-type then re-run the script "$d
  exit 1
fi

masternode=$1
datanode1=$2
datanode2=$3
nodetype=$4

install
