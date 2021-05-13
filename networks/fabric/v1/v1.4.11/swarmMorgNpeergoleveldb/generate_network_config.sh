#!/bin/bash
#
# Generate network config with specified number of organizations, peers
# and orderers

WorkingDirectory=$(dirname $0)
NumberOfOrganizations=$1
NumberOfPeers=$2
NumberOfOrderers=$3
Domain=$4
Output=fabric.yaml

function usage() {
  cat << END
Usage: $0 numberOfOrganizations numberOfPeers numberOfOrderers domain
Description:
  Generate network config with specified number of organizations, peers
  and orderers. Also, you need to specify the domain name to access
  the peers, orderers and CAs.
END
}

function append_header_section() {
  cat - << END >> $WorkingDirectory/$Output
name: Fabric
version: "1.0"
mutual-tls: false

caliper:
  blockchain: fabric
  command:
    start: echo
    end: echo

info:
  Version: 1.4.11
  Size: ${NumberOfOrganizations} Orgs with ${NumberOfPeers} Peer and ${NumberOfOrderers} Orderers
  Orderer: Raft,
  Distribution: Swarm
  StateDB: GoLevelDB

END
}

function append_client_section() {
  local organization_number=$1
  cat - << END >> $WorkingDirectory/$Output
  client0.org${organization_number}.example.com:
    client:
      organization: Org${organization_number}
      credentialStore:
        path: /tmp/hfc-kvs/org${organization_number}
        cryptoStore:
          path: /tmp/hfc-cvs/org${organization_number}
      clientPrivateKey:
        path: networks/fabric/config_swarm_raft/crypto-config/peerOrganizations/org${organization_number}.example.com/users/User1@org${organization_number}.example.com/msp/keystore/key.pem
      clientSignedCert:
        path: networks/fabric/config_swarm_raft/crypto-config/peerOrganizations/org${organization_number}.example.com/users/User1@org${organization_number}.example.com/msp/signcerts/User1@org${organization_number}.example.com-cert.pem

END
}

function append_channel_header_section() {
  cat - << END >> $WorkingDirectory/$Output
channels:
  mychannel:
    configBinary: networks/fabric/config_swarm_raft/mychannel.tx
    created: false
    orderers:
END
  for orderer_number in $(seq 0 $(expr $NumberOfOrderers - 1)); do
    echo "    - orderer$orderer_number.example.com" >> $WorkingDirectory/$Output
  done
  echo "    peers:" >> $WorkingDirectory/$Output
}

function append_chaincode_section() {
  cat - << END >> $WorkingDirectory/$Output
    chaincodes:
    - id: simple
      version: v0
      language: golang
      path: fabric/scenario/simple/go
    - id: smallbank
      version: v0
      language: golang
      path: fabric/scenario/smallbank/go

END
}

function append_org_section() {
  local organization_number=$1
  cat - << END >> $WorkingDirectory/$Output
  Org${organization_number}:
    mspid: Org${organization_number}MSP
    peers:
END
  for peer_number in $(seq 0 $(expr $NumberOfPeers - 1)); do
    echo "    - peer${peer_number}.org${organization_number}.example.com" >> $WorkingDirectory/$Output
  done
  cat - << END >> $WorkingDirectory/$Output
    certificateAuthorities:
    - ca.org${organization_number}.example.com
    adminPrivateKey:
      path: networks/fabric/config_swarm_raft/crypto-config/peerOrganizations/org${organization_number}.example.com/users/Admin@org${organization_number}.example.com/msp/keystore/key.pem
    signedCert:
      path: networks/fabric/config_swarm_raft/crypto-config/peerOrganizations/org${organization_number}.example.com/users/Admin@org${organization_number}.example.com/msp/signcerts/Admin@org${organization_number}.example.com-cert.pem

END
}

function append_orderer_section() {
  echo "orderers:" >> $WorkingDirectory/$Output
  for orderer_number in $(seq 0 $(expr $NumberOfOrderers - 1)); do
    local endpoint_port=`expr ${orderer_number} + 7`050
    cat - << END >> $WorkingDirectory/$Output
  orderer${orderer_number}.example.com:
    url: grpcs://orderer${orderer_number}.${Domain}:${endpoint_port}
    grpcOptions:
      ssl-target-name-override: orderer${orderer_number}.example.com
    tlsCACerts:
        path: networks/fabric/config_swarm_raft/crypto-config/ordererOrganizations/example.com/orderers/orderer${orderer_number}.example.com/msp/tlscacerts/tlsca.example.com-cert.pem
END
  done
  echo "" >> $WorkingDirectory/$Output
}

function append_peer_section() {
  local organization_number=$1
  local peer_number=$2
  local endpoint_port=${organization_number}${peer_number}51
  cat - << END >> $WorkingDirectory/$Output
  peer${peer_number}.org${organization_number}.example.com:
    url: grpcs://peer${peer_number}-org${organization_number}.${Domain}:${endpoint_port}
    grpcOptions:
      ssl-target-name-override: peer${peer_number}.org${organization_number}.example.com
      grpc.keepalive_time_ms: 600000
    tlsCACerts:
      path: networks/fabric/config_swarm_raft/crypto-config/peerOrganizations/org${organization_number}.example.com/peers/peer${peer_number}.org${organization_number}.example.com/msp/tlscacerts/tlsca.org${organization_number}.example.com-cert.pem
   
END
}

function append_ca_section() {
  local organization_number=$1
  local port=${organization_number}054
  cat - << END >> $WorkingDirectory/$Output
  ca.org${organization_number}.example.com:
    url: https://ca-org${organization_number}.${Domain}:${port}
    httpOptions:
      verify: false
    tlsCACerts:
      path: networks/fabric/config_swarm_raft/crypto-config/peerOrganizations/org${organization_number}.example.com/tlsca/tlsca.org${organization_number}.example.com-cert.pem
    registrar:
    - enrollId: admin
      enrollSecret: adminpw

END
}

if [ $# != 4 ]; then
  usage
  exit 1
fi

rm -f $WorkingDirectory/$Output
append_header_section

echo "clients:" >> $WorkingDirectory/$Output
for i in $(seq $NumberOfOrganizations); do
  append_client_section $i
done

append_channel_header_section
for i in $(seq $NumberOfOrganizations); do
  for j in $(seq 0 $(expr $NumberOfPeers - 1)); do
    cat - << END >> $WorkingDirectory/$Output
      peer${j}.org${i}.example.com:
        eventSource: true
END
  done
done
append_chaincode_section

echo "organizations:" >> $WorkingDirectory/$Output
for i in $(seq $NumberOfOrganizations); do
  append_org_section $i
done
append_orderer_section

echo "peers:" >> $WorkingDirectory/$Output
for i in $(seq $NumberOfOrganizations); do
  for j in $(seq 0 $(expr $NumberOfPeers - 1)); do
    append_peer_section $i $j
  done
done

echo "certificateAuthorities:" >> $WorkingDirectory/$Output
for i in $(seq $NumberOfOrganizations); do
  append_ca_section $i
done
