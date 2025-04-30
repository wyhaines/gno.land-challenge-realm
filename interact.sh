#!/bin/bash
# interact_challenges.sh
#
# This script provides examples of how to interact with the deployed challenges.
# It allows viewing challenge details and submitting answers.

set -e # Exit immediately if a command exits with a non-zero status

# Configuration variables - EDIT THESE BEFORE RUNNING
KEY_NAME="YourKeyName"      # Replace with your actual key name
CHAIN_ID="test3"            # Use appropriate chain ID for your target network
REMOTE_NODE="http://localhost:26657"  # Default for local node, update as needed
GAS_FEE="100000ugnot"       # Adjust based on network requirements
GAS_WANTED="200000"         # Adjust based on complexity of operations

# Function to list all challenges in a realm
list_challenges() {
  local realm=$1
  echo "Listing all challenges in ${realm}..."
  
  gnokey query vm/qeval \
    --data "gno.land/p/demo/${realm}.Render()" \
    -remote "${REMOTE_NODE}"
}

# Function to view a specific challenge
view_challenge() {
  local realm=$1
  local challenge_id=$2
  
  echo "Viewing challenge #${challenge_id} in ${realm}..."
  
  gnokey query vm/qeval \
    --data "gno.land/p/demo/${realm}.Render(${challenge_id})" \
    -remote "${REMOTE_NODE}"
}

# Function to submit an answer to a challenge
submit_answer() {
  local realm=$1
  local challenge_id=$2
  local answer=$3
  
  echo "Submitting answer to challenge #${challenge_id} in ${realm}..."
  
  # Create a temporary script file for submission
  TEMP_FILE=$(mktemp)
  
  cat > ${TEMP_FILE} << EOL
package main

import (
  "std"
  "gno.land/p/demo/${realm}"
)

func main() {
  // Submit the answer and get the submission ID
  submissionID := ${realm}.SubmitAnswer(${challenge_id}, "${answer}")
  
  // Print the submission ID for reference
  println("Submission ID:", submissionID)
  
  // Query and print the submission details
  submission := ${realm}.QuerySubmission(submissionID)
  println("Score:", submission.Score)
  println("Passed:", submission.Passed)
  println("Additional info:", submission.Additional)
  println("Is graded:", submission.IsGraded)
}
EOL
  
  # Submit the transaction using gnokey
  gnokey maketx run \
    -gas-fee "${GAS_FEE}" \
    -gas-wanted "${GAS_WANTED}" \
    -broadcast \
    -chainid "${CHAIN_ID}" \
    -remote "${REMOTE_NODE}" \
    "${KEY_NAME}" \
    ${TEMP_FILE}
  
  # Clean up temporary file
  rm ${TEMP_FILE}
}

# Display usage information if no arguments provided
if [ $# -eq 0 ]; then
  echo "Usage:"
  echo "  $0 list coding_challenges      # List all coding challenges"
  echo "  $0 list gamified_challenges    # List all gamified challenges"
  echo "  $0 view coding_challenges 1    # View coding challenge #1"
  echo "  $0 view gamified_challenges 2  # View gamified challenge #2"
  echo "  $0 submit coding_challenges 1 \"6765\"  # Submit answer to coding challenge #1"
  echo "  $0 submit gamified_challenges 2 \"Gno.land is where code becomes law.\"  # Submit answer to gamified challenge #2"
  exit 0
fi

# Parse command line arguments
COMMAND=$1
REALM=$2
CHALLENGE_ID=$3
ANSWER=$4

case ${COMMAND} in
  list)
    list_challenges ${REALM}
    ;;
  view)
    view_challenge ${REALM} ${CHALLENGE_ID}
    ;;
  submit)
    submit_answer ${REALM} ${CHALLENGE_ID} "${ANSWER}"
    ;;
  *)
    echo "Unknown command: ${COMMAND}"
    echo "Valid commands are: list, view, submit"
    exit 1
    ;;
esac

echo "Command completed successfully!"
