package coding_challenges

import (
	"std"
	"strconv"
	"strings"
)

// --------------- CHALLENGE 1: FIBONACCI SEQUENCE ---------------
func createFibonacciChallenge() uint64 {
	renderFunc := func() string {
		return `# Fibonacci Sequence Challenge

## Description
The Fibonacci sequence is a series of numbers where each number is the sum of the two preceding ones, starting from 0 and 1.

The sequence starts: 0, 1, 1, 2, 3, 5, 8, 13, 21, ...

## Your Task
Calculate the 20th Fibonacci number (where F(0) = 0 and F(1) = 1).

## Submission
Submit just the number as your answer.`
	}

	assessFunc := func(challengeID uint64, submitter std.Address, submission string, asyncKey string) (grade uint64, passed bool, additional string) {
		// The 20th Fibonacci number (0-indexed) is 6765
		expected := "6765"
		
		submission = strings.TrimSpace(submission)
		
		if submission == expected {
			return 100, true, "Correct! The 20th Fibonacci number is indeed 6765."
		} else {
			// Check if they used 1-indexing instead of 0-indexing
			if submission == "10946" {
				return 70, false, "You calculated the 21st Fibonacci number (1-indexed). The challenge uses 0-indexing, so F(20) was expected."
			}
			return 0, false, "Incorrect. Try working through the sequence step by step."
		}
	}

}

// --------------- CHALLENGE 2: PALINDROME CHECKER ---------------
func createPalindromeChallenge() uint64 {
	renderFunc := func() string {
		return `# Palindrome Checker Challenge

## Description
A palindrome is a word, phrase, number, or other sequence that reads the same forward and backward.

## Your Task
Write a function in pseudo-code or any programming language that checks if a given string is a palindrome.

Your function should:
1. Ignore spaces, punctuation, and capitalization
2. Return true if the string is a palindrome, false otherwise

## Example
"A man, a plan, a canal, Panama!" should return true.

## Submission
Submit your code solution below.`
	}

	assessFunc := func(challengeID uint64, submitter std.Address, submission string, asyncKey string) (grade uint64, passed bool, additional string) {
		// This is an async challenge that requires manual review
		return 0, false, "Your solution has been submitted and will be reviewed by an instructor."
	}

}

// --------------- CHALLENGE 3: PRIME FACTORS ---------------
func createPrimeFactorsChallenge() uint64 {
	renderFunc := func() string {
		return `# Prime Factorization Challenge

## Description
Prime factorization is the process of determining which prime numbers multiply together to make the original number.

## Your Task
Find all prime factors of 2023 and submit them in ascending order, separated by commas.

## Example
The prime factorization of 15 would be submitted as: "3,5"

## Submission
Submit the prime factors as described.`
	}

	assessFunc := func(challengeID uint64, submitter std.Address, submission string, asyncKey string) (grade uint64, passed bool, additional string) {
		expected := "7,17,17"
		
		// Normalize submission (remove spaces)
		submission = strings.ReplaceAll(submission, " ", "")
		
		if submission == expected {
			return 100, true, "Correct! 2023 = 7 × 17 × 17"
		} else {
			// Check for common mistakes
			if submission == "7,289" {
				return 50, false, "You're on the right track! You found that 7 is a factor, but 289 can be broken down further into prime factors."
			}
			if submission == "7,17,17" || submission == "7,17²" {
				return 90, false, "Almost! Check your formatting. Make sure to list each prime factor individually."
			}
			return 0, false, "That's not correct. Try a systematic approach to find all prime factors."
		}
	}

}

// --------------- CHALLENGE 4: BLOCKCHAIN TERMINOLOGY ---------------
func createBlockchainTerminologyChallenge() uint64 {
	renderFunc := func() string {
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

	assessFunc := func(challengeID uint64, submitter std.Address, submission string, asyncKey string) (grade uint64, passed bool, additional string) {
		expected := "1-C, 2-B, 3-E, 4-A, 5-D"
		
		// Normalize submission (remove spaces)
		submission = strings.ReplaceAll(submission, " ", "")
		expected = strings.ReplaceAll(expected, " ", "")
		
		if strings.EqualFold(submission, expected) {
			return 100, true, "Perfect! You've correctly matched all the terms with their definitions."
		} else {
			// Count correct answers
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

}

// --------------- CHALLENGE 5: GNO CONTRACT REVIEW ---------------
func createGnoContractReviewChallenge() uint64 {
	renderFunc := func() string {
		return `# Gno Smart Contract Review Challenge

## Description
Code review is an essential skill for blockchain developers. In this challenge, you'll review a simple Gno smart contract.

## The Contract
Here's a simple token contract written in Gno:

~~~go
package token

import (
	"errors"
	"std"
)

type Token struct {
	admin  std.Address
	name   string
	symbol string
	supply uint64
	balances map[std.Address]uint64
}

func NewToken(name, symbol string, initialSupply uint64) *Token {
	admin := std.GetOrigCaller()
	t := &Token{
		admin:  admin,
		name:   name,
		symbol: symbol,
		supply: initialSupply,
		balances: make(map[std.Address]uint64),
	}
	t.balances[admin] = initialSupply
	return t
}

func (t *Token) Transfer(to std.Address, amount uint64) error {
	from := std.GetOrigCaller()
	
	if from == to {
		return errors.New("cannot transfer to self")
	}
	
	if t.balances[from] < amount {
		return errors.New("insufficient balance")
	}
	
	t.balances[from] -= amount
	t.balances[to] += amount
	
	return nil
}

func (t *Token) BalanceOf(addr std.Address) uint64 {
	return t.balances[addr]
}
~~~

## Your Task
Identify at least three security or functionality issues in this contract. For each issue:
1. Describe the problem
2. Explain the potential impact
3. Suggest a solution

## Submission
Submit your review as a structured list of the issues you found with your explanations.`
	}

	assessFunc := func(challengeID uint64, submitter std.Address, submission string, asyncKey string) (grade uint64, passed bool, additional string) {
		// This is an async challenge that requires manual review
		return 0, false, "Your submission will be reviewed by an expert. The review will check if you identified key issues such as lack of events for transfers, no protection against integer overflow, and missing access control for critical functions."
	}

}
