#!/bin/bash
# Set up error handling
set -e

# Define variables
CHANNEL_NAME="mychannel"
OUTPUT_PATH="/artifacts"
FABRIC_CFG_PATH="/configtx"

# Set up logging
log_info() {
    echo "[INFO] $1"
}
log_error() {
    echo "[ERROR] $1" >&2
}

# Check for required tools
if ! command -v configtxgen &> /dev/null; then
    log_error "configtxgen is not installed. Please install it and try again."
    exit 1
fi

# Create necessary directories
create_directories() {
    log_info "Creating output directory"
    mkdir -p $OUTPUT_PATH
}

# Generate genesis block
generate_genesis_block() {
    log_info "Generating genesis block"
    configtxgen -profile SystemChannel -channelID system-channel -outputBlock $OUTPUT_PATH/genesis.block
}

# Generate channel creation transaction
generate_channel_tx() {
    log_info "Generating channel creation transaction"
    configtxgen -profile ChannelUsingRaft -outputCreateChannelTx $OUTPUT_PATH/channel.tx -channelID $CHANNEL_NAME
}

# Generate anchor peer updates
generate_anchor_peer_updates() {
    log_info "Generating anchor peer update for Org1"
    configtxgen -profile ChannelUsingRaft -outputAnchorPeersUpdate $OUTPUT_PATH/Org1MSPanchors.tx -channelID $CHANNEL_NAME -asOrg Org1MSP
    
    log_info "Generating anchor peer update for Org2"
    configtxgen -profile ChannelUsingRaft -outputAnchorPeersUpdate $OUTPUT_PATH/Org2MSPanchors.tx -channelID $CHANNEL_NAME -asOrg Org2MSP
}

# Main execution
create_directories
generate_genesis_block
generate_channel_tx
generate_anchor_peer_updates

log_info "Artifact generation completed successfully"
