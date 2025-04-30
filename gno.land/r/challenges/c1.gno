package challenges

import (
	"time"

	"std"

	"gno.land/p/demo/btree"

	"gno.land/p/wyhaines/upgradeable"
)

// -----------------------------------------------------------------------------
// Roles & Access Control (using a simple map)
// -----------------------------------------------------------------------------

// Define role bit-flags. A user may have multiple roles combined.
const (
	ROLE_SUPERUSER = 1 << 0
	ROLE_ADMIN     = 1 << 1
	ROLE_EDITOR    = 1 << 2
	ROLE_VIEWER    = 1 << 3
)

// -----------------------------------------------------------------------------
// Registry for Upgradeable Functions
// -----------------------------------------------------------------------------

var (
	registry *upgradeable.Registry

	// Upgradeable function holders
	hasRoleFunc                   *upgradeable.FunctionHolder // func(addr std.Address, role uint) bool
	requireRoleFunc               *upgradeable.FunctionHolder // func(caller std.Address, role uint)
	grantRoleFunc                 *upgradeable.FunctionHolder // func(addr std.Address, role uint)
	revokeRoleFunc                *upgradeable.FunctionHolder // func(addr std.Address, role uint)
	createChallengeFunc           *upgradeable.FunctionHolder // func(string, uint64, func(string) string, func(uint64, std.Address, string, string) (uint64, bool, string), bool) uint64
	submitAnswerFunc              *upgradeable.FunctionHolder // func(uint64, string) uint64
	doAssessmentFunc              *upgradeable.FunctionHolder // func(*Submission)
	asyncResultCallbackFunc       *upgradeable.FunctionHolder // func(uint64, uint64, bool, string)
	queryMySubmissionsFunc        *upgradeable.FunctionHolder // func() []*Submission
	querySubmissionFunc           *upgradeable.FunctionHolder // func(uint64) *Submission
	queryAllSubmissionsFunc       *upgradeable.FunctionHolder // func() []*Submission
	queryChallengeSubmissionsFunc *upgradeable.FunctionHolder // func(uint64) []*Submission
	queryAllChallengesFunc        *upgradeable.FunctionHolder // func() []*Challenge
	renderFunc                    *upgradeable.FunctionHolder // func(string) string
	getTimestampFunc              *upgradeable.FunctionHolder // func() int64
)

// -----------------------------------------------------------------------------
// Data Structures for Challenges & Submissions
// -----------------------------------------------------------------------------

type Challenge struct {
	ID               uint64
	Title            string
	Owner            std.Address
	PassingThreshold uint64
	Active           bool

	RenderFunc func(string) string
	AssessFunc func(challengeID uint64, submitter std.Address, submission string, asyncKey string) (grade uint64, passed bool, additional string)
	IsAsync    bool
}

type Submission struct {
	ID          uint64
	ChallengeID uint64
	Submitter   std.Address
	Timestamp   int64
	ContentHash string
	Score       uint64
	Passed      bool
	Additional  string
	IsGraded    bool
}

type ChallengeRecord struct {
	ID uint64
	Ch *Challenge
}

func (cr ChallengeRecord) Less(than btree.Record) bool {
	other := than.(ChallengeRecord)
	return cr.ID < other.ID
}

type SubmissionRecord struct {
	ID  uint64
	Sub *Submission
}

func (sr SubmissionRecord) Less(than btree.Record) bool {
	other := than.(SubmissionRecord)
	return sr.ID < other.ID
}

// -----------------------------------------------------------------------------
// Global Variables
// -----------------------------------------------------------------------------

var (
	challenges       map[uint64]*Challenge
	submissions      map[uint64]*Submission
	roles            map[std.Address]uint
	nextChallengeID  uint64
	nextSubmissionID uint64
	challengesTree   *btree.BTree
	submissionsTree  *btree.BTree
)

// -----------------------------------------------------------------------------
// Lookup Helpers
// -----------------------------------------------------------------------------

func getChallengeByID(id uint64) *Challenge {
	rec := challengesTree.Get(ChallengeRecord{ID: id})
	if rec == nil {
		return nil
	}
	return rec.(ChallengeRecord).Ch
}

