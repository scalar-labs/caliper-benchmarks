
# Benchmark Scripts for Hyperledger Fabric

We have the following two scripts to run a benchmark for Hyperledger Fabric on multi-node environments. The first one is fully using Caliper framework and the second one is Java-based smallbank benchmark that only uses initialization and install function of Caliper framework.

- benchmark-caliper.sh
- benchmark-java.sh

## Requirements

- Docker (latest recommended)
- Docker Compose (latest recommended)
- pdsh
- pdsh-mod-dshgroup

## Common Setup

Prepare hosts to use benchmark with hostname resolution with following rules. Note that peer and orderer must be start with 0

```
client1.yourdomain 10.x.x.x (only for Java)
client2.yourdomain 10.x.x.x (only for Java)
...
ca-org1.yourdomain 10.x.x.x
ca-org2.yourdomain 10.x.x.x
...
peer0-org1.yourdomain 10.x.x.x
peer1-org1.yourdomain 10.x.x.x
...
orederer0.yourdomain 10.x.x.x
orederer1.yourdomain 10.x.x.x
...
```

Prepare Docker Swarm cluster and add labels for each node based on their roles. Example setup is as follows.

```
docker network create --attachable --driver overlay caliper-nw
docker swarm init
pdsh -w all_hosts docker swarm join --token XXX 10.x.x.x:2377
docker node update --label-add orderer0=true orederer0.yourdomain
docker node update --label-add orderer1=true orederer1.yourdomain
... repeat for all hosts with the label 'hostname=true'
```

## Usage: Caliper

Configure following parameters and just run benchmark-caliper.sh.

```sh
ORG_COUNT=2                    # Number of organizations
PEER_COUNT=3                   # Number of peers
ORDERER_COUNT=3                # Number of orderers
BLOCK_SIZE_PATTERN="10 50 256" # Number of transactions per block
WEBHOOK_URL=                   # Webhook URL for notification on Slack (not mandatory)
DOMAIN=yourdomain              # Domain name (e.g., sample.org)
```

## Usage: Java

Build smallbank Java benchmark on each client hosts.

```
cd $HOME
git clone https://github.com/scalar-labs/caliper-benchmarks.git
git checkout scalardl
cd benchmarks/java
./gradlew installDist
```

Configure following parameters and just run benchmark-java.sh.

```sh
CLIENT_COUNT=2                 # Number of clients
ORG_COUNT=2                    # Number of organizations
PEER_COUNT=3                   # Number of peers
ORDERER_COUNT=3                # Number of orderers
THREAD_PATTERN="4 8 16"        # Number of threads per client
BLOCK_SIZE_PATTERN="10 50 256" # Number of transactions per block
WEBHOOK_URL=                   # Webhook URL for notification on Slack (not mandatory)
DOMAIN=yourdomain              # Domain name (e.g., sample.org)
NUM_ACCOUNTS=1000000           # Number of smallbank accounts to load
NUM_TRIAL=3                    # Number of trials
RAMP_UP_TIME=10                # Ramp-up time (seconds)
DURATION=60                    # Benchmark duration of single run (seconds)
SLEEP_TIME=30                  # Sleep time after single run (seconds)
```
