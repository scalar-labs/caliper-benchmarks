#!/bin/bash -x

ORG_COUNT=2
PEER_COUNT=6
ORDERER_COUNT=5
BLOCK_SIZE_PATTERN="10 50 256"
WEBHOOK_URL=
DOMAIN=large.internal.scalar-labs.com

FABRIC_VERSION=1.4.11
FABRIC_CA_VERSION=1.4.9

CALIPER_DIR=$HOME/caliper
CALIPER_BENCH_BASE_DIR=$HOME/caliper-benchmarks                              # Must be absolute path
CALIPER_BENCH_FABRIC_DIR=networks/fabric/v1/v1.4.11/swarmMorgNpeergoleveldb  # Relative from CALIPER_BENCH_BASE_DIR
CALIPER_BENCH_CONFIG=benchmarks/scenario/smallbank/config.yaml               # Relative from CALIPER_BENCH_BASE_DIR
CALIPER_BENCH_NETCONFIG=$CALIPER_BENCH_FABRIC_DIR/fabric.yaml                # Relative from CALIPER_BENCH_BASE_DIR
CONFIG_NAME=config_swarm_raft
CONFIG_DIR=$CALIPER_BENCH_BASE_DIR/networks/fabric/$CONFIG_NAME
CONFIGTX_FILE=$CONFIG_DIR/configtx.yaml
FABRIC_NETWORK_DIR=$CALIPER_BENCH_BASE_DIR/$CALIPER_BENCH_FABRIC_DIR
FABRIC_PEER_FS_DEV=/dev/nvme0n1

source ./benchmark-common.sh

export DSHGROUP_PATH=.
setup_to_use_caliper 

# Log directory preparation
name=benchmark-caliper-$(date '+%Y%m%d-%H%M%S')-${PEER_COUNT}peer${ORDERER_COUNT}orderer
log_dir=$CALIPER_BENCH_BASE_DIR/log/$name
mkdir -p $log_dir

# Fabric crypt-config preparation
rm -rf /tmp/hfc-*
$CONFIG_DIR/generate_config.sh $ORG_COUNT $PEER_COUNT $ORDERER_COUNT $block_size
(cd $CONFIG_DIR; ./generate.sh)
make_pdsh_groups
pdcp -r -g orderer.group,peer.group,ca.group $CONFIG_DIR ~/

for block_size in $BLOCK_SIZE_PATTERN; do
  log_file=${log_dir}/bs${block_size}.log
  $FABRIC_NETWORK_DIR/generate_network_config.sh $ORG_COUNT $PEER_COUNT $ORDERER_COUNT $DOMAIN
  $FABRIC_NETWORK_DIR/generate_docker_compose.sh $ORG_COUNT $PEER_COUNT $ORDERER_COUNT
  docker_compose_down       | tee -a $log_file
  sleep 3
  update_config $block_size | tee -a $log_file
  check_device              | tee -a $log_file
  init_volume               | tee -a $log_file
  docker_compose_up         | tee -a $log_file
  echo "Waiting for docker compose up ..."
  sleep 30
  setup_chaincode           | tee -a $log_file
  run $block_size $log_dir
  mv $CALIPER_BENCH_BASE_DIR/caliper.log $log_dir/caliper.${PEER_COUNT}peer${ORDERER_COUNT}orderer.bs${block_size}.log
done
cp $CALIPER_BENCH_BASE_DIR/$CALIPER_BENCH_CONFIG $log_dir/
notify "Benchmark done. See ${log_dir}"
