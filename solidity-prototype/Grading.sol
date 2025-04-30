// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./AnswerLib.sol";

import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract CertificationGrading is
    Initializable,
    PausableUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable
{
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant ANSWER_KEY_ROLE = keccak256("ANSWER_KEY_ROLE"); // Role to manage answer key entries

    // Mapping from question ID to their corresponding answers
    mapping(string => AnswerLib.Answer[]) private answerKey;

    constructor() {
        //_disableInitializers();
    }

    function initialize(
        address defaultAdmin,
        address pauser,
        address upgrader
    ) public initializer {
        __Pausable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(PAUSER_ROLE, pauser);
        _grantRole(UPGRADER_ROLE, upgrader);
        _grantRole(ANSWER_KEY_ROLE, defaultAdmin); // Grant ANSWER_KEY_ROLE to the admin initially

        // Emit the initialization event
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function checkRole(bytes32 role) public view returns (bool) {
        return hasRole(role, msg.sender);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(UPGRADER_ROLE) {}

    // Role-based function to add or update an answer in the answer key
    function setAnswer(
        string calldata questionId,
        uint position,
        uint256 number,
        string calldata stringVal,
        bytes32 byteVal,
        bool boolVal
    ) external {
        require(
            hasRole(ANSWER_KEY_ROLE, msg.sender),
            "CertificationGrading: Must have ANSWER_KEY role to view answers"
        );

        // Ensure the array is large enough.
        if (answerKey[questionId].length <= position) {
            // Resize the array to accommodate the new index
            // This could be done by pushing empty elements until reaching the desired length
            while (answerKey[questionId].length <= position) {
                answerKey[questionId].push(); // Push a new, empty Answer
            }
        }
        answerKey[questionId][position] = AnswerLib.Answer(
            true,
            number,
            stringVal,
            byteVal,
            boolVal
        );
    }

    // Role-based function to set all of the answers in a single function call
    function setAnswers(
        string calldata questionId,
        AnswerLib.Answer[] calldata answers
    ) external onlyRole(ANSWER_KEY_ROLE) {
        delete answerKey[questionId];
        for (uint i = 0; i < answers.length; i++) {
            answerKey[questionId][i] = answers[i];
        }
    }

    // Role-based function to query the number of answers for a given questionId
    function answersLength(
        string calldata questionId
    ) public view returns (uint) {
        require(
            hasRole(ANSWER_KEY_ROLE, msg.sender),
            "CertificationGrading: Must have ANSWER_KEY role to view answers"
        );
        return answerKey[questionId].length;
    }

    // Role-based function to push an additional answer onto the stack of answers
    function pushAnswer(
        string calldata questionId,
        uint256 number,
        string calldata stringVal,
        bytes32 byteVal,
        bool boolVal
    ) external onlyRole(ANSWER_KEY_ROLE) {
        answerKey[questionId].push(
            AnswerLib.Answer(true, number, stringVal, byteVal, boolVal)
        );
    }

    // Role-based function to delete all answers from the answer key for a given questionId
    function deleteAnswer(
        string calldata questionId
    ) external onlyRole(ANSWER_KEY_ROLE) {
        delete answerKey[questionId];
    }

    // Role-based function to delete a single answer from the answer key
    function deleteAnswer(
        string calldata questionId,
        uint position
    ) external onlyRole(ANSWER_KEY_ROLE) {
        delete answerKey[questionId][position];
    }

    // Function to retrieve answer (view-only and not publicly accessible)
    function getAnswer(
        string calldata questionId,
        uint position
    ) public view returns (AnswerLib.Answer memory) {
        require(
            hasRole(ANSWER_KEY_ROLE, msg.sender),
            "CertificationGrading: Must have ANSWER_KEY role to view answers"
        );
        return answerKey[questionId][position];
    }

    // Function to get all answers (view-only and not publicly accessible)
    function getAnswers(
        string calldata questionId
    ) public view returns (AnswerLib.Answer[] memory) {
        require(
            hasRole(ANSWER_KEY_ROLE, msg.sender),
            "CertificationGrading: Must have ANSWER_KEY role to view answers"
        );
        return answerKey[questionId];
    }

    // Function to grade answers for a specific question
    function calculateScore(
        string calldata questionId,
        AnswerLib.Answer[] calldata providedAnswers
    ) external view returns (uint correctCount, uint incorrectCount) {
        AnswerLib.Answer[] storage correctAnswers = answerKey[questionId]; // Retrieve the correct answers from the answer key
        uint totalCount = providedAnswers.length;
        incorrectCount = 0; // Initialize the incorrect count

        // Loop over each provided answer and compare it with the stored correct answer
        for (uint i = 0; i < totalCount; i++) {
            if (
                i < correctAnswers.length &&
                AnswerLib.areAnswersEqual(providedAnswers[i], correctAnswers[i])
            ) {
                correctCount++;
            } else {
                incorrectCount++;
            }
        }

        return (correctCount, incorrectCount);
    }
}
