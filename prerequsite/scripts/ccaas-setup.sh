#!/bin/bash
set -e

# Set environment variables
export CHANNEL_NAME=mychannel
export CHAINCODE_NAME=mycc
export ORDERER_CA=/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt
export ORDERER_ADDRESS=orderer:7050

# Function to set peer environment variables
set_peer_env() {
    export CORE_PEER_LOCALMSPID=$1
    export CORE_PEER_MSPCONFIGPATH=/organizations/peerOrganizations/$2/users/Admin@$2/msp
    export CORE_PEER_TLS_ROOTCERT_FILE=/organizations/peerOrganizations/$2/peers/$3/tls/ca.crt
    export CORE_PEER_ADDRESS=$4:7051
    export CORE_PEER_TLS_ENABLED=true
}

# Invoke chaincode
invoke_chaincode() {
    set_peer_env Org1MSP org1.example.com peer1.org1.example.com peer1-org1-example-com
    peer chaincode invoke -o ${ORDERER_ADDRESS} --ordererTLSHostnameOverride orderer.example.com --tls --cafile ${ORDERER_CA} --channelID ${CHANNEL_NAME} --name ${CHAINCODE_NAME} -c '{"function":"YourFunction","Args":["arg1", "arg2"]}' --peerAddresses peer1-org1-example-com:7051 --tlsRootCertFiles /organizations/peerOrganizations/org1.example.com/peers/peer1.org1.example.com/tls/ca.crt --peerAddresses peer1-org2-example-com:7051 --tlsRootCertFiles /organizations/peerOrganizations/org2.example.com/peers/peer1.org2.example.com/tls/ca.crt
    echo "Chaincode invoked successfully"
}

# Main execution
invoke_chaincode

