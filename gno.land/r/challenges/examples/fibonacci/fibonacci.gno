package fibonacci

import (
	"std"
	"strings"
)

// Render renders the challenge description
func Render(_ string) string {
	return `# Fibonacci Sequence Challenge

## Description
The Fibonacci sequence is a series of numbers where each number is the sum of the two preceding ones, starting from 0 and 1.

The sequence starts: 0, 1, 1, 2, 3, 5, 8, 13, 21, ...

## Your Task
Calculate the 20th Fibonacci number (where F(0) = 0 and F(1) = 1).

## Submission
Submit just the number as your answer.`
}

// Assess evaluates a submission for this challenge
func Assess(challengeID uint64, submitter std.Address, submission string, asyncKey string) (grade uint64, passed bool, additional string) {
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
