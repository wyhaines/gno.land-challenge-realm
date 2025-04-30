package main

import (
	"gno.land/r/challenges"
	"gno.land/r/challenges/examples/fibonacci"
	"gno.land/r/challenges/examples/palindrome"
	"gno.land/r/challenges/examples/prime_factors"
	"gno.land/r/challenges/examples/terminology"
	"gno.land/r/challenges/examples/gnokey_secrets"
//	"gno.land/r/demo/gno_contract_review"
)

func main() {
	// Register the Fibonacci challenge
	fibonacciID := challenges.CreateChallenge(
		"Fibonacci Sequence", 
		100, 
		fibonacci.Render,
		fibonacci.Assess,
		false,
	)
	println("Registered Fibonacci challenge with ID:", fibonacciID)
	
	// Register the Palindrome challenge
	palindromeID := challenges.CreateChallenge(
		"Palindrome Checker", 
		80, 
		palindrome.Render,
		palindrome.Assess,
		true,
	)
	println("Registered Palindrome challenge with ID:", palindromeID)
	
	// Register the Prime Factors challenge
	primeFactorsID := challenges.CreateChallenge(
		"Prime Factorization", 
		100, 
		prime_factors.Render,
		prime_factors.Assess,
		false,
	)
	println("Registered Prime Factors challenge with ID:", primeFactorsID)
	
	// Register the Blockchain Terminology challenge
	terminologyID := challenges.CreateChallenge(
		"Blockchain Terminology", 
		80, 
		terminology.Render,
		terminology.Assess,
		false,
	)
	println("Registered Blockchain Terminology challenge with ID:", terminologyID)
	
	// Register the Gnokey Secrets challenge
	secretsID := challenges.CreateChallenge(
		"Gnokey Secrets", 
		80, 
		gnokey_secrets.Render,
		gnokey_secrets.Assess,
		false,
	)
	println("Registered Gnokey Secrets challenge with ID:", secretsID)

	// Register the Gno Contract Review challenge
//	reviewID := challenges.CreateChallenge(
//		"Gno Contract Review", 
//		80, 
//		gno_contract_review.Render,
//		gno_contract_review.Assess,
//		true,
//	)
//	println("Registered Gno Contract Review challenge with ID:", reviewID)
}
