package challenges

import (
	"strconv"
	"strings"
	"time"

	"std"

	"gno.land/p/demo/btree"
	"gno.land/p/demo/ufmt"

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
	// Registry for upgradeable functions
	registry *upgradeable.Registry

	// Upgradeable functions
	hasRoleFunc             *upgradeable.FunctionHolder // func(addr std.Address, role uint) bool
	requireRoleFunc         *upgradeable.FunctionHolder // func(caller std.Address, role uint)
	grantRoleFunc           *upgradeable.FunctionHolder // func(addr std.Address, role uint)
	revokeRoleFunc          *upgradeable.FunctionHolder // func(addr std.Address, role uint)
	createChallengeFunc     *upgradeable.FunctionHolder // complex signature, using base holder
	submitAnswerFunc        *upgradeable.FunctionHolder // func(challengeID uint64, contentHash string) uint64
	doAssessmentFunc        *upgradeable.FunctionHolder // func(sub *Submission)
	asyncResultCallbackFunc *upgradeable.FunctionHolder // func(submissionID uint64, score uint64, passed bool, info string)
	queryMySubmissionsFunc  *upgradeable.FunctionHolder // func() []*Submission
	querySubmissionFunc     *upgradeable.FunctionHolder // func(submissionID uint64) *Submission
	queryAllSubmissionsFunc *upgradeable.FunctionHolder // func() []*Submission
	queryAllChallengesFunc  *upgradeable.FunctionHolder // func() []*Challenge
	renderFunc              *upgradeable.FunctionHolder // func(args ...interface{}) string
	getTimestampFunc        *upgradeable.FunctionHolder // func() int64
)

// -----------------------------------------------------------------------------
// Data Structures for Challenges & Submissions
// -----------------------------------------------------------------------------

// Challenge represents a single challenge/assessment with an associated
// RenderFunc for displaying the challenge, and an AssessFunc that
// evaluates submissions (synchronously or asynchronously).
type Challenge struct {
	ID               uint64
	Title            string
	Owner            std.Address // creator's address
	PassingThreshold uint64      // e.g. 80 means score >= 80 passes
	Active           bool

	// RenderFunc returns a Markdown description of the challenge.
	RenderFunc func(string) string

	// AssessFunc is a function to compute the challenge result.
	//   - challengeID: the challenge's ID
	//   - submitter: the address of the person submitting
	//   - submission: the submitted answer/content (or its checksum)
	//   - asyncKey: used to identify an async submission if needed
	// Returns:
	//   - grade (uint64): a percentage score
	//   - passed (bool): whether the submission is passing
	//   - additional (string): free-form text for extra context/feedback
	AssessFunc func(challengeID uint64, submitter std.Address, submission string, asyncKey string) (grade uint64, passed bool, additional string)

	// If true, grading is performed asynchronously.
	IsAsync bool
}

// Submission represents an individual's submitted answer for a challenge.
type Submission struct {
	ID          uint64
	ChallengeID uint64
	Submitter   std.Address
	Timestamp   int64
	ContentHash string // a checksum or reference
	Score       uint64 // percentage score
	Passed      bool
	Additional  string // extra grading info
	IsGraded    bool   // false if grading is pending
}

// -----------------------------------------------------------------------------
// Record Types
// -----------------------------------------------------------------------------

// ChallengeRecord wraps a Challenge to implement btree.Record.
type ChallengeRecord struct {
	ID uint64
	Ch *Challenge
}

// Less implements the btree.Record interface for ChallengeRecord.
func (cr ChallengeRecord) Less(than btree.Record) bool {
	other := than.(ChallengeRecord)
	return cr.ID < other.ID
}

// SubmissionRecord wraps a Submission to implement btree.Record.
type SubmissionRecord struct {
	ID  uint64
	Sub *Submission
}

// Less implements the btree.Record interface for SubmissionRecord.
func (sr SubmissionRecord) Less(than btree.Record) bool {
	other := than.(SubmissionRecord)
	return sr.ID < other.ID
}

// -----------------------------------------------------------------------------
// Global Variables
// -----------------------------------------------------------------------------

