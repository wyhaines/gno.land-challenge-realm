// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "./AnswerLib.sol";

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

abstract contract AbstractCertification {
    bytes32 public constant URI_SETTER_ROLE = keccak256("URI_SETTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    mapping(address => AccountInfo) private accountInfos;
    mapping(uint256 => string) private tokenNames;
    mapping(string => Challenge) private challenges;

    struct AccountInfo {
        string name;
        string email;
    }

    struct Challenge {
        string name;
        IChallengeCallback callback;
        uint passingGrade;
        bool isActive;
    }

    function setAccountInfo(
        address account,
        string calldata _name,
        string calldata _email
    ) external {
        accountInfos[account] = AccountInfo(_name, _email);
    }

    function setAccountInfo(
        string calldata _name,
        string calldata _email
    ) external {
        accountInfos[msg.sender] = AccountInfo(_name, _email);
    }

    function getAccountInfo(
        address _account
    ) public view returns (string memory, string memory) {
        return (accountInfos[_account].name, accountInfos[_account].email);
    }

    function getAccountName(
        address _account
    ) public view returns (string memory) {
        return accountInfos[_account].name;
    }

    function getAccountEmail(
        address _account
    ) public view returns (string memory) {
        return accountInfos[_account].email;
    }

    function getTokenName(
        uint256 _tokenId
    ) internal view returns (string memory) {
        return tokenNames[_tokenId];
    }

    function setTokenName(uint256 _tokenId, string memory _tokenName) internal {
        tokenNames[_tokenId] = _tokenName;
    }

    function getChallenge(
        string memory _challengeName
    ) internal view returns (Challenge storage) {
        return challenges[_challengeName];
    }

    function setChallenge(
        string memory _challengeName,
        Challenge memory _challenge
    ) internal {
        challenges[_challengeName] = _challenge;
    }
}
