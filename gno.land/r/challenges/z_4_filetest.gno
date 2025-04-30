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
	// Create an async challenge
	renderFunc := func(string) string {
		return "# Async Challenge\n\nThis is an asynchronous challenge."
	}
	assessFunc := func(challengeID uint64, submitter std.Address, submission string, asyncKey string) (grade uint64, passed bool, additional string) {
		return 0, false, "Async assessment pending"
	}

	cid := challenges.CreateChallenge("Async Challenge", 80, renderFunc, assessFunc, true)

	// Submit an answer
	testing.SetOriginCaller(testUser)
	sid := challenges.SubmitAnswer(cid, "test submission")

	// Switch back to admin to grade the submission
	testing.SetOriginCaller(originCaller)
	challenges.GrantRole(std.OriginCaller(), challenges.ROLE_ADMIN)
	challenges.AsyncResultCallback(sid, 95, true, "Async grading complete")

	// Query the submission to verify grading
	sub := challenges.QuerySubmission(sid)
	println("Submission score:", sub.Score)
	println("Submission passed:", sub.Passed)
	println("Additional info:", sub.Additional)
	println("Is graded:", sub.IsGraded)
}

// Output:
// Submission score: 95
// Submission passed: true
// Additional info: Async grading complete
// Is graded: true
