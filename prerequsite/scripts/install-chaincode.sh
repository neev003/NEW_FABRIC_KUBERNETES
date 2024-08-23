#!/bin/bash
set -e

# Set environment variables
export CHANNEL_NAME=mychannel
export ORDERER_ADDRESS=orderer:7050
export ORDERER_CA=/organizations/ordererOrganizations/example.com/orderers/orderer.example.com/tls/ca.crt
export FABRIC_CFG_PATH=/configtx
export CHAINCODE_NAME=mycc
export CHAINCODE_VERSION=1.0
export CHAINCODE_SEQUENCE=1
export CHAINCODE_SERVER_ADDRESS=chaincode-service:7052
export CORE_PEER_EXTERNALCHAINCODE=chaincode-service:7052

# Function to set peer environment variables
set_peer_env() {
    export CORE_PEER_LOCALMSPID=$1
    export CORE_PEER_MSPCONFIGPATH=/organizations/peerOrganizations/$2/users/Admin@$2/msp
    export CORE_PEER_TLS_ROOTCERT_FILE=/organizations/peerOrganizations/$2/peers/$3/tls/ca.crt
    export CORE_PEER_ADDRESS=$4:7051
    export CORE_PEER_TLS_ENABLED=true
}

cd chaincode
tar cfz code.tar.gz connection.json 
tar cfz mycc.tgz metadata.json code.tar.gz

# Function to install chaincode on a peer
install_chaincode() {
    set_peer_env $1 $2 $3 $4
    
    echo "Installing chaincode on $1"

    peer lifecycle chaincode install mycc.tgz
    
    echo "Installed chaincode on $1"
    
    PACKAGE_ID=$(peer lifecycle chaincode queryinstalled | grep "${CHAINCODE_NAME}" | tail -n 1 | awk '{print $3}' | sed 's/,//')
    echo "PACKAGE_ID for $3: $PEER_PACKAGE_ID"
    
    # Store the package ID in a variable named after the peer
    eval "${3//./_}_PACKAGE_ID=$PEER_PACKAGE_ID"
}

# Install chaincode on each peer
install_chaincode Org1MSP org1.example.com peer1.org1.example.com peer1-org1-example-com
install_chaincode Org2MSP org2.example.com peer1.org2.example.com peer1-org2-example-com

# Get the package ID


# Function to approve chaincode for an org
approve_chaincode() {
    set_peer_env $1 $2 $3 $4
    
    echo "Approving chaincode for $1"

    peer lifecycle chaincode approveformyorg -o $ORDERER_ADDRESS \
        --channelID $CHANNEL_NAME --name $CHAINCODE_NAME --version $CHAINCODE_VERSION \
        --package-id $PACKAGE_ID --sequence $CHAINCODE_SEQUENCE \
        --tls --cafile $ORDERER_CA \
        --signature-policy "OR('Org1MSP.member','Org2MSP.member')" 
        
    echo "Approved chaincode for $1"
}

# Approve chaincode for each org
approve_chaincode Org1MSP org1.example.com peer1.org1.example.com peer1-org1-example-com
approve_chaincode Org2MSP org2.example.com peer1.org2.example.com peer1-org2-example-com

# Check commit readiness
set_peer_env Org1MSP org1.example.com peer1.org1.example.com peer1-org1-example-com
echo "commit readiness"
peer lifecycle chaincode checkcommitreadiness --channelID $CHANNEL_NAME \
    --name $CHAINCODE_NAME --version $CHAINCODE_VERSION --sequence $CHAINCODE_SEQUENCE \
    --tls --cafile $ORDERER_CA --output json \
    --signature-policy "OR('Org1MSP.member','Org2MSP.member')"
echo "commit readiness done"

# Commit the chaincode definition
peer lifecycle chaincode commit -o $ORDERER_ADDRESS \
    --channelID $CHANNEL_NAME --name $CHAINCODE_NAME --version $CHAINCODE_VERSION \
    --sequence $CHAINCODE_SEQUENCE --tls --cafile $ORDERER_CA \
    --peerAddresses peer1-org1-example-com:7051 \
    --tlsRootCertFiles /organizations/peerOrganizations/org1.example.com/peers/peer1.org1.example.com/tls/ca.crt \
    --peerAddresses peer1-org2-example-com:7051 \
    --tlsRootCertFiles /organizations/peerOrganizations/org2.example.com/peers/peer1.org2.example.com/tls/ca.crt \
    --signature-policy "OR('Org1MSP.member','Org2MSP.member')"

# Query committed chaincode
peer lifecycle chaincode querycommitted --channelID $CHANNEL_NAME \
    --name $CHAINCODE_NAME --cafile $ORDERER_CA

echo "Chaincode deployment completed for all organizations."



