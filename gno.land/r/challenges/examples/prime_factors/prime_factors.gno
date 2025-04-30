package prime_factors

import (
        "sort"
	"std"
	"strings"
	"strconv"
	"gno.land/p/demo/ufmt"
)

// Render renders the challenge description
func Render(_ string) string {
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

func formatSubmission(input string) (string, error) {
	parts := strings.Split(input, ",")
	numbers := make([]int, 0, len(parts))

	for _, part := range parts {
		trimmedPart := strings.TrimSpace(part)
		if trimmedPart == "" {
			continue 
		}
		num, err := strconv.Atoi(trimmedPart)
		if err != nil {
			return "", ufmt.Errorf("failed to convert '%s' to integer: %w", trimmedPart, err)
		}
		numbers = append(numbers, num)
	}

	sort.Ints(numbers)

	var stringNumbers []string
	for _, num := range numbers {
		stringNumbers = append(stringNumbers, strconv.Itoa(num))
	}

	return strings.Join(stringNumbers, ", "), nil
}

// Assess evaluates a submission for this challenge
func Assess(challengeID uint64, submitter std.Address, raw_submission string, asyncKey string) (grade uint64, passed bool, additional string) {
	expected := "7,17,17"
	
	// Normalize submission (remove spaces)
	submission, _ := formatSubmission(raw_submission)
	
	if submission == expected {
		return 100, true, "Correct! 2023 = 7 × 17 × 17"
	} else {
		// Check for common mistakes
		if submission == "7,289" {
			return 50, false, "You're on the right track! You found that 7 is a factor, but 289 can be broken down further into prime factors."
		}
		if submission == "7,17²" {
			return 90, false, "Almost! Check your formatting. Make sure to list each prime factor individually."
		}
		return 0, false, "That's not correct. Try a systematic approach to find all prime factors."
	}
}
