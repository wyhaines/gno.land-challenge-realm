package main

// SEND: 20000000ugnot

import (
	"std"
	"testing"

	"gno.land/r/challenges"
)

const originCaller = std.Address("g1hy6zry03hg5d8le9s2w4fxme6236hkgd928dun")
const testUser = std.Address("g1whzkakk4hzjkvy60d5pwfk484xu67ar2cl62h2")

func init() {
	testing.SetOriginCaller(originCaller)
}

func main() {
	challenges.InitRealm()
	// Create a challenge first
	renderFunc := func(string) string {
		return "# Submission Test Challenge\n\nTest challenge for submissions."
	}
	assessFunc := func(challengeID uint64, submitter std.Address, submission string, asyncKey string) (grade uint64, passed bool, additional string) {
		if submission == "correct" {
			return 100, true, "Perfect submission!"
		}
		return 50, false, "Try again"
	}

	cid := challenges.CreateChallenge("Submission Test", 80, renderFunc, assessFunc, false)

	// Switch to test user and submit
	testing.SetOriginCaller(testUser)

	sid := challenges.SubmitAnswer(cid, "correct")
	sub := challenges.QuerySubmission(sid)
	println("Submission score:", sub.Score)
	println("Submission passed:", sub.Passed)
	println("Additional info:", sub.Additional)
}

// Output:
// Submission score: 100
// Submission passed: true
// Additional info: Perfect submission!
