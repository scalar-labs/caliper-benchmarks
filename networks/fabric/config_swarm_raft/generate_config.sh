#!/bin/bash
#
# Generate configtx and crypto-config files with specified number of
# organizations, peer, orderers and block size.

WorkingDirectory=$(dirname $0)
NumberOfOrganizations=$1
NumberOfPeers=$2
NumberOfOrderers=$3
BlockSize=$4
OutputConfigTx=configtx.yaml
OutputCryptoConfig=crypto-config.yaml

function usage() {
  cat << END
Usage: $0 numberOfOrganizations numberOfPeers numberOfOrderers blockSize
Description:
  Generate configtx and crypto-config files with specified number of
  organizations, peer, orderers and block size.
END
}

function append_header_section() {
  cat - << END >> $WorkingDirectory/$OutputConfigTx
---

Organizations:
- &OrdererOrg
    Name: OrdererMSP
    ID: OrdererMSP
    MSPDir: crypto-config/ordererOrganizations/example.com/msp
    AdminPrincipal: Role.MEMBER

END
}

function append_org_section() {
  local organization_number=$1
  cat - << END >> $WorkingDirectory/$OutputConfigTx
- &Org${organization_number}
    Name: Org${organization_number}MSP
    ID: Org${organization_number}MSP
    MSPDir: crypto-config/peerOrganizations/org${organization_number}.example.com/msp
    AdminPrincipal: Role.ADMIN
    AnchorPeers:
END
  for peer_number in $(seq 0 $(expr $NumberOfPeers - 1)); do
    cat - << END >> $WorkingDirectory/$OutputConfigTx
    - Host: peer${peer_number}-org${organization_number}
      Port: 7051
END
  done
  echo "" >> $WorkingDirectory/$OutputConfigTx
}

function append_orderer_section() {
  cat - << END >> $WorkingDirectory/$OutputConfigTx
Orderer: &OrdererDefaults
    OrdererType: etcdraft
    Addresses:
END
  for orderer_number in $(seq 0 $(expr $NumberOfOrderers - 1)); do
    echo "    - orderer$orderer_number:7050" >> $WorkingDirectory/$OutputConfigTx
  done
  cat - << END >> $WorkingDirectory/$OutputConfigTx
    BatchTimeout: 500ms
    BatchSize:
        MaxMessageCount: ${BlockSize}
        AbsoluteMaxBytes: 128 MB
        PreferredMaxBytes: 128 MB
    MaxChannels: 0
    EtcdRaft:
        Consenters:
END
  for orderer_number in $(seq 0 $(expr $NumberOfOrderers - 1)); do
    cat - << END >> $WorkingDirectory/$OutputConfigTx
        - Host: orderer${orderer_number}
          Port: 7050
          ClientTLSCert: crypto-config/ordererOrganizations/example.com/orderers/orderer${orderer_number}.example.com/tls/server.crt
          ServerTLSCert: crypto-config/ordererOrganizations/example.com/orderers/orderer${orderer_number}.example.com/tls/server.crt
END
  done
  echo "    Organizations:" >> $WorkingDirectory/$OutputConfigTx
  echo "" >> $WorkingDirectory/$OutputConfigTx
}

function append_profile_section() {
  cat - << END >> $WorkingDirectory/$OutputConfigTx
Application: &ApplicationDefaults
    Organizations:

Profiles:
    OrdererGenesis:
        Orderer:
            <<: *OrdererDefaults
            Organizations:
            - *OrdererOrg
        Consortiums:
            SampleConsortium:
                Organizations:
END
  for organization_number in $(seq $NumberOfOrganizations); do
    echo "                - *Org$organization_number" >> $WorkingDirectory/$OutputConfigTx
  done
  cat - << END >> $WorkingDirectory/$OutputConfigTx
    ChannelConfig:
        Consortium: SampleConsortium
        Application:
            <<: *ApplicationDefaults
            Organizations:
END
  for organization_number in $(seq $NumberOfOrganizations); do
    echo "            - *Org$organization_number" >> $WorkingDirectory/$OutputConfigTx
  done
}

function generate_crypto_config() {
  cat - << END >> $WorkingDirectory/$OutputCryptoConfig
OrdererOrgs:
- Name: Orderer
  Domain: example.com
  Template:
      Count: ${NumberOfOrderers}

PeerOrgs:
END

  for organization_number in $(seq $NumberOfOrganizations); do
    cat - << END >> $WorkingDirectory/$OutputCryptoConfig
- Name: Org${organization_number}
  Domain: org${organization_number}.example.com
  Template:
      Count: ${NumberOfPeers}
  Users:
      Count: 1

END
  done
}

if [ $# != 4 ]; then
  usage
  exit 1
fi

rm -f $WorkingDirectory/$OutputConfigTx
rm -f $WorkingDirectory/$OutputCryptoConfig
append_header_section
for i in $(seq $NumberOfOrganizations); do
  append_org_section $i
done
append_orderer_section
append_profile_section
generate_crypto_config