func getSubmissionByID(id uint64) *Submission {
	rec := submissionsTree.Get(SubmissionRecord{ID: id})
	if rec == nil {
		return nil
	}
	return rec.(SubmissionRecord).Sub
}

// -----------------------------------------------------------------------------
// Original function implementations (defaults)
// -----------------------------------------------------------------------------

func hasRole(addr std.Address, role uint) bool {
	r, ok := roles[addr]
	if !ok {
		return false
	}
	return (r & role) == role
}

func requireRole(caller std.Address, role uint) {
	hasRoleFn := hasRoleFunc.Get().(func(std.Address, uint) bool)
	if !hasRoleFn(caller, role) {
		panic("insufficient permissions")
	}
}

func grantRole(addr std.Address, role uint) {
	caller := std.OriginCaller()
	hasRoleFn := hasRoleFunc.Get().(func(std.Address, uint) bool)
	requireRoleFn := requireRoleFunc.Get().(func(std.Address, uint))
	if role == ROLE_SUPERUSER {
		requireRoleFn(caller, ROLE_SUPERUSER)
	} else if !hasRoleFn(caller, ROLE_SUPERUSER) && !hasRoleFn(caller, ROLE_ADMIN) {
		panic("must be admin or superuser to grant roles")
	}
	roles[addr] |= role
}

func revokeRole(addr std.Address, role uint) {
	caller := std.OriginCaller()
	hasRoleFn := hasRoleFunc.Get().(func(std.Address, uint) bool)
	requireRoleFn := requireRoleFunc.Get().(func(std.Address, uint))
	if role == ROLE_SUPERUSER {
		requireRoleFn(caller, ROLE_SUPERUSER)
	} else if !hasRoleFn(caller, ROLE_SUPERUSER) && !hasRoleFn(caller, ROLE_ADMIN) {
		panic("must be admin or superuser to revoke roles")
	}
	roles[addr] &^= role
}

func createChallenge(
	title string,
	passingThreshold uint64,
	rnd func(string) string,
	assess func(uint64, std.Address, string, string) (uint64, bool, string),
	isAsync bool,
) uint64 {
	caller := std.OriginCaller()
	hasRoleFn := hasRoleFunc.Get().(func(std.Address, uint) bool)
	if !(hasRoleFn(caller, ROLE_EDITOR) || hasRoleFn(caller, ROLE_ADMIN) || hasRoleFn(caller, ROLE_SUPERUSER)) {
		panic("must have editor/admin/superuser role")
	}
	nextChallengeID++
	cid := nextChallengeID
	ch := &Challenge{ID: cid, Title: title, Owner: caller, PassingThreshold: passingThreshold, Active: true, RenderFunc: rnd, AssessFunc: assess, IsAsync: isAsync}
	challengesTree.Insert(ChallengeRecord{ID: cid, Ch: ch})
	return cid
}

func submitAnswer(challengeID uint64, contentHash string) uint64 {
	caller := std.OriginCaller()
	ch := getChallengeByID(challengeID)
	if ch == nil || !ch.Active {
		panic("invalid challenge")
	}
	timestamp := getTimestampFunc.Get().(func() int64)()
	nextSubmissionID++
	sid := nextSubmissionID
	sub := &Submission{ID: sid, ChallengeID: challengeID, Submitter: caller, Timestamp: timestamp, ContentHash: contentHash}
	submissionsTree.Insert(SubmissionRecord{ID: sid, Sub: sub})
	if !ch.IsAsync {
		doAssessmentFunc.Get().(func(*Submission))(sub)
	}
	return sid
}

func doAssessment(sub *Submission) {
	ch := getChallengeByID(sub.ChallengeID)
	if ch != nil && ch.AssessFunc != nil {
		grade, passed, info := ch.AssessFunc(ch.ID, sub.Submitter, sub.ContentHash, "")
		sub.Score, sub.Passed, sub.Additional = grade, passed, info
	} else {
		sub.Score = 80
		sub.Passed = sub.Score >= ch.PassingThreshold
		sub.Additional = "default grading"
	}
	sub.IsGraded = true
}

