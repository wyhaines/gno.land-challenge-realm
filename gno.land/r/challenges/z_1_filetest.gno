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
	// Test role granting
	challenges.GrantRole(testUser, challenges.ROLE_EDITOR)

	// Switch to test user and try to create a challenge
	testing.SetOriginCaller(testUser)

	renderFunc := func(string) string {
		return "# Editor Challenge\n\nCreated by editor."
	}
	assessFunc := func(challengeID uint64, submitter std.Address, submission string, asyncKey string) (grade uint64, passed bool, additional string) {
		return 100, true, "Editor assessment"
	}

	cid := challenges.CreateChallenge("Editor Challenge", 80, renderFunc, assessFunc, false)
	println(challenges.Render(cid))
}

// Output:
// # Editor Challenge
//
// Created by editor.
