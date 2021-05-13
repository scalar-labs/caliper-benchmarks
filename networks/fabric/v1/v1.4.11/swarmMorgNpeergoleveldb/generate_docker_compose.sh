#!/bin/bash
#
# Generate docker-compose.yaml with specified number of organizations, peers
# and orderers

OUTPUT=docker-compose.yaml
TEMPLATE=docker-compose.template

WorkingDirectory=$(dirname $0)
NumberOfOrganizations=$1
NumberOfPeers=$2
NumberOfOrderers=$3

##############################################################################
# Show usage
# Globals:
#   None
# Arguments:
#   None
# Returns:
#   None
##############################################################################
function usage() {
  cat << END
Usage: $0 numberOfOrganizations numberOfPeers numberOfOrderers
Description:
  Generate docker-compose.yaml with specified number of organizations, peers,
  and orderers.
END
}

##############################################################################
# Append header section
# Globals:
#   OUTPUT
# Arguments:
#   None
# Returns:
#   None
##############################################################################
function append_header_section() {
  cat - << END >> $WorkingDirectory/$OUTPUT
version: '3'

networks:
  caliper-nw:
    external: true

services:
END
}

##############################################################################
# Append a orderer section with specified orderer# for the output
# Globals:
#   OUTPUT
# Arguments:
#   orderer_number
# Returns:
#   None
##############################################################################
function append_orderer_section() {
  local orderer_number=$1
  local endpoint_port=`expr ${orderer_number} + 7`050
  cat - << END >> $WorkingDirectory/$OUTPUT

  orderer${orderer_number}:
    image: hyperledger/fabric-orderer:${FABRIC_VERSION}
    environment:
      - FABRIC_LOGGING_SPEC=grpc=info:info
      - ORDERER_GENERAL_LISTENADDRESS=0.0.0.0
      - ORDERER_GENERAL_GENESISMETHOD=file
      - ORDERER_GENERAL_GENESISFILE=/etc/hyperledger/configtx/genesis.block
      - ORDERER_GENERAL_LOCALMSPID=OrdererMSP
      - ORDERER_GENERAL_LOCALMSPDIR=/etc/hyperledger/msp/orderer/msp
      - ORDERER_GENERAL_TLS_ENABLED=true
      - ORDERER_GENERAL_TLS_PRIVATEKEY=/etc/hyperledger/msp/orderer/tls/server.key
      - ORDERER_GENERAL_TLS_CERTIFICATE=/etc/hyperledger/msp/orderer/tls/server.crt
      - ORDERER_GENERAL_TLS_ROOTCAS=[/etc/hyperledger/msp/orderer/tls/ca.crt]
      - ORDERER_GENERAL_CLUSTER_CLIENTCERTIFICATE=/etc/hyperledger/msp/orderer/tls/server.crt
      - ORDERER_GENERAL_CLUSTER_CLIENTPRIVATEKEY=/etc/hyperledger/msp/orderer/tls/server.key
    working_dir: /opt/gopath/src/github.com/hyperledger/fabric
    command: orderer
    ports:
      - ${endpoint_port}:7050
    volumes:
      - /mnt/:/var/hyperledger/production/
      - /home/centos/config_swarm_raft/:/etc/hyperledger/configtx
      - /home/centos/config_swarm_raft/crypto-config/ordererOrganizations/example.com/orderers/orderer${orderer_number}.example.com/:/etc/hyperledger/msp/orderer
    depends_on:
      - ca.org1.example.com
      - ca.org2.example.com
    networks:
      - caliper-nw
    deploy:
      replicas: 1
      placement:
        constraints:
          - node.labels.orderer${orderer_number}==true
END
}

