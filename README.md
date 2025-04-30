# Gno Challenges Realm

This repository contains a Gno-based realm (`challenges.gno`) that facilitates the creation, management, and grading of challenges or assessments, alongside a queryable database of user submissions.

## Overview

- **Challenges**  
  Each challenge contains:
  - A `RenderFunc` to produce a Markdown description.
  - An `AssessFunc` to grade submissions (can be synchronous or asynchronous).
  - Configuration fields like `Title`, `Owner`, `PassingThreshold`, and `Active`.

- **Submissions**  
  Users submit answers (or content hashes) to a challenge. Submissions are recorded on-chain and can be automatically graded (sync) or later graded (async).

- **Roles & Permissions**  
  The system uses bit flags for roles:
  - `ROLE_SUPERUSER`
  - `ROLE_ADMIN`
  - `ROLE_EDITOR`
  - `ROLE_VIEWER`
  
  This controls who can create challenges, grant roles, view all submissions, finalize asynchronous grading, etc.

## Key Functions

### Initialization

- **`InitRealm()`**  
  Initializes the realm's data structures and grants the caller `ROLE_SUPERUSER`.

### Roles Management

- **`GrantRole(addr, roleBit)`**  
  Grants a specific role to an address. Caller must be `ADMIN` or `SUPERUSER` (only `SUPERUSER` can grant `ROLE_SUPERUSER`).

- **`RevokeRole(addr, roleBit)`**  
  Revokes a specific role from an address. Same permission requirements as granting roles.

### Challenges Management

- **`CreateChallenge(title, passingThreshold, renderFunc, assessFunc, isAsync)`**  
  Creates and registers a new challenge. Only `EDITOR`, `ADMIN`, or `SUPERUSER` can do this.

- **`QueryAllChallenges()`**  
  Returns a list of all challenges. No role restrictions.

> **TODO**: Future functions to update existing challenges or toggle activation status are noted but not yet implemented.

### Submission Lifecycle

- **`SubmitAnswer(challengeID, contentHash)`**  
  Creates a new submission for the given challenge. If the challenge is synchronous, grading is done immediately.

- **`AsyncResultCallback(submissionID, score, passed, info)`**  
  Finalizes asynchronous grading for a submission. Only `ADMIN` or `SUPERUSER` can call this.

### Querying Submissions

- **`QueryMySubmissions()`**  
  Returns all submissions by the caller.

- **`QuerySubmission(submissionID)`**  
  Retrieves a single submission if the caller is either the submitter or has at least `ROLE_VIEWER`.

- **`QueryAllSubmissions()`**  
  Returns all submissions, but only if the caller has `ROLE_VIEWER` or higher.

- **`QueryChallengeSubmissions(challengeID)`**  
  Returns all submissions associated with a given challenge. Visible to the challenge owner, submitters of their own submissions, or anyone with `ROLE_VIEWER`/`ADMIN`/`SUPERUSER`.

### Rendering

- **`Render()`**  
  Provides a Markdown-based view of the challenges.  
  - No arguments: List all challenges (ID and Title).  
  - Single argument (challenge ID): Render the full Markdown description of the challenge.

## Technical Details

The realm implements two main data structures:
- `challenges` and `submissions` maps
- B-tree indexes (`challengesTree` and `submissionsTree`) for efficient lookups and sorted traversal

## How to Deploy and Use

1. **Deploy**: Publish the `challenges.gno` realm on the Gno blockchain.
2. **Initialize**: Call `InitRealm()` once to set up the initial data structures. The deployer becomes `ROLE_SUPERUSER`.
3. **Grant Roles**: Use `GrantRole(addr, roleBit)` to give others access to challenge creation or administrative tasks.
4. **Create Challenges**: Call `CreateChallenge(...)` as an `EDITOR`, `ADMIN`, or `SUPERUSER`.
5. **Submit Answers**: Any user can call `SubmitAnswer(challengeID, contentHash)` to post a response.
6. **Grade Answers**: 
   - Synchronous: The answer is automatically graded.
   - Asynchronous: Use `AsyncResultCallback(submissionID, score, passed, info)` to finalize results.
7. **Query**: 
   - `QueryMySubmissions()` for personal submissions.
   - `QueryAllSubmissions()` if you have viewing rights.
   - `QueryChallengeSubmissions(challengeID)` to see all submissions for a challenge, if authorized.

## Contributing

- Fork the repository.
- Create a feature branch for your proposed changes.
- Submit a pull request with detailed information about your modifications.

## License

This project is licensed under the Apache 2.0 License - see the [LICENSE](LICENSE) file for details.
