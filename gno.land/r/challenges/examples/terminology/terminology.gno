package terminology

import (
	"std"
	"strings"
	"strconv"
)

// Render renders the challenge description
func Render(_ string) string {
	return `# Blockchain Terminology Challenge

## Description
Understanding blockchain terminology is essential for developing on platforms like Gno.land.

## Your Task
Match each term with its correct definition:

Terms:
1. Consensus Algorithm
2. Smart Contract
3. Gas
4. Merkle Tree
5. Public Key Cryptography

Definitions:
A. A data structure used in blockchains to efficiently verify the integrity of large datasets
B. Programs stored on a blockchain that run when predetermined conditions are met
C. The mechanism through which a blockchain network reaches agreement on its state
D. A cryptographic system that uses pairs of keys: public keys for encryption and private keys for decryption
E. A fee required to perform a transaction or execute a contract on a blockchain

## Submission
Submit your answers in the format "1-C, 2-B, 3-E, 4-A, 5-D" (This is just an example, find the correct matches).`
}

// Assess evaluates a submission for this challenge
func Assess(challengeID uint64, submitter std.Address, submission string, asyncKey string) (grade uint64, passed bool, additional string) {
	expected := "1-C, 2-B, 3-E, 4-A, 5-D"
	
	submission = strings.ReplaceAll(submission, " ", "")
	expected = strings.ReplaceAll(expected, " ", "")
	
	if strings.EqualFold(submission, expected) {
		return 100, true, "Perfect! You've correctly matched all the terms with their definitions."
	} else {
		submissionParts := strings.Split(submission, ",")
		expectedParts := strings.Split(expected, ",")
		
		correctCount := 0
		for i, part := range submissionParts {
			if i < len(expectedParts) && strings.EqualFold(part, expectedParts[i]) {
				correctCount++
			}
		}
		
		grade := uint64((correctCount * 100) / 5)
		return grade, grade >= 80, "You got " + strconv.Itoa(correctCount) + " out of 5 correct."
	}
}