var (
	challenges       map[uint64]Challenge
	submissions      map[uint64]Submission
	roles            map[std.Address]uint
	nextChallengeID  uint64
	nextSubmissionID uint64
	challengesTree   *btree.BTree
	submissionsTree  *btree.BTree
)

// -----------------------------------------------------------------------------
// Lookup Helpers
// -----------------------------------------------------------------------------

// getChallengeByID retrieves a Challenge object from the challengesTree given a numeric ID.
func getChallengeByID(id uint64) *Challenge {
	rec := challengesTree.Get(ChallengeRecord{ID: id})
	if rec == nil {
		return nil
	}
	return rec.(ChallengeRecord).Ch
}

// getSubmissionByID retrieves a Submission object from the submissionsTree given a numeric ID.
func getSubmissionByID(id uint64) *Submission {
	rec := submissionsTree.Get(SubmissionRecord{ID: id})
	if rec == nil {
		return nil
	}
	return rec.(SubmissionRecord).Sub
}

// -----------------------------------------------------------------------------
// Original function implementations (will be used as defaults)
// -----------------------------------------------------------------------------

// hasRole checks if a given address has the provided role bit set.
func hasRole(addr std.Address, role uint) bool {
	r, ok := roles[addr]
	if !ok {
		return false
	}
	return (r & role) == role
}

// requireRole panics if the caller does not have the specified role.
func requireRole(caller std.Address, role uint) {
	hasRoleFn := hasRoleFunc.Get().(func(std.Address, uint) bool)
	if !hasRoleFn(caller, role) {
		panic("insufficient permissions")
	}
}

// grantRole grants a bit-flag role to a given address.
func grantRole(addr std.Address, role uint) {
	caller := std.OriginCaller()
	hasRoleFn := hasRoleFunc.Get().(func(std.Address, uint) bool)
	requireRoleFn := requireRoleFunc.Get().(func(std.Address, uint))

	if role == ROLE_SUPERUSER {
		requireRoleFn(caller, ROLE_SUPERUSER)
	} else {
		if !hasRoleFn(caller, ROLE_SUPERUSER) && !hasRoleFn(caller, ROLE_ADMIN) {
			panic("must be admin or superuser to grant roles")
		}
	}
	roles[addr] = roles[addr] | role
}

// revokeRole removes a bit-flag role from a given address.
func revokeRole(addr std.Address, role uint) {
	caller := std.OriginCaller()
	hasRoleFn := hasRoleFunc.Get().(func(std.Address, uint) bool)
	requireRoleFn := requireRoleFunc.Get().(func(std.Address, uint))

	if role == ROLE_SUPERUSER {
		requireRoleFn(caller, ROLE_SUPERUSER)
	} else {
		if !hasRoleFn(caller, ROLE_SUPERUSER) && !hasRoleFn(caller, ROLE_ADMIN) {
			panic("must be admin or superuser to revoke roles")
		}
	}
	current := roles[addr]
	roles[addr] = current &^ role
}

// createChallenge inserts a new challenge record.
func createChallenge(
	title string,
	passingThreshold uint64,
	renderFunc func(string) string,
	assessFunc func(challengeID uint64, submitter std.Address, submission string, asyncKey string) (grade uint64, passed bool, additional string),
	isAsync bool,
) uint64 {
	caller := std.OriginCaller()
	hasRoleFn := hasRoleFunc.Get().(func(std.Address, uint) bool)

	if !(hasRoleFn(caller, ROLE_EDITOR) || hasRoleFn(caller, ROLE_ADMIN) || hasRoleFn(caller, ROLE_SUPERUSER)) {
		panic("must have editor/admin/superuser role to create challenge")
	}
	nextChallengeID++
	cid := nextChallengeID

	ch := &Challenge{
		ID:               cid,
		Title:            title,
		Owner:            caller,
		PassingThreshold: passingThreshold,
		Active:           true,
		RenderFunc:       renderFunc,
		AssessFunc:       assessFunc,
		IsAsync:          isAsync,
	}
	challengesTree.Insert(ChallengeRecord{ID: cid, Ch: ch})
	return cid
}

