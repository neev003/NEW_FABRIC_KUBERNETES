#!/bin/bash
set -e

# Set environment variables (make sure these match your deployment environment)
export CHANNEL_NAME=mychannel
export ORDERER_ADDRESS=orderer:7050
export ORDERER_CA=/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt
export CHAINCODE_NAME=mycc

# Function to set peer environment variables
set_peer_env() {
    export CORE_PEER_LOCALMSPID=$1
    export CORE_PEER_MSPCONFIGPATH=/organizations/peerOrganizations/$2/users/Admin@$2/msp
    export CORE_PEER_TLS_ROOTCERT_FILE=/organizations/peerOrganizations/$2/peers/$3/tls/ca.crt
    export CORE_PEER_ADDRESS=$4:7051
    export CORE_PEER_TLS_ENABLED=true
}

# Set environment to Org1's first peer
set_peer_env Org1MSP org1.example.com peer1.org1.example.com peer1-org1-example-com

# Function to invoke chaincode
invoke_chaincode() {
    echo "Invoking chaincode function: $1"
    peer chaincode invoke -o $ORDERER_ADDRESS \
        --tls --cafile $ORDERER_CA \
        -C $CHANNEL_NAME -n $CHAINCODE_NAME \
        --peerAddresses peer1-org1-example-com:7051 \
        --tlsRootCertFiles /organizations/peerOrganizations/org1.example.com/peers/peer1.org1.example.com/tls/ca.crt \
        --peerAddresses peer1-org2-example-com:7051 \
        --tlsRootCertFiles /organizations/peerOrganizations/org2.example.com/peers/peer1.org2.example.com/tls/ca.crt \
        -c "${2}" \
        --waitForEvent
}

# Function to query chaincode
query_chaincode() {
    echo "Querying chaincode function: $1"
    peer chaincode query -C $CHANNEL_NAME -n $CHAINCODE_NAME -c "${2}"
}

# Example invocations (modify these according to your chaincode functions)
invoke_chaincode "CreateAsset" '{"function":"CreateAsset","Args":["asset1", "blue", "5", "tom", "10"]}'
query_chaincode "ReadAsset" '{"function":"ReadAsset","Args":["asset1"]}'

echo "Chaincode invocation completed."
