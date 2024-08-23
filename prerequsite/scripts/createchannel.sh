#!/bin/bash
set -e

# Set environment variables
export CHANNEL_NAME=mychannel
export ORDERER_ADDRESS=orderer:7050
export ORDERER_CA=/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt
export FABRIC_CFG_PATH=/configtx

# Function to set peer environment variables
set_peer_env() {
    export CORE_PEER_LOCALMSPID=$1
    export CORE_PEER_MSPCONFIGPATH=/organizations/peerOrganizations/$2/users/Admin@$2/msp
    export CORE_PEER_TLS_ROOTCERT_FILE=/organizations/peerOrganizations/$2/peers/$3/tls/ca.crt
    export CORE_PEER_ADDRESS=$4:7051
    export CORE_PEER_TLS_ENABLED=true
}

# Ensure channel-artifacts directory exists
mkdir -p /channel-artifacts

# Generate channel configuration transaction
configtxgen -profile ChannelUsingRaft -outputCreateChannelTx /channel-artifacts/$CHANNEL_NAME.tx -channelID $CHANNEL_NAME

# Set environment for Org1's first peer
set_peer_env Org1MSP org1.example.com peer1.org1.example.com peer1-org1-example-com

# Create the channel
peer channel create -o $ORDERER_ADDRESS -c $CHANNEL_NAME -f /channel-artifacts/$CHANNEL_NAME.tx \
    --outputBlock /channel-artifacts/${CHANNEL_NAME}.block --tls --cafile $ORDERER_CA

echo "Channel $CHANNEL_NAME has been created"

# Function to join peer to channel
join_channel() {
    set_peer_env $1 $2 $3 $4
    peer channel join -b /channel-artifacts/${CHANNEL_NAME}.block
    echo "Peer $3 has joined the channel $CHANNEL_NAME"
}

# Join peers to the channel
join_channel Org1MSP org1.example.com peer1.org1.example.com peer1-org1-example-com
join_channel Org1MSP org1.example.com peer2.org1.example.com peer2-org1-example-com
join_channel Org2MSP org2.example.com peer1.org2.example.com peer1-org2-example-com
join_channel Org2MSP org2.example.com peer2.org2.example.com peer2-org2-example-com

# Update anchor peers
update_anchor_peers() {
    set_peer_env $1 $2 $3 $4
    peer channel update -o $ORDERER_ADDRESS -c $CHANNEL_NAME -f /channel-artifacts/${1}anchors.tx \
        --tls --cafile $ORDERER_CA
    echo "Anchor peers updated for $1"
}

update_anchor_peers Org1MSP org1.example.com peer1.org1.example.com peer1-org1-example-com
update_anchor_peers Org2MSP org2.example.com peer1.org2.example.com peer1-org2-example-com

echo "Channel setup and peer joining completed."