// submitAnswer creates a new Submission record.
func submitAnswer(challengeID uint64, contentHash string) uint64 {
	caller := std.OriginCaller()
	ch := getChallengeByID(challengeID)
	if ch == nil {
		panic("challenge not found")
	}
	if !ch.Active {
		panic("challenge is not active")
	}

	timestampFn := getTimestampFunc.Get().(func() int64)

	nextSubmissionID++
	sid := nextSubmissionID

	sub := &Submission{
		ID:          sid,
		ChallengeID: challengeID,
		Submitter:   caller,
		Timestamp:   timestampFn(),
		ContentHash: contentHash,
	}
	submissionsTree.Insert(SubmissionRecord{ID: sid, Sub: sub})

	// For synchronous challenges, do immediate grading.
	if !ch.IsAsync {
		doAssessmentFn := doAssessmentFunc.Get().(func(*Submission))
		doAssessmentFn(sub)
	}
	return sid
}

// doAssessment uses a challenge's AssessFunc.
func doAssessment(sub *Submission) {
	ch := getChallengeByID(sub.ChallengeID)
	if ch == nil {
		panic("challenge not found")
	}
	if ch.AssessFunc != nil {
		grade, passed, additional := ch.AssessFunc(ch.ID, sub.Submitter, sub.ContentHash, "")
		sub.Score = grade
		sub.Passed = passed
		sub.Additional = additional
	} else {
		// Default dummy logic if no assessment function is provided.
		sub.Score = 80
		if sub.Score >= ch.PassingThreshold {
			sub.Passed = true
		} else {
			sub.Passed = false
		}
		sub.Additional = "Synchronous grading complete (default)"
	}
	sub.IsGraded = true
}

// asyncResultCallback finalizes grading.
func asyncResultCallback(submissionID uint64, score uint64, passed bool, info string) {
	caller := std.OriginCaller()
	hasRoleFn := hasRoleFunc.Get().(func(std.Address, uint) bool)

	if !hasRoleFn(caller, ROLE_ADMIN) && !hasRoleFn(caller, ROLE_SUPERUSER) {
		panic("not authorized to finalize asynchronous result")
	}
	sub := getSubmissionByID(submissionID)
	if sub == nil {
		panic("submission not found")
	}
	if sub.IsGraded {
		panic("already graded")
	}
	sub.Score = score
	sub.Passed = passed
	sub.Additional = info
	sub.IsGraded = true
}

// queryMySubmissions returns caller's submissions.
func queryMySubmissions() []*Submission {
	caller := std.OriginCaller()
	var results []*Submission
	submissionsTree.Ascend(func(r btree.Record) bool {
		sr := r.(SubmissionRecord)
		if sr.Sub.Submitter == caller {
			results = append(results, sr.Sub)
		}
		return true
	})
	return results
}

// querySubmission retrieves a submission by ID.
func querySubmission(submissionID uint64) *Submission {
	caller := std.OriginCaller()
	hasRoleFn := hasRoleFunc.Get().(func(std.Address, uint) bool)

	sub := getSubmissionByID(submissionID)
	if sub == nil {
		panic("submission not found")
	}
	if sub.Submitter == caller ||
		hasRoleFn(caller, ROLE_VIEWER) ||
		hasRoleFn(caller, ROLE_ADMIN) ||
		hasRoleFn(caller, ROLE_SUPERUSER) {
		return sub
	}
	panic("not authorized to view this submission")
}

// queryAllSubmissions returns all submissions.
func queryAllSubmissions() []*Submission {
	caller := std.OriginCaller()
	hasRoleFn := hasRoleFunc.Get().(func(std.Address, uint) bool)

	if !(hasRoleFn(caller, ROLE_VIEWER) || hasRoleFn(caller, ROLE_ADMIN) || hasRoleFn(caller, ROLE_SUPERUSER)) {
		panic("not authorized to view all submissions")
	}
	var results []*Submission
	submissionsTree.Ascend(func(r btree.Record) bool {
		sr := r.(SubmissionRecord)
		results = append(results, sr.Sub)
		return true
	})
	return results
}

