package gamified_challenges

// SEND: 20000000ugnot

import (
	"std"
	"strings"
	"strconv"

	"gno.land/r/challenges"
)

// Constants for address management
const adminAddress = std.Address("g1hy6zry03hg5d8le9s2w4fxme6236hkgd928dun")

func init() {
	// Initialize with admin privileges
	std.TestSetOriginCaller(adminAddress)
	
	// Initialize the challenges realm
	challenges.InitRealm()
	
	// Grant admin role to ensure we can create challenges
	challenges.GrantRole(adminAddress, challenges.ROLE_ADMIN)
	
	// Create all sample challenges
	createCryptoPuzzleChallenge()
	createBinaryTranslationChallenge()
	createPredictTheHashChallenge()
	createLogicalPuzzleChallenge()
	createEscapeRoomChallenge()
}

// --------------- CHALLENGE 1: CRYPTOGRAPHIC PUZZLE ---------------
func createCryptoPuzzleChallenge() uint64 {
	renderFunc := func() string {
		return `# Cryptographic Puzzle Challenge

## Background Story
You've intercepted a message from a secret blockchain organization. The message appears to be encrypted with a simple substitution cipher where each letter is shifted by a constant value in the alphabet.

## The Encrypted Message
"NGTU OY G HRUIQINGOT VRGZLUXS ZNOZ IUSHOTKY ZNK VUCKX UL HRUIQINGOT COZN ZNK LRKDOHOROZA UL ZUAXOTM-IUSVRKZK VXUMXGSSOTM."

## Your Task
1. Decrypt the message
2. Identify the shift value (key) used in the cipher
3. Submit your answer in the format: "DECRYPTED_MESSAGE|KEY"

## Hint
The English alphabet has 26 letters, and the shift is applied cyclically.`
	}

	assessFunc := func(challengeID uint64, submitter std.Address, submission string, asyncKey string) (grade uint64, passed bool, additional string) {
		// The encrypted message is: "GNOL IS A BLOCKCHAIN PLATFORM THAT COMBINES THE POWER OF BLOCKCHAIN WITH THE FLEXIBILITY OF TOURING-COMPLETE PROGRAMMING."
		// With a key of 6 (shift right by 6)
		
		expectedMessage := "GNOL IS A BLOCKCHAIN PLATFORM THAT COMBINES THE POWER OF BLOCKCHAIN WITH THE FLEXIBILITY OF TOURING-COMPLETE PROGRAMMING."
		expectedKey := "6"
		
		parts := strings.Split(submission, "|")
		
		if len(parts) != 2 {
			return 0, false, "Your submission format is incorrect. Please use the format: 'DECRYPTED_MESSAGE|KEY'."
		}
		
		submittedMessage := strings.TrimSpace(parts[0])
		submittedKey := strings.TrimSpace(parts[1])
		
		// Check if the message is correct
		messageCorrect := strings.EqualFold(submittedMessage, expectedMessage)
		
		// Check if the key is correct
		keyCorrect := submittedKey == expectedKey
		
		if messageCorrect && keyCorrect {
			return 100, true, "Perfect! You correctly decrypted the message and identified the key as 6."
		} else if messageCorrect {
			return 80, true, "You correctly decrypted the message, but the key you provided is incorrect. The correct key is 6."
		} else if keyCorrect {
			return 60, false, "You correctly identified the key as 6, but the decrypted message is incorrect. Please check your decryption process."
		} else {
			return 0, false, "Both your decrypted message and key are incorrect. Try using the hints and working systematically through the cipher."
		}
	}

	return challenges.CreateChallenge("Cryptographic Puzzle", 80, renderFunc, assessFunc, false)
}

// --------------- CHALLENGE 2: BINARY TRANSLATION ---------------
func createBinaryTranslationChallenge() uint64 {
	renderFunc := func() string {
		return `# Binary Translation Challenge

## Description
As blockchain developers, we often need to understand how data is represented at the binary level.

## Your Task
Translate the following binary string into ASCII text:

01000111 01101110 01101111 00101110 01101100 01100001 01101110 01100100 00100000 01101001 01110011 00100000 01110111 01101000 01100101 01110010 01100101 00100000 01100011 01101111 01100100 01100101 00100000 01100010 01100101 01100011 01101111 01101101 01100101 01110011 00100000 01101100 01100001 01110111 00101110

## Hint
Each 8-bit binary sequence represents one ASCII character.

## Submission
Submit the translated ASCII text.`
	}

	assessFunc := func(challengeID uint64, submitter std.Address, submission string, asyncKey string) (grade uint64, passed bool, additional string) {
		expected := "Gno.land is where code becomes law."
		
		if submission == expected {
			return 100, true, "Excellent! You've correctly translated the binary to ASCII text."
		} else {
			// Check if close (missing punctuation or case differences)
			normalizedSubmission := strings.ToLower(strings.ReplaceAll(submission, ".", ""))
			normalizedExpected := strings.ToLower(strings.ReplaceAll(expected, ".", ""))
			
			if normalizedSubmission == normalizedExpected {
				return 90, true, "Almost perfect! Your translation has the right words but check the punctuation and capitalization."
			}
			
			// Check if partially correct
			words := strings.Fields(expected)
			submissionWords := strings.Fields(submission)
			
			correctWords := 0
			for _, word := range words {
				for _, subWord := range submissionWords {
					if strings.EqualFold(word, subWord) {
						correctWords++
						break
					}
				}
			}
			
			if correctWords > 0 {
				percentCorrect := (correctWords * 100) / len(words)
				grade := uint64(percentCorrect)
				if grade >= 50 {
					return grade, false, "You've translated some words correctly. Keep trying!"
				}
			}
			
			return 0, false, "Your translation is incorrect. Remember, each 8-bit sequence represents one ASCII character."
		}
	}

	return challenges.CreateChallenge("Binary Translation", 90, renderFunc, assessFunc, false)
}

