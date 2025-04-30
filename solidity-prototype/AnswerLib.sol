// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library AnswerLib {
    struct Answer {
        bool exists;
        uint256 numberValue;
        string stringValue;
        bytes32 byteValue;
        bool boolValue;
    }

    // Example utility function to compare two Answer structs
    function areAnswersEqual(
        Answer memory a,
        Answer memory b
    ) internal pure returns (bool) {
        return
            a.exists == b.exists &&
            a.numberValue == b.numberValue &&
            keccak256(abi.encodePacked(a.stringValue)) ==
            keccak256(abi.encodePacked(b.stringValue)) &&
            a.byteValue == b.byteValue &&
            a.boolValue == b.boolValue;
    }

    function calculatePercentage(
        uint numerator,
        uint denominator,
        uint precision
    ) public pure returns (uint) {
        return
            ((numerator * 10000000000) / denominator) /
            (100000000 / (10 ** precision));
    }

    function calculatePercentage(
        uint numerator,
        uint denominator
    ) public pure returns (uint) {
        return calculatePercentage(numerator, denominator, 1);
    }
}