// queryChallengeSubmissions returns submissions for a challenge.
func queryChallengeSubmissions(challengeID uint64) []*Submission {
	caller := std.OriginCaller()
	hasRoleFn := hasRoleFunc.Get().(func(std.Address, uint) bool)

	ch := getChallengeByID(challengeID)
	if ch == nil {
		panic("challenge not found")
	}
	var results []*Submission
	submissionsTree.Ascend(func(r btree.Record) bool {
		sr := r.(SubmissionRecord)
		if sr.Sub.ChallengeID == challengeID {
			if ch.Owner == caller ||
				hasRoleFn(caller, ROLE_VIEWER) ||
				hasRoleFn(caller, ROLE_ADMIN) ||
				hasRoleFn(caller, ROLE_SUPERUSER) {
				results = append(results, sr.Sub)
			} else if sr.Sub.Submitter == caller {
				results = append(results, sr.Sub)
			}
		}
		return true
	})
	return results
}

// queryAllChallenges returns all challenges.
func queryAllChallenges() []*Challenge {
	var all []*Challenge
	challengesTree.Ascend(func(r btree.Record) bool {
		cr := r.(ChallengeRecord)
		all = append(all, cr.Ch)
		return true
	})
	return all
}

// renderImpl renders the challenges realm.
func renderImpl(path string) string {
	if path == "" {
		var sb strings.Builder
		sb.WriteString("# Available Challenges\n\n")

		// Add some introductory text
		sb.WriteString("Welcome to the Gno.land Coding Challenges! Select a challenge below to test your skills.\n\n")

		// Create a better formatted list with links
		challengesTree.Ascend(func(r btree.Record) bool {
			cr := r.(ChallengeRecord)
			// Create a styled challenge card with link
			// TODO: There is a way to dynamically get the package path, right?
			sb.WriteString(ufmt.Sprintf("## [%s](/r/challenges:%d)\n\n", cr.Ch.Title, cr.ID))

			// Show status (active or inactive)
			if cr.Ch.Active {
				sb.WriteString("**Status:** 🟢 Active\n\n")
			} else {
				sb.WriteString("**Status:** ⚪ Inactive\n\n")
			}

			// Show passing threshold
			sb.WriteString(ufmt.Sprintf("**Passing Threshold:** %d%%\n\n", cr.Ch.PassingThreshold))

			// Add async indicator if applicable
			if cr.Ch.IsAsync {
				sb.WriteString("**Grading:** Asynchronous evaluation\n\n")
			} else {
				sb.WriteString("**Grading:** Immediate evaluation\n\n")
			}

			// Add a "Start Challenge" link
			sb.WriteString(ufmt.Sprintf("[Start Challenge →](/r/challenges:%d)\n\n", cr.ID))

			// Add a divider between challenges
			sb.WriteString("---\n\n")

			return true
		})

		return sb.String()
	} else {
		id, err := strconv.ParseUint(path, 10, 64)
		if err != nil {
			return ufmt.Sprintf("Challenge with ID %s not found.", path)
		}

		ch := getChallengeByID(id)
		if ch == nil {
			return ufmt.Sprintf("Challenge with ID %d not found.", id)
		}

		// Create a detailed challenge view with back navigation
		var detailPage strings.Builder

		// Add back navigation
		detailPage.WriteString("← [Back to All Challenges](/r/challenges)\n\n")

		// Add challenge metadata header before the main content
		detailPage.WriteString(ufmt.Sprintf("# %s\n\n", ch.Title))

		if ch.Active {
			detailPage.WriteString("**Status:** 🟢 Active | ")
		} else {
			detailPage.WriteString("**Status:** ⚪ Inactive | ")
		}

		detailPage.WriteString(ufmt.Sprintf("**Passing Threshold:** %d%%", ch.PassingThreshold))

		if ch.IsAsync {
			detailPage.WriteString(" | **Grading:** Asynchronous\n\n")
		} else {
			detailPage.WriteString(" | **Grading:** Immediate\n\n")
		}

		// Add horizontal rule before actual challenge content
		detailPage.WriteString("---\n\n")

		// Add the challenge content from RenderFunc
		detailPage.WriteString(ch.RenderFunc(""))

		// Add submission form or instructions if not included in the challenge content
		if !strings.Contains(ch.RenderFunc(""), "## Submission") &&
			!strings.Contains(ch.RenderFunc(""), "# Submission") {
			detailPage.WriteString("\n\n## How to Submit\n\n")
			detailPage.WriteString("Enter your solution below and click 'Submit Answer' when ready.\n\n")
			detailPage.WriteString("```\n// Your solution here\n```\n\n")
			detailPage.WriteString("[Submit Answer](#) (submission functionality to be implemented)\n\n")
		}

		return detailPage.String()
	}
}

