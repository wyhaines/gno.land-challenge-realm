package palindrome

import (
	"std"
)

// Render renders the challenge description
func Render(_ string) string {
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

// Assess evaluates a submission for this challenge
func Assess(challengeID uint64, submitter std.Address, submission string, asyncKey string) (grade uint64, passed bool, additional string) {
	// This is an async challenge that requires manual review
	return 0, false, "Your solution has been submitted and will be reviewed by an instructor."
}
