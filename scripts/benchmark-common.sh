# Common function for benchmark scripts

function update_config() {
  local block_size=$1
  $CONFIG_DIR/generate_config.sh $ORG_COUNT $PEER_COUNT $ORDERER_COUNT $block_size
  (cd $CONFIG_DIR; ./update.sh)
  pdcp -g orderer.group,peer.group,ca.group $CONFIG_DIR/{genesis.block,mychannel.tx} ~/$CONFIG_NAME/
}

function check_device() {
  for org in `seq $ORG_COUNT`; do
    for i in `seq 0 \`expr $PEER_COUNT - 1\``; do
      ssh peer${i}-org${org}.${DOMAIN} test -b $FABRIC_PEER_FS_DEV
      if [ $? -ne 0 ]; then
        local host=$(getent hosts peer${i}-org${org}.${DOMAIN})
        notify "NVMe device not found: $host"
        exit 1
      fi
      echo "peer${i}-org${org}.${DOMAIN}: NVMe device ready"
    done
  done
}

function init_volume() {
  pdsh -g orderer.group sudo rm -rf /mnt/*
  pdsh -g peer.group sudo umount -f /mnt
  sleep 5
  pdsh -g peer.group sudo mkfs -t xfs -f $FABRIC_PEER_FS_DEV
  pdsh -g peer.group sudo mount $FABRIC_PEER_FS_DEV /mnt
  pdsh -g peer.group df -h | dshbak
}

function docker_compose_up() {
  docker stack deploy caliper -c $FABRIC_NETWORK_DIR/docker-compose.yaml
}

function docker_compose_down() {
  docker stack rm caliper
}

function setup_chaincode() {
  (
    cd $CALIPER_DIR/packages/caliper-cli
    node caliper.js launch master \
      --caliper-workspace $CALIPER_BENCH_BASE_DIR \
      --caliper-benchconfig $CALIPER_BENCH_CONFIG \
      --caliper-networkconfig $CALIPER_BENCH_NETCONFIG \
      --caliper-flow-only-init
    node caliper.js launch master \
      --caliper-workspace $CALIPER_BENCH_BASE_DIR \
      --caliper-benchconfig $CALIPER_BENCH_CONFIG \
      --caliper-networkconfig $CALIPER_BENCH_NETCONFIG \
      --caliper-flow-only-install
  )
  if [ $? -ne 0 ]; then
    notify "Fabric network setup failed"
    exit 1
  fi
}

function wait_for_ready() {
  for org in `seq $ORG_COUNT`; do
    for i in `seq 0 \`expr $PEER_COUNT - 1\``; do
      cpu_util=$(ssh peer${i}-org${org}.${DOMAIN} top -b -n 1 | grep peer | awk '{print $9}' | cut -d "." -f 1)
      if [ $cpu_util -gt 10 ]; then
        echo "$(date) Wait for block height stable: peer${i}-org${org} cpu ${cpu_util}%"
        return 1
      fi
    done
  done
  return 0
}

function run() {
  local block_size=$1
  local log_dir=$2
  (
    cd $CALIPER_DIR/packages/caliper-cli
    node caliper.js launch master \
      --caliper-workspace $CALIPER_BENCH_BASE_DIR \
      --caliper-benchconfig $CALIPER_BENCH_CONFIG \
      --caliper-networkconfig $CALIPER_BENCH_NETCONFIG \
      --caliper-report-path ${log_dir}/${PEER_COUNT}peer${ORDERER_COUNT}orderer.bs${block_size}.html \
      --caliper-flow-only-test
  )
}

function generate_payload() {
  local message=$@
  cat << EOF
{
  "text": "Notification from benchmark script",
  "blocks": [
    {
      "type": "section",
      "text": {
        "type": "plain_text",
        "text": "${message}"
      }
    }
  ]
}
EOF
}

function notify() {
  if [ -n "$WEBHOOK_URL" ]; then
    local message=$@
    curl -i -H "Content-type: application/json" \
      -s -S -X POST -d "$(generate_payload ${message})" ${WEBHOOK_URL}
  fi
}

function make_pdsh_groups() {
  rm -f orderer.group peer.group ca.group client.group
  for i in `seq 0 \`expr $ORDERER_COUNT - 1\``; do
    echo orderer${i}.${DOMAIN} >> orderer.group
  done
  for org in `seq $ORG_COUNT`; do
    echo ca-org${org}.${DOMAIN} >> ca.group
    for i in `seq 0 \`expr $PEER_COUNT - 1\``; do
      echo peer${i}-org${org}.${DOMAIN} >> peer.group
    done
  done
  if [ -n "$CLIENT_COUNT" ]; then
    for client in `seq $CLIENT_COUNT`; do
      echo client${client}.${DOMAIN} >> client.group
    done
  fi
}

function setup_crypto_config() {
  rm -rf /tmp/hfc-*
  $CONFIG_DIR/generate_config.sh $ORG_COUNT $PEER_COUNT $ORDERER_COUNT $block_size
  (cd $CONFIG_DIR; ./generate.sh)
  make_pdsh_groups
  cp -a $CONFIG_DIR ~/
  pdcp -r -g orderer.group,peer.group,ca.group $CONFIG_DIR ~/
  if [ -n "$CLIENT_COUNT" ]; then
    pdcp -r -g client.group $CONFIG_DIR ~/
  fi
}

function setup_to_use_caliper() {
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  nvm use lts/dubnium 
  export FABRIC_VERSION
  export FABRIC_CA_VERSION
}