// getTimestamp returns the current Unix timestamp.
func getTimestamp() int64 {
	return time.Now().Unix()
}

// -----------------------------------------------------------------------------
// Public API Functions (These delegate to the upgradeable implementations)
// -----------------------------------------------------------------------------

// HasRole checks if a given address has the provided role bit set.
func HasRole(addr std.Address, role uint) bool {
	fn := hasRoleFunc.Get().(func(std.Address, uint) bool)
	return fn(addr, role)
}

// RequireRole panics if the caller does not have the specified role.
func RequireRole(caller std.Address, role uint) {
	fn := requireRoleFunc.Get().(func(std.Address, uint))
	fn(caller, role)
}

// GrantRole grants a bit-flag role to a given address.
func GrantRole(addr std.Address, role uint) {
	fn := grantRoleFunc.Get().(func(std.Address, uint))
	fn(addr, role)
}

// RevokeRole removes a bit-flag role from a given address.
func RevokeRole(addr std.Address, role uint) {
	fn := revokeRoleFunc.Get().(func(std.Address, uint))
	fn(addr, role)
}

// CreateChallenge inserts a new challenge record.
func CreateChallenge(
	title string,
	passingThreshold uint64,
	renderFunc func(string) string,
	assessFunc func(challengeID uint64, submitter std.Address, submission string, asyncKey string) (grade uint64, passed bool, additional string),
	isAsync bool,
) uint64 {
	fn := createChallengeFunc.Get().(func(
		string,
		uint64,
		func(string) string,
		func(challengeID uint64, submitter std.Address, submission string, asyncKey string) (grade uint64, passed bool, additional string),
		bool,
	) uint64)
	return fn(title, passingThreshold, renderFunc, assessFunc, isAsync)
}

// SubmitAnswer creates a new Submission record.
func SubmitAnswer(challengeID uint64, contentHash string) uint64 {
	fn := submitAnswerFunc.Get().(func(uint64, string) uint64)
	return fn(challengeID, contentHash)
}

// AsyncResultCallback finalizes grading.
func AsyncResultCallback(submissionID uint64, score uint64, passed bool, info string) {
	fn := asyncResultCallbackFunc.Get().(func(uint64, uint64, bool, string))
	fn(submissionID, score, passed, info)
}

// QueryMySubmissions returns caller's submissions.
func QueryMySubmissions() []*Submission {
	fn := queryMySubmissionsFunc.Get().(func() []*Submission)
	return fn()
}

// QuerySubmission retrieves a submission by ID.
func QuerySubmission(submissionID uint64) *Submission {
	fn := querySubmissionFunc.Get().(func(uint64) *Submission)
	return fn(submissionID)
}

// QueryAllSubmissions returns all submissions.
func QueryAllSubmissions() []*Submission {
	fn := queryAllSubmissionsFunc.Get().(func() []*Submission)
	return fn()
}

// QueryChallengeSubmissions returns submissions for a challenge.
func QueryChallengeSubmissions(challengeID uint64) []*Submission {
	fn := queryAllSubmissionsFunc.Get().(func() []*Submission)
	return fn()
}

// QueryAllChallenges returns all challenges.
func QueryAllChallenges() []*Challenge {
	fn := queryAllChallengesFunc.Get().(func() []*Challenge)
	return fn()
}

// Render renders the challenges realm.
func Render(path string) string {
	fn := renderFunc.Get().(func(string) string)
	return fn(path)
}

