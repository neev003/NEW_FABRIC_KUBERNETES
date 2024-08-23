#!/bin/bash

# Set up error handling and debugging
set -e
set -x

# Define variables
CA_SERVER="ca-org2:8054"
ORG_NAME="org2.example.com"
CA_NAME="ca-org2"
TLS_CERT_FILE="/ca-org2/tls-cert.pem"
PEER_NUMBER=${1:-0}
PEER_NAME="peer${PEER_NUMBER}"
PEER_SERVICE_NAME="${PEER_NAME}-org2-example-com"
ADMIN_NAME="org${PEER_NUMBER}admin"
USER_NAME="user${PEER_NUMBER}"

# Check for required tools
if ! command -v fabric-ca-client &> /dev/null; then
    echo "fabric-ca-client is not installed. Please install it and try again."
    exit 1
fi

# Set up logging
log_info() {
    echo "[INFO] $1"
}

log_error() {
    echo "[ERROR] $1" >&2
}

# Check if CA server is ready
check_ca_server() {
    local max_retries=5
    local retry_interval=5

    for i in $(seq 1 $max_retries); do
        if curl -k https://${CA_SERVER} &>/dev/null; then
            log_info "CA server is ready"
            return 0
        else
            log_info "Waiting for CA server to be ready... (attempt $i/$max_retries)"
            sleep $retry_interval
        fi
    done

    log_error "CA server did not become ready in time"
    return 1
}

# Check required files
check_required_files() {
    log_info "Current working directory: $(pwd)"
    log_info "Contents of current directory:"
    ls -la

    local files=(
        "$TLS_CERT_FILE"
    )

    for file in "${files[@]}"; do
        if [ ! -f "$file" ]; then
            log_error "Required file not found: $file"
            log_info "Listing contents of directory containing missing file:"
            ls -la "$(dirname "$file")"
            return 1
        fi
    done

    log_info "All required files are present"
    return 0
}

# Create necessary directories
create_directories() {
    log_info "Creating directories"
    mkdir -p /organizations/peerOrganizations/${ORG_NAME}/
}

# Enroll admin
enroll_admin() {
    log_info "Enrolling admin"
    export FABRIC_CA_CLIENT_HOME=/organizations/peerOrganizations/${ORG_NAME}
    fabric-ca-client enroll -u https://admin:adminpw@${CA_SERVER} --caname ${CA_NAME} --tls.certfiles ${TLS_CERT_FILE}
}

# Create MSP config file
create_msp_config() {
    log_info "Creating MSP config"
    echo 'NodeOUs:
  Enable: true
  ClientOUIdentifier:
    Certificate: cacerts/'${CA_NAME}'-'${CA_SERVER##*:}'-'${CA_NAME}'.pem
    OrganizationalUnitIdentifier: client
  PeerOUIdentifier:
    Certificate: cacerts/'${CA_NAME}'-'${CA_SERVER##*:}'-'${CA_NAME}'.pem
    OrganizationalUnitIdentifier: peer
  AdminOUIdentifier:
    Certificate: cacerts/'${CA_NAME}'-'${CA_SERVER##*:}'-'${CA_NAME}'.pem
    OrganizationalUnitIdentifier: admin
  OrdererOUIdentifier:
    Certificate: cacerts/'${CA_NAME}'-'${CA_SERVER##*:}'-'${CA_NAME}'.pem
    OrganizationalUnitIdentifier: orderer' > /organizations/peerOrganizations/${ORG_NAME}/msp/config.yaml
}

# Register peer, user, and admin if not already registered
register_identities() {
    log_info "Registering peer ${PEER_NAME}"
    if ! fabric-ca-client identity list --caname ${CA_NAME} --tls.certfiles ${TLS_CERT_FILE} | grep -q "${PEER_NAME}"; then
        fabric-ca-client register --caname ${CA_NAME} --id.name ${PEER_NAME} --id.secret peerpw --id.type peer --tls.certfiles ${TLS_CERT_FILE}
    else
        log_info "Peer ${PEER_NAME} already registered"
    fi

    log_info "Registering the user ${USER_NAME}"
    if ! fabric-ca-client identity list --caname ${CA_NAME} --tls.certfiles ${TLS_CERT_FILE} | grep -q "${USER_NAME}"; then
        fabric-ca-client register --caname ${CA_NAME} --id.name ${USER_NAME} --id.secret userpw --id.type client --tls.certfiles ${TLS_CERT_FILE}
    else
        log_info "User ${USER_NAME} already registered"
    fi

    log_info "Registering the org admin ${ADMIN_NAME}"
    if ! fabric-ca-client identity list --caname ${CA_NAME} --tls.certfiles ${TLS_CERT_FILE} | grep -q "${ADMIN_NAME}"; then
        fabric-ca-client register --caname ${CA_NAME} --id.name ${ADMIN_NAME} --id.secret orgadminpw --id.type admin --tls.certfiles ${TLS_CERT_FILE}
    else
        log_info "Admin ${ADMIN_NAME} already registered"
    fi
}

