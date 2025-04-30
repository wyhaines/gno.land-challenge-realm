package gnokey_secrets

import (
	"std"
	"strings"

	"gno.land/p/demo/btree"
)

// SecretCodeRecord stores a user's address and their secret code
type SecretCodeRecord struct {
	Address std.Address
	Code    string
}

// Less implements the btree.Record interface for SecretCodeRecord
func (scr SecretCodeRecord) Less(than btree.Record) bool {
	other := than.(SecretCodeRecord)
	return scr.Address.String() < other.Address.String()
}

// Global BTree to store user addresses and their secret codes
var secretCodes *btree.BTree

// init initializes the global BTree when the realm is deployed
func init() {
	secretCodes = btree.New()
}

// RegisterSecretCode allows a user to register their secret code
// This is the function that users will call with gnokey
func RegisterSecretCode(code string) string {
	// Get the caller's address
	caller := std.OriginCaller()
	
	// Trim any whitespace from the code
	code = strings.TrimSpace(code)
	
	// Create a record with the caller's address and their secret code
	record := SecretCodeRecord{
		Address: caller,
		Code:    code,
	}
	
	// Check if this address already has a code registered
	existingRecord := getRecordByAddress(caller)
	if existingRecord != nil {
		// Update the existing record
		secretCodes.Delete(existingRecord)
		secretCodes.Insert(record)
		return "Your secret code has been updated."
	}
	
	// Insert the new record into the BTree
	secretCodes.Insert(record)
	return "Your secret code has been registered. Remember it for the challenge assessment!"
}

// getRecordByAddress retrieves a SecretCodeRecord by address
func getRecordByAddress(addr std.Address) *SecretCodeRecord {
	var result *SecretCodeRecord
	
	// Create a dummy record with the address we're looking for
	//searchRecord := SecretCodeRecord{
	//	Address: addr,
	//	Code:    "",
	//}
	
	// Find the record in the BTree
	secretCodes.Ascend(func(rec btree.Record) bool {
		record := rec.(SecretCodeRecord)
		if record.Address == addr {
			result = &SecretCodeRecord{
				Address: record.Address,
				Code:    record.Code,
			}
			return false // Stop iteration
		}
		return true // Continue iteration
	})
	
	return result
}

// Render renders the challenge description
func Render(_ string) string {
	return `# Secret Code Challenge

## Description
This challenge tests your ability to interact with a Gno realm using gnokey and then validate that interaction.

## Your Task
This challenge consists of two parts:

1. First, call the 'RegisterSecretCode' function in this realm with a secret code of your choice.
   Use the following command (replace values as appropriate):

   ` + "```" + `bash
   gnokey maketx call \
     -pkgpath "gno.land/r/demo/secret_code_challenge" \
     -func "RegisterSecretCode" \
     -args "your_secret_code_here" \
     -gas-fee 1000000ugnot \
     -gas-wanted 2000000 \
     -broadcast \
     -chainid YOUR_CHAIN_ID \
     -remote YOUR_REMOTE_NODE \
     YOUR_KEY_NAME
   ` + "```" + `

2. Then, submit the EXACT SAME secret code as your answer to this challenge.

## Important Notes
- The secret code is case-sensitive and whitespace will be trimmed
- You must use the same account address for both the function call and the challenge submission
- Your submission will be validated against what you registered in the realm

## Submission
Submit your secret code below.`
}

// Assess evaluates a submission for this challenge
func Assess(challengeID uint64, submitter std.Address, submission string, asyncKey string) (grade uint64, passed bool, additional string) {
	// Trim whitespace from submission
	submission = strings.TrimSpace(submission)
	
	// Get the record for this submitter
	record := getRecordByAddress(submitter)
	
	// Check if the user has registered a secret code
	if record == nil {
		return 0, false, "You haven't registered a secret code yet. Please call the RegisterSecretCode function first."
	}
	
	// Check if the submitted code matches the registered code
	if record.Code == submission {
		return 100, true, "Correct! Your submitted code matches your registered secret code."
	} else {
		return 0, false, "Incorrect. Your submitted code does not match the one you registered."
	}
}