// GetTimestamp returns the current Unix timestamp.
func GetTimestamp() int64 {
	fn := getTimestampFunc.Get().(func() int64)
	return fn()
}

// -----------------------------------------------------------------------------
// Upgradeability Admin Functions
// -----------------------------------------------------------------------------

// UpgradeHasRoleFunc upgrades the hasRole implementation
func UpgradeHasRoleFunc(newFunc func(std.Address, uint) bool) error {
	caller := std.OriginCaller()
	if !HasRole(caller, ROLE_SUPERUSER) {
		return upgradeable.ErrCallerNotAdmin
	}
	return hasRoleFunc.Update(newFunc)
}

// UpgradeRequireRoleFunc upgrades the requireRole implementation
func UpgradeRequireRoleFunc(newFunc func(std.Address, uint)) error {
	caller := std.OriginCaller()
	if !HasRole(caller, ROLE_SUPERUSER) {
		return upgradeable.ErrCallerNotAdmin
	}
	return requireRoleFunc.Update(newFunc)
}

// UpgradeGrantRoleFunc upgrades the grantRole implementation
func UpgradeGrantRoleFunc(newFunc func(std.Address, uint)) error {
	caller := std.OriginCaller()
	if !HasRole(caller, ROLE_SUPERUSER) {
		return upgradeable.ErrCallerNotAdmin
	}
	return grantRoleFunc.Update(newFunc)
}

// UpgradeRevokeRoleFunc upgrades the revokeRole implementation
func UpgradeRevokeRoleFunc(newFunc func(std.Address, uint)) error {
	caller := std.OriginCaller()
	if !HasRole(caller, ROLE_SUPERUSER) {
		return upgradeable.ErrCallerNotAdmin
	}
	return revokeRoleFunc.Update(newFunc)
}

// UpgradeCreateChallengeFunc upgrades the createChallenge implementation
func UpgradeCreateChallengeFunc(newFunc func(
	string,
	uint64,
	func(string) string,
	func(challengeID uint64, submitter std.Address, submission string, asyncKey string) (grade uint64, passed bool, additional string),
	bool,
) uint64) error {
	caller := std.OriginCaller()
	if !HasRole(caller, ROLE_SUPERUSER) {
		return upgradeable.ErrCallerNotAdmin
	}
	return createChallengeFunc.Update(newFunc)
}

// UpgradeSubmitAnswerFunc upgrades the submitAnswer implementation
func UpgradeSubmitAnswerFunc(newFunc func(uint64, string) uint64) error {
	caller := std.OriginCaller()
	if !HasRole(caller, ROLE_SUPERUSER) {
		return upgradeable.ErrCallerNotAdmin
	}
	return submitAnswerFunc.Update(newFunc)
}

// UpgradeDoAssessmentFunc upgrades the doAssessment implementation
func UpgradeDoAssessmentFunc(newFunc func(*Submission)) error {
	caller := std.OriginCaller()
	if !HasRole(caller, ROLE_SUPERUSER) {
		return upgradeable.ErrCallerNotAdmin
	}
	return doAssessmentFunc.Update(newFunc)
}

// UpgradeAsyncResultCallbackFunc upgrades the asyncResultCallback implementation
func UpgradeAsyncResultCallbackFunc(newFunc func(uint64, uint64, bool, string)) error {
	caller := std.OriginCaller()
	if !HasRole(caller, ROLE_SUPERUSER) {
		return upgradeable.ErrCallerNotAdmin
	}
	return asyncResultCallbackFunc.Update(newFunc)
}

// UpgradeQueryMySubmissionsFunc upgrades the queryMySubmissions implementation
func UpgradeQueryMySubmissionsFunc(newFunc func() []*Submission) error {
	caller := std.OriginCaller()
	if !HasRole(caller, ROLE_SUPERUSER) {
		return upgradeable.ErrCallerNotAdmin
	}
	return queryMySubmissionsFunc.Update(newFunc)
}

