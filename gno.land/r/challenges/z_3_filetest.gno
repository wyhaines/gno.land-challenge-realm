package main

// SEND: 20000000ugnot

import (
	"std"
	"testing"

	"gno.land/r/challenges"
)

const originCaller = std.Address("g1hy6zry03hg5d8le9s2w4fxme6236hkgd928dun")
const unauthorizedUser = std.Address("g1whzkakk4hzjkvy60d5pwfk484xu67ar2cl62h2")

func init() {
	testing.SetOriginCaller(originCaller)
}

func main() {
	challenges.InitRealm()
	// Test unauthorized challenge creation
	testing.SetOriginCaller(unauthorizedUser)

	renderFunc := func(string) string {
		return "# Unauthorized Challenge"
	}
	assessFunc := func(challengeID uint64, submitter std.Address, submission string, asyncKey string) (grade uint64, passed bool, additional string) {
		return 100, true, "test"
	}

	// This should panic with "must have editor/admin/superuser role to create challenge"
	challenges.CreateChallenge("Unauthorized Challenge", 80, renderFunc, assessFunc, false)
}

// Error:
// must have editor/admin/superuser role to create challenge