// --------------- CHALLENGE 3: PREDICT THE HASH ---------------
func createPredictTheHashChallenge() uint64 {
	renderFunc := func() string {
		return `# Predict the Hash Challenge

## Background
Blockchain systems rely heavily on cryptographic hash functions. For this challenge, we'll use a simplified hash function.

## Our Simple Hash Function
For this challenge, our hash function works as follows:
1. Take a string input
2. Convert each character to its ASCII value
3. Sum all the ASCII values
4. Multiply by 7
5. Take the remainder when divided by 1000 (mod 1000)
6. The result is our "hash"

## Example
Input: "ABC"
ASCII values: A=65, B=66, C=67
Sum: 65 + 66 + 67 = 198
Multiply by 7: 198 * 7 = 1386
Mod 1000: 1386 % 1000 = 386
Hash: 386

## Your Task
Find a string input that will produce a hash of exactly 42.

## Rules
1. Your input must be a readable English word or name
2. The word must be between 3 and 10 characters long
3. Only standard letters (A-Z, a-z) are allowed

## Submission
Submit just the word that produces a hash of 42.`
	}

	assessFunc := func(challengeID uint64, submitter std.Address, submission string, asyncKey string) (grade uint64, passed bool, additional string) {
		submission = strings.TrimSpace(submission)
		
		// Check if the submission is a valid word according to our rules
		if len(submission) < 3 || len(submission) > 10 {
			return 0, false, "Your submission must be between 3 and 10 characters long."
		}
		
		for _, char := range submission {
			if (char < 'A' || char > 'Z') && (char < 'a' || char > 'z') {
				return 0, false, "Your submission must only contain standard letters (A-Z, a-z)."
			}
		}
		
		// Calculate the hash
		sum := 0
		for _, char := range submission {
			sum += int(char)
		}
		
		hash := (sum * 7) % 1000
		
		if hash == 42 {
			return 100, true, "Excellent! Your word '" + submission + "' correctly produces a hash of 42."
		} else {
			return 0, false, "Your word '" + submission + "' produces a hash of " + strconv.Itoa(hash) + ", not 42. Try again!"
		}
	}

	return challenges.CreateChallenge("Predict the Hash", 100, renderFunc, assessFunc, false)
}

// --------------- CHALLENGE 4: LOGICAL PUZZLE ---------------
func createLogicalPuzzleChallenge() uint64 {
	renderFunc := func() string {
		return `# Logical Puzzle Challenge

## The Scenario
You are exploring the Gno virtual machine and have encountered a security puzzle. You need to determine the correct arrangement of five security layers to proceed.

## The Clues
1. The Merkle layer must be adjacent to the Consensus layer
2. The Encryption layer cannot be first or last
3. The Validation layer must be before the Consensus layer, but not necessarily adjacent
4. The Authentication layer must be either first or last
5. If the Merkle layer is right after the Validation layer, then the Authentication layer must be last

## Your Task
Determine the correct order of the five security layers: Authentication, Consensus, Encryption, Merkle, and Validation.

## Submission
Submit your answer as a comma-separated list in the correct order from first to last.
Example format: "Layer1, Layer2, Layer3, Layer4, Layer5"`
	}

	assessFunc := func(challengeID uint64, submitter std.Address, submission string, asyncKey string) (grade uint64, passed bool, additional string) {
		// The correct answer is: "Authentication, Validation, Encryption, Merkle, Consensus"
		expected := "Authentication, Validation, Encryption, Merkle, Consensus"
		
		// Normalize submission (remove extra spaces, standardize formatting)
		submissionParts := strings.Split(submission, ",")
		normalizedParts := make([]string, 0, len(submissionParts))
		
		for _, part := range submissionParts {
			normalizedParts = append(normalizedParts, strings.TrimSpace(part))
		}
		
		normalizedSubmission := strings.Join(normalizedParts, ", ")
		
		if normalizedSubmission == expected {
			return 100, true, "Perfect! You've correctly identified the sequence that satisfies all the clues."
		} else {
			// Check each constraint to provide helpful feedback
			hasAuth := false
			hasConsensus := false
			hasEncryption := false
			hasMerkle := false
			hasValidation := false
			
			// Check if all layers are present
			for _, part := range normalizedParts {
				switch part {
				case "Authentication":
					hasAuth = true
				case "Consensus":
					hasConsensus = true
				case "Encryption":
					hasEncryption = true
				case "Merkle":
					hasMerkle = true
				case "Validation":
					hasValidation = true
				}
			}
			
			if !hasAuth || !hasConsensus || !hasEncryption || !hasMerkle || !hasValidation {
				return 0, false, "Your solution is missing one or more of the required layers. Make sure to include all five layers: Authentication, Consensus, Encryption, Merkle, and Validation."
			}
			
			return 0, false, "Your solution doesn't satisfy all the clues. Try again and carefully check each constraint."
		}
	}

	return challenges.CreateChallenge("Logical Puzzle", 100, renderFunc, assessFunc, false)
}