func asyncResultCallback(submissionID, score uint64, passed bool, info string) {
	caller := std.OriginCaller()
	hasRoleFn := hasRoleFunc.Get().(func(std.Address, uint) bool)
	if !hasRoleFn(caller, ROLE_ADMIN) && !hasRoleFn(caller, ROLE_SUPERUSER) {
		panic("not authorized")
	}
	sub := getSubmissionByID(submissionID)
	if sub == nil || sub.IsGraded {
		panic("invalid submission")
	}
	sub.Score, sub.Passed, sub.Additional, sub.IsGraded = score, passed, info, true
}

func queryMySubmissions() []*Submission {
	caller := std.OriginCaller()
	var out []*Submission
	submissionsTree.Ascend(func(r btree.Record) bool {
		sr := r.(SubmissionRecord)
		if sr.Sub.Submitter == caller {
			out = append(out, sr.Sub)
		}
		return true
	})
	return out
}

func querySubmission(submissionID uint64) *Submission {
	caller := std.OriginCaller()
	sub := getSubmissionByID(submissionID)
	has := hasRoleFunc.Get().(func(std.Address, uint) bool)
	if sub == nil {
		panic("not found")
	}
	if sub.Submitter == caller || has(caller, ROLE_VIEWER) || has(caller, ROLE_ADMIN) || has(caller, ROLE_SUPERUSER) {
		return sub
	}
	panic("not authorized")
}

func queryAllSubmissions() []*Submission {
	caller := std.OriginCaller()
	has := hasRoleFunc.Get().(func(std.Address, uint) bool)
	if !(has(caller, ROLE_VIEWER) || has(caller, ROLE_ADMIN) || has(caller, ROLE_SUPERUSER)) {
		panic("not authorized")
	}
	var out []*Submission
	submissionsTree.Ascend(func(r btree.Record) bool {
		out = append(out, r.(SubmissionRecord).Sub)
		return true
	})
	return out
}

func queryChallengeSubmissions(challengeID uint64) []*Submission {
	caller := std.OriginCaller()
	has := hasRoleFunc.Get().(func(std.Address, uint) bool)
	ch := getChallengeByID(challengeID)
	if ch == nil {
		panic("not found")
	}
	var out []*Submission
	submissionsTree.Ascend(func(r btree.Record) bool {
		sr := r.(SubmissionRecord)
		if sr.Sub.ChallengeID == challengeID {
			if sr.Sub.Submitter == caller || ch.Owner == caller || has(caller, ROLE_VIEWER) || has(caller, ROLE_ADMIN) || has(caller, ROLE_SUPERUSER) {
				out = append(out, sr.Sub)
			}
		}
		return true
	})
	return out
}

func queryAllChallenges() []*Challenge {
	var out []*Challenge
	challengesTree.Ascend(func(r btree.Record) bool {
		out = append(out, r.(ChallengeRecord).Ch)
		return true
	})
	return out
}

func renderImpl(path string) string {
	// ... existing rendering logic ...
	return "" // omitted for brevity
}

func getTimestamp() int64 {
	return time.Now().Unix()
}

// -----------------------------------------------------------------------------
// Public API Functions
// -----------------------------------------------------------------------------

func HasRole(addr std.Address, role uint) bool {
	return hasRoleFunc.Get().(func(std.Address, uint) bool)(addr, role)
}

func RequireRole(caller std.Address, role uint) {
	requireRoleFunc.Get().(func(std.Address, uint))(caller, role)
}

func GrantRole(addr std.Address, role uint) {
	grantRoleFunc.Get().(func(std.Address, uint))(addr, role)
}

func RevokeRole(addr std.Address, role uint) {
	revokeRoleFunc.Get().(func(std.Address, uint))(addr, role)
}

func CreateChallenge(title string, passingThreshold uint64, render func(string) string, assess func(uint64, std.Address, string, string) (uint64, bool, string), isAsync bool) uint64 {
	return createChallengeFunc.Get().(func(string, uint64, func(string) string, func(uint64, std.Address, string, string) (uint64, bool, string), bool) uint64)(title, passingThreshold, render, assess, isAsync)
}

func SubmitAnswer(challengeID uint64, contentHash string) uint64 {
	return submitAnswerFunc.Get().(func(uint64, string) uint64)(challengeID, contentHash)
}