# Generate the peer MSP
generate_peer_msp() {
    log_info "Generating the peer MSP"
    fabric-ca-client enroll -u https://${PEER_NAME}:peerpw@${CA_SERVER} --caname ${CA_NAME} -M /organizations/peerOrganizations/${ORG_NAME}/peers/${PEER_NAME}.${ORG_NAME}/msp --csr.hosts ${PEER_SERVICE_NAME} --csr.hosts localhost --csr.hosts ${CA_NAME} --csr.hosts ${PEER_NAME} --tls.certfiles ${TLS_CERT_FILE}

    cp /organizations/peerOrganizations/${ORG_NAME}/msp/config.yaml /organizations/peerOrganizations/${ORG_NAME}/peers/${PEER_NAME}.${ORG_NAME}/msp/config.yaml
}

# Generate the peer TLS certificates
generate_peer_tls() {
    log_info "Generating the peer TLS certificates"
    fabric-ca-client enroll -u https://${PEER_NAME}:peerpw@${CA_SERVER} --caname ${CA_NAME} -M /organizations/peerOrganizations/${ORG_NAME}/peers/${PEER_NAME}.${ORG_NAME}/tls --enrollment.profile tls --csr.hosts ${PEER_SERVICE_NAME} --csr.hosts localhost --csr.hosts ${CA_NAME} --csr.hosts ${PEER_NAME} --tls.certfiles ${TLS_CERT_FILE}

    cp /organizations/peerOrganizations/${ORG_NAME}/peers/${PEER_NAME}.${ORG_NAME}/tls/tlscacerts/* /organizations/peerOrganizations/${ORG_NAME}/peers/${PEER_NAME}.${ORG_NAME}/tls/ca.crt
    cp /organizations/peerOrganizations/${ORG_NAME}/peers/${PEER_NAME}.${ORG_NAME}/tls/signcerts/* /organizations/peerOrganizations/${ORG_NAME}/peers/${PEER_NAME}.${ORG_NAME}/tls/server.crt
    cp /organizations/peerOrganizations/${ORG_NAME}/peers/${PEER_NAME}.${ORG_NAME}/tls/keystore/* /organizations/peerOrganizations/${ORG_NAME}/peers/${PEER_NAME}.${ORG_NAME}/tls/server.key

    mkdir -p /organizations/peerOrganizations/${ORG_NAME}/msp/tlscacerts
    cp /organizations/peerOrganizations/${ORG_NAME}/peers/${PEER_NAME}.${ORG_NAME}/tls/tlscacerts/* /organizations/peerOrganizations/${ORG_NAME}/msp/tlscacerts/tlsca.${ORG_NAME}-cert.pem

    mkdir -p /organizations/peerOrganizations/${ORG_NAME}/tlsca
    cp /organizations/peerOrganizations/${ORG_NAME}/peers/${PEER_NAME}.${ORG_NAME}/tls/tlscacerts/* /organizations/peerOrganizations/${ORG_NAME}/tlsca/tlsca.${ORG_NAME}-cert.pem

    mkdir -p /organizations/peerOrganizations/${ORG_NAME}/ca
    cp /organizations/peerOrganizations/${ORG_NAME}/peers/${PEER_NAME}.${ORG_NAME}/msp/cacerts/* /organizations/peerOrganizations/${ORG_NAME}/ca/ca.${ORG_NAME}-cert.pem
}

# Generate the user MSP
generate_user_msp() {
    log_info "Generating the user MSP"
    fabric-ca-client enroll -u https://${USER_NAME}:userpw@${CA_SERVER} --caname ${CA_NAME} -M /organizations/peerOrganizations/${ORG_NAME}/users/User1@${ORG_NAME}/msp --tls.certfiles ${TLS_CERT_FILE}

    cp /organizations/peerOrganizations/${ORG_NAME}/msp/config.yaml /organizations/peerOrganizations/${ORG_NAME}/users/User1@${ORG_NAME}/msp/config.yaml
}

# Generate the admin MSP
generate_admin_msp() {
    log_info "Generating the admin MSP"
    fabric-ca-client enroll -u https://${ADMIN_NAME}:orgadminpw@${CA_SERVER} --caname ${CA_NAME} -M /organizations/peerOrganizations/${ORG_NAME}/users/Admin@${ORG_NAME}/msp --tls.certfiles ${TLS_CERT_FILE}

    cp /organizations/peerOrganizations/${ORG_NAME}/msp/config.yaml /organizations/peerOrganizations/${ORG_NAME}/users/Admin@${ORG_NAME}/msp/config.yaml
}

# Main execution
check_ca_server || exit 1
check_required_files || exit 1
create_directories
enroll_admin
create_msp_config
register_identities
generate_peer_msp
generate_peer_tls
generate_user_msp
generate_admin_msp

log_info "Certificate generation for Org2 completed successfully"

{ set +x; } 2>/dev/null

