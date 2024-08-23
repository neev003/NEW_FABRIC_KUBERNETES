#!/bin/bash

# Set up error handling
set -e

# Define variables
CA_SERVER="ca-orderer:10054"
ORG_NAME="example.com"
CA_NAME="ca-orderer"
TLS_CERT_FILE="/data/tls-cert.pem"
ORDERER_NAME="orderer"
ADMIN_NAME="ordererAdmin"

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
  local max_retries=30
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
    mkdir -p organizations/ordererOrganizations/${ORG_NAME}/{msp,orderers,users}
    mkdir -p organizations/ordererOrganizations/${ORG_NAME}/orderers/${ORDERER_NAME}.${ORG_NAME}
    mkdir -p organizations/ordererOrganizations/${ORG_NAME}/users/Admin@${ORG_NAME}
}

# Enroll admin
enroll_admin() {
    log_info "Enrolling admin"
    export FABRIC_CA_CLIENT_HOME=/organizations/ordererOrganizations/${ORG_NAME}
    fabric-ca-client enroll -u https://admin:adminpw@${CA_SERVER} --caname ${CA_NAME} --tls.certfiles ${TLS_CERT_FILE} --csr.hosts $(hostname)
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
    OrganizationalUnitIdentifier: orderer' > /organizations/ordererOrganizations/${ORG_NAME}/msp/config.yaml
}

# Register orderer and admin
register_identities() {
    log_info "Registering orderer"
    fabric-ca-client register --caname ${CA_NAME} --id.name ${ORDERER_NAME} --id.secret ordererpw --id.type orderer --tls.certfiles ${TLS_CERT_FILE}

    log_info "Registering the orderer admin"
    fabric-ca-client register --caname ${CA_NAME} --id.name ${ADMIN_NAME} --id.secret ordererAdminpw --id.type admin --tls.certfiles ${TLS_CERT_FILE}
}

# Generate the orderer MSP
generate_orderer_msp() {
    log_info "Generating the orderer MSP"
    fabric-ca-client enroll -u https://${ORDERER_NAME}:ordererpw@${CA_SERVER} --caname ${CA_NAME} -M /organizations/ordererOrganizations/${ORG_NAME}/orderers/${ORDERER_NAME}.${ORG_NAME}/msp --csr.hosts ${ORDERER_NAME}.${ORG_NAME} --csr.hosts localhost --csr.hosts ${CA_NAME} --csr.hosts ${ORDERER_NAME} --tls.certfiles ${TLS_CERT_FILE}

    cp /organizations/ordererOrganizations/${ORG_NAME}/msp/config.yaml /organizations/ordererOrganizations/${ORG_NAME}/orderers/${ORDERER_NAME}.${ORG_NAME}/msp/config.yaml
}

# Generate the orderer TLS certificates
generate_orderer_tls() {
    log_info "Generating the orderer TLS certificates"
    fabric-ca-client enroll -u https://${ORDERER_NAME}:ordererpw@${CA_SERVER} --caname ${CA_NAME} -M /organizations/ordererOrganizations/${ORG_NAME}/orderers/${ORDERER_NAME}.${ORG_NAME}/tls --enrollment.profile tls --csr.hosts ${ORDERER_NAME}.${ORG_NAME} --csr.hosts localhost --csr.hosts ${CA_NAME} --csr.hosts ${ORDERER_NAME} --tls.certfiles ${TLS_CERT_FILE}

    cp /organizations/ordererOrganizations/${ORG_NAME}/orderers/${ORDERER_NAME}.${ORG_NAME}/tls/tlscacerts/* /organizations/ordererOrganizations/${ORG_NAME}/orderers/${ORDERER_NAME}.${ORG_NAME}/tls/ca.crt
    cp /organizations/ordererOrganizations/${ORG_NAME}/orderers/${ORDERER_NAME}.${ORG_NAME}/tls/signcerts/* /organizations/ordererOrganizations/${ORG_NAME}/orderers/${ORDERER_NAME}.${ORG_NAME}/tls/server.crt
    cp /organizations/ordererOrganizations/${ORG_NAME}/orderers/${ORDERER_NAME}.${ORG_NAME}/tls/keystore/* /organizations/ordererOrganizations/${ORG_NAME}/orderers/${ORDERER_NAME}.${ORG_NAME}/tls/server.key

    mkdir -p /organizations/ordererOrganizations/${ORG_NAME}/orderers/${ORDERER_NAME}.${ORG_NAME}/msp/tlscacerts
    cp /organizations/ordererOrganizations/${ORG_NAME}/orderers/${ORDERER_NAME}.${ORG_NAME}/tls/tlscacerts/* /organizations/ordererOrganizations/${ORG_NAME}/orderers/${ORDERER_NAME}.${ORG_NAME}/msp/tlscacerts/tlsca.${ORG_NAME}-cert.pem

    mkdir -p /organizations/ordererOrganizations/${ORG_NAME}/msp/tlscacerts
    cp /organizations/ordererOrganizations/${ORG_NAME}/orderers/${ORDERER_NAME}.${ORG_NAME}/tls/tlscacerts/* /organizations/ordererOrganizations/${ORG_NAME}/msp/tlscacerts/tlsca.${ORG_NAME}-cert.pem
}

# Generate the admin MSP
generate_admin_msp() {
    log_info "Generating the admin MSP"
    fabric-ca-client enroll -u https://${ADMIN_NAME}:ordererAdminpw@${CA_SERVER} --caname ${CA_NAME} -M /organizations/ordererOrganizations/${ORG_NAME}/users/Admin@${ORG_NAME}/msp --tls.certfiles ${TLS_CERT_FILE}

    cp /organizations/ordererOrganizations/${ORG_NAME}/msp/config.yaml /organizations/ordererOrganizations/${ORG_NAME}/users/Admin@${ORG_NAME}/msp/config.yaml
}

# Main execution
check_ca_server || exit 1
check_required_files || exit 1
create_directories
enroll_admin
create_msp_config
register_identities
generate_orderer_msp
generate_orderer_tls
generate_admin_msp

log_info "Certificate generation completed successfully"

exit 0