func AsyncResultCallback(submissionID, score uint64, passed bool, info string) {
	asyncResultCallbackFunc.Get().(func(uint64, uint64, bool, string))(submissionID, score, passed, info)
}

func QueryMySubmissions() []*Submission {
	return queryMySubmissionsFunc.Get().(func() []*Submission)()
}

func QuerySubmission(submissionID uint64) *Submission {
	return querySubmissionFunc.Get().(func(uint64) *Submission)(submissionID)
}

func QueryAllSubmissions() []*Submission {
	return queryAllSubmissionsFunc.Get().(func() []*Submission)()
}

func QueryChallengeSubmissions(challengeID uint64) []*Submission {
	return queryChallengeSubmissionsFunc.Get().(func(uint64) []*Submission)(challengeID)
}

func QueryAllChallenges() []*Challenge {
	return queryAllChallengesFunc.Get().(func() []*Challenge)()
}

func Render(path string) string {
	return renderFunc.Get().(func(string) string)(path)
}

func GetTimestamp() int64 {
	return getTimestampFunc.Get().(func() int64)()
}

// -----------------------------------------------------------------------------
// Upgrade Admin Functions
// -----------------------------------------------------------------------------

func UpgradeHasRoleFunc(newFunc func(std.Address, uint) bool) error {
	caller := std.OriginCaller()
	if !HasRole(caller, ROLE_SUPERUSER) {
		return upgradeable.ErrCallerNotAdmin
	}
	return hasRoleFunc.Update(newFunc)
}

func UpgradeRequireRoleFunc(newFunc func(std.Address, uint)) error {
	caller := std.OriginCaller()
	if !HasRole(caller, ROLE_SUPERUSER) {
		return upgradeable.ErrCallerNotAdmin
	}
	return requireRoleFunc.Update(newFunc)
}

func UpgradeGrantRoleFunc(newFunc func(std.Address, uint)) error {
	caller := std.OriginCaller()
	if !HasRole(caller, ROLE_SUPERUSER) {
		return upgradeable.ErrCallerNotAdmin
	}
	return grantRoleFunc.Update(newFunc)
}

func UpgradeRevokeRoleFunc(newFunc func(std.Address, uint)) error {
	caller := std.OriginCaller()
	if !HasRole(caller, ROLE_SUPERUSER) {
		return upgradeable.ErrCallerNotAdmin
	}
	return revokeRoleFunc.Update(newFunc)
}

func UpgradeCreateChallengeFunc(newFunc func(string, uint64, func(string) string, func(uint64, std.Address, string, string) (uint64, bool, string), bool) uint64) error {
	caller := std.OriginCaller()
	if !HasRole(caller, ROLE_SUPERUSER) {
		return upgradeable.ErrCallerNotAdmin
	}
	return createChallengeFunc.Update(newFunc)
}

func UpgradeSubmitAnswerFunc(newFunc func(uint64, string) uint64) error {
	caller := std.OriginCaller()
	if !HasRole(caller, ROLE_SUPERUSER) {
		return upgradeable.ErrCallerNotAdmin
	}
	return submitAnswerFunc.Update(newFunc)
}

func UpgradeDoAssessmentFunc(newFunc func(*Submission)) error {
	caller := std.OriginCaller()
	if !HasRole(caller, ROLE_SUPERUSER) {
		return upgradeable.ErrCallerNotAdmin
	}
	return doAssessmentFunc.Update(newFunc)
}

func UpgradeAsyncResultCallbackFunc(newFunc func(uint64, uint64, bool, string)) error {
	caller := std.OriginCaller()
	if !HasRole(caller, ROLE_SUPERUSER) {
		return upgradeable.ErrCallerNotAdmin
	}
	return asyncResultCallbackFunc.Update(newFunc)
}

func UpgradeQueryMySubmissionsFunc(newFunc func() []*Submission) error {
	caller := std.OriginCaller()
	if !HasRole(caller, ROLE_SUPERUSER) {
		return upgradeable.ErrCallerNotAdmin
	}
	return queryMySubmissionsFunc.Update(newFunc)
}

