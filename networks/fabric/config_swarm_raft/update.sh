#!/usr/bin/env bash

: "${FABRIC_VERSION:=1.4.11}"
: "${FABRIC_CA_VERSION:=1.4.9}"

# if the binaries are not available, download them
if [[ ! -d "bin" ]]; then
  curl -sSL http://bit.ly/2ysbOFE | bash -s -- ${FABRIC_VERSION} ${FABRIC_CA_VERSION} 0.4.14 -ds
fi

rm -f ./genesis.block
rm -f ./mychannel.tx

./bin/configtxgen -profile OrdererGenesis -outputBlock genesis.block -channelID syschannel
./bin/configtxgen -profile ChannelConfig -outputCreateChannelTx mychannel.tx -channelID mychannel