// --------------- CHALLENGE 5: ESCAPE ROOM ---------------
func createEscapeRoomChallenge() uint64 {
	renderFunc := func() string {
		return `# Blockchain Escape Room Challenge

## Scenario
You're trapped in a virtual blockchain escape room. To exit, you need to find a secret passphrase by solving a series of linked puzzles about blockchain technology.

## Step 1: Transaction Puzzle
A transaction hash is: "0x7b2267616d65223a202265736361706522207d"
This is actually a hexadecimal representation of ASCII characters. Decode it to get your first clue.

## Step 2: Block Height Riddle
Using the clue from Step 1, calculate:
- Take the block height of Bitcoin's genesis block
- Add the typical number of confirmations considered secure for Bitcoin transactions
- Multiply by the approximate number of minutes it takes to mine a Bitcoin block
- Write down this number

## Step 3: Consensus Maze
Navigate the consensus maze:
Start from the number you calculated in Step 2.
- If Proof of Work was created by Satoshi Nakamoto, add 10
- If Delegated Proof of Stake uses fewer validators than standard Proof of Stake, add 5
- If Byzantine Fault Tolerance can typically withstand up to 1/3 of nodes being malicious, add 15
- If Proof of Authority requires known validators, add 20

## Step 4: Final Decryption
Take your final number from Step 3.
Find the corresponding word in this list:
50: "satoshi"
60: "smart"
70: "blocks"
80: "ledger"
90: "contract"
100: "decentralized"
110: "immutable"
120: "trustless"

This word is your escape passphrase.

## Submission
Submit the passphrase that will let you escape.`
	}

	assessFunc := func(challengeID uint64, submitter std.Address, submission string, asyncKey string) (grade uint64, passed bool, additional string) {
		// Step 1: "0x7b2267616d65223a202265736361706522207d" decodes to: {"game": "escape"}
		// Step 2: Genesis block (0) + Confirmations (6) * Block time (10) = 60
		// Step 3: 60 + 10 (true) + 5 (true) + 15 (true) + 20 (true) = 110
		// Step 4: Word at 110 is "immutable"
		
		expected := "immutable"
		
		if strings.EqualFold(strings.TrimSpace(submission), expected) {
			return 100, true, "Congratulations! You've successfully escaped the blockchain puzzle room by finding the correct passphrase: 'immutable'."
		} else {
			// Check if they are close (maybe got to step 3 but made a mistake)
			closeAnswers := map[string]string{
				"smart":         "You reached Step 3 but made a mistake in your calculations. Double-check your answers to the consensus questions.",
				"blocks":        "You reached Step 3 but made a mistake in your calculations. Double-check your answers to the consensus questions.",
				"ledger":        "You reached Step 3 but made a mistake in your calculations. Double-check your answers to the consensus questions.",
				"contract":      "You reached Step 3 but made a mistake in your calculations. Double-check your answers to the consensus questions.",
				"decentralized": "You reached Step 3 but made a mistake in your calculations. Double-check your answers to the consensus questions.",
				"trustless":     "You reached Step 3 but made a mistake in your calculations. Double-check your answers to the consensus questions.",
				"satoshi":       "You reached Step 3 but made a mistake in your calculations. Double-check your answers to the consensus questions.",
			}
			
			if feedback, found := closeAnswers[strings.ToLower(strings.TrimSpace(submission))]; found {
				return 50, false, feedback
			}
			
			// Check if they incorrectly interpreted step 1
			if strings.Contains(strings.ToLower(submission), "escape") || strings.Contains(strings.ToLower(submission), "game") {
				return 20, false, "You're on the right track with Step 1, but that's just a clue, not the final passphrase. Continue to Step 2 using this information."
			}
			
			return 0, false, "That's not the correct passphrase. Try following the steps methodically to solve the puzzle."
		}
	}

	return challenges.CreateChallenge("Blockchain Escape Room", 80, renderFunc, assessFunc, false)
}