func UpgradeQuerySubmissionFunc(newFunc func(uint64) *Submission) error {
	caller := std.OriginCaller()
	if !HasRole(caller, ROLE_SUPERUSER) {
		return upgradeable.ErrCallerNotAdmin
	}
	return querySubmissionFunc.Update(newFunc)
}

func UpgradeQueryAllSubmissionsFunc(newFunc func() []*Submission) error {
	caller := std.OriginCaller()
	if !HasRole(caller, ROLE_SUPERUSER) {
		return upgradeable.ErrCallerNotAdmin
	}
	return queryAllSubmissionsFunc.Update(newFunc)
}

func UpgradeQueryChallengeSubmissionsFunc(newFunc func(uint64) []*Submission) error {
	caller := std.OriginCaller()
	if !HasRole(caller, ROLE_SUPERUSER) {
		return upgradeable.ErrCallerNotAdmin
	}
	return queryChallengeSubmissionsFunc.Update(newFunc)
}

func UpgradeQueryAllChallengesFunc(newFunc func() []*Challenge) error {
	caller := std.OriginCaller()
	if !HasRole(caller, ROLE_SUPERUSER) {
		return upgradeable.ErrCallerNotAdmin
	}
	return queryAllChallengesFunc.Update(newFunc)
}

func UpgradeRenderFunc(newFunc func(string) string) error {
	caller := std.OriginCaller()
	if !HasRole(caller, ROLE_SUPERUSER) {
		return upgradeable.ErrCallerNotAdmin
	}
	return renderFunc.Update(newFunc)
}

func UpgradeGetTimestampFunc(newFunc func() int64) error {
	caller := std.OriginCaller()
	if !HasRole(caller, ROLE_SUPERUSER) {
		return upgradeable.ErrCallerNotAdmin
	}
	return getTimestampFunc.Update(newFunc)
}

// -----------------------------------------------------------------------------
// Initialization
// -----------------------------------------------------------------------------

func init() string {
	challenges = make(map[uint64]*Challenge)
	submissions = make(map[uint64]*Submission)
	roles = make(map[std.Address]uint)
	nextChallengeID = 1
	nextSubmissionID = 1
	challengesTree = btree.New()
	submissionsTree = btree.New()

	creator := std.OriginCaller()
	roles[creator] = ROLE_SUPERUSER

	registry = upgradeable.NewWithAddress(creator)

	hasRoleFunc = upgradeable.NewFunctionHolder(registry, "hasRole", hasRole)
	requireRoleFunc = upgradeable.NewFunctionHolder(registry, "requireRole", requireRole)
	grantRoleFunc = upgradeable.NewFunctionHolder(registry, "grantRole", grantRole)
	revokeRoleFunc = upgradeable.NewFunctionHolder(registry, "revokeRole", revokeRole)
	createChallengeFunc = upgradeable.NewFunctionHolder(registry, "createChallenge", createChallenge)
	submitAnswerFunc = upgradeable.NewFunctionHolder(registry, "submitAnswer", submitAnswer)
	doAssessmentFunc = upgradeable.NewFunctionHolder(registry, "doAssessment", doAssessment)
	asyncResultCallbackFunc = upgradeable.NewFunctionHolder(registry, "asyncResultCallback", asyncResultCallback)
	queryMySubmissionsFunc = upgradeable.NewFunctionHolder(registry, "queryMySubmissions", queryMySubmissions)
	querySubmissionFunc = upgradeable.NewFunctionHolder(registry, "querySubmission", querySubmission)
	queryAllSubmissionsFunc = upgradeable.NewFunctionHolder(registry, "queryAllSubmissions", queryAllSubmissions)
	queryChallengeSubmissionsFunc = upgradeable.NewFunctionHolder(registry, "queryChallengeSubmissions", queryChallengeSubmissions)
	queryAllChallengesFunc = upgradeable.NewFunctionHolder(registry, "queryAllChallenges", queryAllChallenges)
	renderFunc = upgradeable.NewFunctionHolder(registry, "render", renderImpl)
	getTimestampFunc = upgradeable.NewFunctionHolder(registry, "getTimestamp", getTimestamp)

	return "registration finished;"
}
