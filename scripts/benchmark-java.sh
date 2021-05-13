#!/bin/bash -x

CLIENT_COUNT=2
ORG_COUNT=2
PEER_COUNT=3
ORDERER_COUNT=3
THREAD_PATTERN="2 4 8 16 32 64 128 192 256"
BLOCK_SIZE_PATTERN="10 50 256 1024"

NUM_ACCOUNTS=10000
NUM_TRIAL=1
RAMP_UP_TIME=1
DURATION=6
SLEEP_TIME=3
NUM_ACCOUNTS=1000000
NUM_TRIAL=5
RAMP_UP_TIME=10
DURATION=60
SLEEP_TIME=30
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

JAVA_BENCH_DIR=$CALIPER_BENCH_BASE_DIR/benchmarks/java
JAVA_BENCH_CONFIG=$JAVA_BENCH_DIR/connection.yaml
JAVA_BIN_LOADER=$JAVA_BENCH_DIR/build/install/java/bin/smallbank-loader
JAVA_BIN_BENCHMARK=$JAVA_BENCH_DIR/build/install/java/bin/smallbank-bench
JAVA_LOADER_NUM_THREADS=64

source ./benchmark-common.sh

function setup_data() {
  local num_accounts=$1
  $JAVA_BIN_LOADER \
    --network-config $JAVA_BENCH_CONFIG \
    --crypto-config ~/$CONFIG_NAME/crypto-config \
    --num-accounts $num_accounts --num-threads $JAVA_LOADER_NUM_THREADS \
    --commit-wait-policy NONE
}

function run() {
  local log_dir=$1
  local bs=$2
  for i in `seq $NUM_TRIAL`; do
    for t in $THREAD_PATTERN; do
      # ALL
      sleep $SLEEP_TIME
      pdsh -g client.group "(cd $CALIPER_BENCH_BASE_DIR; $JAVA_BIN_BENCHMARK --network-config $JAVA_BENCH_CONFIG --crypto-config ~/$CONFIG_NAME/crypto-config --num-accounts $NUM_ACCOUNTS --num-threads $t --commit-wait-policy NETWORK_SCOPE_ALLFORTX --ramp-up-time $RAMP_UP_TIME --duration $DURATION)" > $log_dir/bs${bs}_all_$t.out$i
      # ANY
      sleep $SLEEP_TIME
      pdsh -g client.group "(cd $CALIPER_BENCH_BASE_DIR; $JAVA_BIN_BENCHMARK --network-config $JAVA_BENCH_CONFIG --crypto-config ~/$CONFIG_NAME/crypto-config --num-accounts $NUM_ACCOUNTS --num-threads $t --commit-wait-policy NETWORK_SCOPE_ANYFORTX --ramp-up-time $RAMP_UP_TIME --duration $DURATION)" > $log_dir/bs${bs}_any_$t.out$i
    done
  done
}

export DSHGROUP_PATH=.
ulimit -u 8192

# Use caliper for chaincode setup
setup_to_use_caliper 

# Log directory preparation
name=benchmark-java-$(date '+%Y%m%d-%H%M%S')-${PEER_COUNT}peer${ORDERER_COUNT}orderer
log_dir=$CALIPER_BENCH_BASE_DIR/log/$name
mkdir -p $log_dir

# Fabric crypt-config generation and distribution
setup_crypto_config

for block_size in $BLOCK_SIZE_PATTERN; do
  log_file=${log_dir}/bs${block_size}.log
  load_log_file=${log_dir}/bs${block_size}_load.log
  $JAVA_BENCH_DIR/generate_java_config.sh $ORG_COUNT $PEER_COUNT $ORDERER_COUNT $DOMAIN
  pdcp -r -g client.group $JAVA_BENCH_CONFIG $JAVA_BENCH_CONFIG
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
  setup_data $NUM_ACCOUNTS  | tee -a $load_log_file
  while true; do wait_for_ready && break || sleep 1; done \
                            | tee -a $log_file
  run $log_dir $block_size
done
notify "Benchmark done. See ${log_dir}"
