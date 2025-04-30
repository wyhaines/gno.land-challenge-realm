package main // Change from challenges_test to challenges

// SEND: 20000000ugnot

import (
	"std"
	"testing"

	"gno.land/r/challenges"
)

const originCaller = std.Address("g1hy6zry03hg5d8le9s2w4fxme6236hkgd928dun")

func init() {
	testing.SetOriginCaller(originCaller)
}

func main() {
	challenges.InitRealm()
	// Test basic challenge creation
	renderFunc := func(string) string {
		return "# Test Challenge\n\nThis is a test challenge."
	}
	assessFunc := func(challengeID uint64, submitter std.Address, submission string, asyncKey string) (grade uint64, passed bool, additional string) {
		return 100, true, "Test assessment"
	}

	cid := challenges.CreateChallenge("Test Challenge", 80, renderFunc, assessFunc, false)
	println(challenges.Render(cid))
}

// Output:
// # Test Challenge
//
// This is a test challenge.