// UpgradeQuerySubmissionFunc upgrades the querySubmission implementation
func UpgradeQuerySubmissionFunc(newFunc func(uint64) *Submission) error {
	caller := std.OriginCaller()
	if !HasRole(caller, ROLE_SUPERUSER) {
		return upgradeable.ErrCallerNotAdmin
	}
	return querySubmissionFunc.Update(newFunc)
}

// UpgradeQueryAllSubmissionsFunc upgrades the queryAllSubmissions implementation
func UpgradeQueryAllSubmissionsFunc(newFunc func() []*Submission) error {
	caller := std.OriginCaller()
	if !HasRole(caller, ROLE_SUPERUSER) {
		return upgradeable.ErrCallerNotAdmin
	}
	return queryAllSubmissionsFunc.Update(newFunc)
}

// UpgradeQueryAllChallengesFunc upgrades the queryAllChallenges implementation
func UpgradeQueryAllChallengesFunc(newFunc func() []*Challenge) error {
	caller := std.OriginCaller()
	if !HasRole(caller, ROLE_SUPERUSER) {
		return upgradeable.ErrCallerNotAdmin
	}
	return queryAllChallengesFunc.Update(newFunc)
}

// UpgradeRenderFunc upgrades the render implementation
func UpgradeRenderFunc(newFunc func(...interface{}) string) error {
	caller := std.OriginCaller()
	if !HasRole(caller, ROLE_SUPERUSER) {
		return upgradeable.ErrCallerNotAdmin
	}
	return renderFunc.Update(newFunc)
}

// UpgradeGetTimestampFunc upgrades the getTimestamp implementation
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

// init() initializes the realm after deployment. It sets the caller as a
// SUPERUSER, and sets up the global data structures. This is intended to be
// called only once.
func init() string {
	r := "registration-start; "
	challenges = make(map[uint64]Challenge)
	submissions = make(map[uint64]Submission)
	roles = make(map[std.Address]uint)
	nextChallengeID = 1
	nextSubmissionID = 1
	challengesTree = btree.New()
	submissionsTree = btree.New()

	creator := std.OriginCaller()
	roles[creator] = ROLE_SUPERUSER

	// Initialize the registry
	registry = upgradeable.NewWithAddress(creator)

	// Initialize all function holders with default implementations
	hasRoleFunc = upgradeable.NewFunctionHolder(
		registry,
		"hasRole",
		hasRole,
	)

	requireRoleFunc = upgradeable.NewFunctionHolder(
		registry,
		"requireRole",
		requireRole,
	)

	grantRoleFunc = upgradeable.NewFunctionHolder(
		registry,
		"grantRole",
		grantRole,
	)

	revokeRoleFunc = upgradeable.NewFunctionHolder(
		registry,
		"revokeRole",
		revokeRole,
	)

	createChallengeFunc = upgradeable.NewFunctionHolder(
		registry,
		"createChallenge",
		createChallenge,
	)

	submitAnswerFunc = upgradeable.NewFunctionHolder(
		registry,
		"submitAnswer",
		submitAnswer,
	)

	doAssessmentFunc = upgradeable.NewFunctionHolder(
		registry,
		"doAssessment",
		doAssessment,
	)

	asyncResultCallbackFunc = upgradeable.NewFunctionHolder(
		registry,
		"asyncResultCallback",
		asyncResultCallback,
	)

	queryMySubmissionsFunc = upgradeable.NewFunctionHolder(
		registry,
		"queryMySubmissions",
		queryMySubmissions,
	)

	querySubmissionFunc = upgradeable.NewFunctionHolder(
		registry,
		"querySubmission",
		querySubmission,
	)

	queryAllSubmissionsFunc = upgradeable.NewFunctionHolder(
		registry,
		"queryAllSubmissions",
		queryAllSubmissions,
	)

	queryAllChallengesFunc = upgradeable.NewFunctionHolder(
		registry,
		"queryAllChallenges",
		queryAllChallenges,
	)

	renderFunc = upgradeable.NewFunctionHolder(
		registry,
		"render",
		renderImpl,
	)

	getTimestampFunc = upgradeable.NewFunctionHolder(
		registry,
		"getTimestamp",
		getTimestamp,
	)
	r = r + "registration finished;"
	return r
}