##############################################################################
# Append a peer section with specified organization# and peer# for the output
# Globals:
#   OUTPUT
# Arguments:
#   organization_number
#   peer_number
# Returns:
#   None
##############################################################################
function append_peer_section() {
  local organization_number=$1
  local peer_number=$2
  local endpoint_port=${organization_number}${peer_number}51
  local eventhub_port=${organization_number}${peer_number}53
  cat - << END >> $WorkingDirectory/$OUTPUT

  peer${peer_number}-org${organization_number}:
    image: hyperledger/fabric-peer:${FABRIC_VERSION}
    environment:
      - FABRIC_LOGGING_SPEC=grpc=info:info
      - CORE_CHAINCODE_LOGGING_LEVEL=INFO
      - CORE_CHAINCODE_LOGGING_SHIM=INFO
      - CORE_CHAINCODE_EXECUTETIMEOUT=30s
      - CORE_CHAINCODE_STARTUPTIMEOUT=600s
      - CORE_CHAINCODE_BUILDER=hyperledger/fabric-ccenv:1.4
      - CORE_VM_ENDPOINT=unix:///host/var/run/docker.sock
      - CORE_PEER_ID=peer${peer_number}.org${organization_number}.example.com
      - CORE_PEER_ENDORSER_ENABLED=true
      - CORE_PEER_LOCALMSPID=Org${organization_number}MSP
      - CORE_PEER_MSPCONFIGPATH=/etc/hyperledger/msp/peer/msp/
      - CORE_PEER_ADDRESS=peer${peer_number}-org${organization_number}:7051
      - CORE_PEER_CHAINCODELISTENADDRESS=0.0.0.0:7052
      - CORE_PEER_GOSSIP_USELEADERELECTION=true
      - CORE_PEER_GOSSIP_ORGLEADER=false
      - CORE_PEER_GOSSIP_EXTERNALENDPOINT=peer${peer_number}-org${organization_number}:7051
      - CORE_PEER_TLS_ENABLED=true
      - CORE_PEER_TLS_KEY_FILE=/etc/hyperledger/msp/peer/tls/server.key
      - CORE_PEER_TLS_CERT_FILE=/etc/hyperledger/msp/peer/tls/server.crt
      - CORE_PEER_TLS_ROOTCERT_FILE=/etc/hyperledger/msp/peer/tls/ca.crt
      - CORE_VM_DOCKER_HOSTCONFIG_NETWORKMODE=caliper-nw
    working_dir: /opt/gopath/src/github.com/hyperledger/fabric
    command: peer node start
    ports:
      - ${endpoint_port}:7051
      - ${eventhub_port}:7053
    volumes:
      - /var/run/:/host/var/run/
      - /mnt/:/var/hyperledger/production/
      - /home/centos/config_swarm_raft/crypto-config/peerOrganizations/org${organization_number}.example.com/peers/peer${peer_number}.org${organization_number}.example.com/:/etc/hyperledger/msp/peer
    networks:
      - caliper-nw
    deploy:
      replicas: 1
      placement:
        constraints:
          - node.labels.peer${peer_number}-org${organization_number}==true
    depends_on:
END
  for orderer_number in $(seq 0 $(expr $NumberOfOrderers - 1)); do
    echo "      - orderer$orderer_number" >> $WorkingDirectory/$OUTPUT
  done
}

##############################################################################
# Append a CA section with specified organization# for the output
# Globals:
#   OUTPUT
# Arguments:
#   organization_number
# Returns:
#   None
##############################################################################
function append_ca_section() {
  local organization_number=$1
  local port=${organization_number}${peer_number}054
  cat - << END >> $WorkingDirectory/$OUTPUT

  ca-org${organization_number}:
    image: hyperledger/fabric-ca:${FABRIC_CA_VERSION}
    environment:
      - FABRIC_CA_HOME=/etc/hyperledger/fabric-ca-server
      - FABRIC_CA_SERVER_CA_NAME=ca.org${organization_number}.example.com
      - FABRIC_CA_SERVER_CA_CERTFILE=/etc/hyperledger/fabric-ca-server-config/ca.org${organization_number}.example.com-cert.pem
      - FABRIC_CA_SERVER_CA_KEYFILE=/etc/hyperledger/fabric-ca-server-config/key.pem
      - FABRIC_CA_SERVER_TLS_ENABLED=true
      - FABRIC_CA_SERVER_TLS_CERTFILE=/etc/hyperledger/fabric-ca-server-tls/tlsca.org${organization_number}.example.com-cert.pem
      - FABRIC_CA_SERVER_TLS_KEYFILE=/etc/hyperledger/fabric-ca-server-tls/key.pem
    ports:
      - ${port}:7054
    command: sh -c 'fabric-ca-server start --ca.certfile /etc/hyperledger/fabric-ca-server-config/ca.org${organization_number}.example.com-cert.pem --ca.keyfile /etc/hyperledger/fabric-ca-server-config/key.pem -b admin:adminpw -d'
    volumes:
      - /home/centos/config_swarm_raft/crypto-config/peerOrganizations/org${organization_number}.example.com/ca/:/etc/hyperledger/fabric-ca-server-config
      - /home/centos/config_swarm_raft/crypto-config/peerOrganizations/org${organization_number}.example.com/tlsca/:/etc/hyperledger/fabric-ca-server-tls
    networks:
      - caliper-nw
    deploy:
      replicas: 1
      placement:
        constraints:
          - node.labels.ca-org${organization_number}==true
END
}

if [ $# != 3 ]; then
  usage
  exit 1
fi

rm -f $WorkingDirectory/$OUTPUT

append_header_section

for i in $(seq 0 $(expr $NumberOfOrderers - 1)); do
  append_orderer_section $i
done

for i in $(seq $NumberOfOrganizations); do
  for j in $(seq 0 $(expr $NumberOfPeers - 1)); do
    append_peer_section $i $j
  done
  append_ca_section $i
done
