// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "./AnswerLib.sol";
import "./AbstractCertification.sol";

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract Certification is
    AbstractCertification,
    Initializable,
    ERC1155Upgradeable,
    AccessControlUpgradeable,
    ERC1155PausableUpgradeable,
    ERC1155BurnableUpgradeable,
    ERC1155SupplyUpgradeable,
    UUPSUpgradeable
{
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        //_disableInitializers();
    }

    function initialize(
        address defaultAdmin,
        address pauser,
        address minter,
        address upgrader
    ) public initializer {
        __ERC1155_init("");
        __AccessControl_init();
        __ERC1155Pausable_init();
        __ERC1155Burnable_init();
        __ERC1155Supply_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(PAUSER_ROLE, pauser);
        _grantRole(MINTER_ROLE, minter);
        _grantRole(UPGRADER_ROLE, upgrader);
    }

    function setURI(string memory newuri) public onlyRole(URI_SETTER_ROLE) {
        _setURI(newuri);
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(UPGRADER_ROLE) {}

    // The following functions are overrides required by Solidity.

    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    )
        internal
        override(
            ERC1155Upgradeable,
            ERC1155PausableUpgradeable,
            ERC1155SupplyUpgradeable
        )
    {
        super._update(from, to, ids, values);
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(ERC1155Upgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function mint(
        address account,
        uint256 id,
        uint256 amount,
        bytes memory data,
        string memory tokenName
    ) public onlyRole(MINTER_ROLE) {
        _mint(account, id, amount, data);
        setTokenName(id, tokenName);
    }

    function mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data,
        string[] memory tokenNamesArray
    ) public onlyRole(MINTER_ROLE) {
        require(
            ids.length == tokenNamesArray.length,
            "Token IDs and names must have the same length"
        );
        _mintBatch(to, ids, amounts, data);
        for (uint256 i = 0; i < ids.length; i++) {
            setTokenName(ids[i], tokenNamesArray[i]);
        }
    }

    function addChallenge(
        string memory _name,
        address _callbackContract,
        uint passing_grade
    ) public onlyRole(MINTER_ROLE) {
        IChallengeCallback callback = IChallengeCallback(_callbackContract);
        setChallenge(_name, Challenge(_name, callback, passing_grade, true));
    }

    event Debug(string msg, uint num);

    function completeChallenge(
        address account,
        string calldata challengeName,
        AnswerLib.Answer[] calldata input
    ) public returns (uint256) {
        emit Debug("start completeChallenge", 0);
        Challenge memory challenge = getChallenge(challengeName);
        if (!challenge.isActive) {
            emit Debug("challenge is not active", 0);
        }
        require(challenge.isActive, "Challenge not found");
        bool success = false;
        (uint correct, uint incorrect) = challenge.callback.calculateScore(
            challengeName,
            input
        );
        uint grade = AnswerLib.calculatePercentage(
            correct,
            (correct + incorrect)
        );

        emit Debug("Grade:", grade);
        emit Debug("Passing Grade:", challenge.passingGrade);

        if (grade > challenge.passingGrade) {
            success = true;
        }
        if (success) {
            emit Debug("success", 0);
            uint256 tokenId = totalSupply() + 1;
            string memory tokenName = string.concat(
                getAccountName(account),
                " - ",
                challengeName
            );

            emit Debug(tokenName, tokenId);
            // Mint the token and transfer it to the account
            mint(
                account,
                tokenId,
                1,
                abi.encodePacked(tokenName, grade),
                tokenName
            );
            emit Debug("minted", 0);
            return tokenId;
        } else {
            emit Debug("failed", 0);
            return 0;
        }
    }

    function getAllTokensAndInfoOfOwner(
        address owner
    )
        public
        view
        returns (
            uint256[] memory,
            uint256[] memory,
            string[] memory,
            string memory,
            string memory
        )
    {
        uint256[] memory tokenIds = new uint256[](totalSupply());
        uint256[] memory balances = new uint256[](totalSupply());
        string[] memory tokenNameArray = new string[](totalSupply());
        uint256 index = 0;
        for (uint256 i = 1; i <= totalSupply(); i++) {
            if (balanceOf(owner, i) > 0) {
                tokenIds[index] = i;
                balances[index] = balanceOf(owner, i);
                tokenNameArray[index] = getTokenName(i);
                index++;
            }
        }

        (string memory name, string memory email) = getAccountInfo(owner);

        return (tokenIds, balances, tokenNameArray, name, email);
    }
}
