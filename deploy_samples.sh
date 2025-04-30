#!/bin/bash
# deploy_challenges.sh
#
# This script deploys the challenge realms and registers them with the main challenge realm

set -e # Exit immediately if a command exits with a non-zero status

# Configuration variables - EDIT THESE BEFORE RUNNING
KEY_NAME="KirkKey"  # Replace with your actual key name
CHAIN_ID="dev"          # Use appropriate chain ID for your target network
REMOTE_NODE="http://localhost:26657"  # Default for local node, update as needed
GAS_FEE="1000000ugnot"  # Adjust based on network requirements
GAS_WANTED="30000000"   # Adjust based on package complexity

# Base directories
SRC_DIR="./gno.land/r/challenges/examples"  # Source files for challenges

# Function to deploy a realm
deploy_realm() {
  local realm_name=$1
  local realm_path="gno.land/r/challenges/examples/${realm_name}"
  local realm_dir="$SRC_DIR/${realm_name}"
  
  echo "=================================================="
  echo "Deploying ${realm_name} realm to ${realm_path}"
  echo "=================================================="
  
  # Check if the key exists
  if ! gnokey list | grep -q "$KEY_NAME"; then
    echo "Error: Key '$KEY_NAME' not found. Please create a key first or update KEY_NAME."
    echo "Available keys:"
    gnokey list
    exit 1
  fi
  
  # Deploy the realm to the chain
  gnokey maketx addpkg \
    -pkgpath "${realm_path}" \
    -pkgdir "${realm_dir}" \
    -gas-fee "${GAS_FEE}" \
    -gas-wanted "${GAS_WANTED}" \
    -broadcast \
    -chainid "${CHAIN_ID}" \
    -remote "${REMOTE_NODE}" \
    "${KEY_NAME}"
  
  echo "Realm ${realm_name} deployed successfully to ${realm_path}"
}

# Copy challenge files from source to build directory
echo "Building challenge realms..."

# Deploy all challenge realms
echo "Deploying challenge realms..."
deploy_realm "fibonacci"
deploy_realm "palindrome"
deploy_realm "prime_factors"
deploy_realm "terminology"
deploy_realm "gnokey_secrets"
#deploy_realm "gno_contract_review_challenge"

# Register the challenges using the script
echo "Registering challenges with the main challenge realm..."
gnokey maketx run \
  -gas-fee "${GAS_FEE}" \
  -gas-wanted "${GAS_WANTED}" \
  -broadcast \
  -chainid "${CHAIN_ID}" \
  -remote "${REMOTE_NODE}" \
  "${KEY_NAME}" \
  "register_challenges.gno"

echo "All challenges have been deployed and registered!"
echo ""
echo "To view all challenges, use the command:"
echo "  gnokey query vm/qeval --data \"gno.land/p/demo/challenges.Render()\" -remote \"${REMOTE_NODE}\""
echo ""
echo "To view a specific challenge (replace ID with the actual challenge ID):"
echo "  gnokey query vm/qeval --data \"gno.land/p/demo/challenges.Render(1)\" -remote \"${REMOTE_NODE}\""
