// SPDX-License-Identifier: MIT

// © 2024 https://onchainpoints.xyz All Rights Reserved.

pragma solidity ^0.8.24;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./OnchainPoints.sol";

/**
 * @title SpendingDemo
 * @dev A contract for demo purposes to spend tokens using OnchainPoints
 */
contract SpendingDemo is Initializable, OwnableUpgradeable, ERC1155HolderUpgradeable, UUPSUpgradeable, ReentrancyGuardUpgradeable {

    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.Bytes32Set;

    address payable onchainPointsAddress;

    mapping(address => uint256) public userSpendings;
    mapping(address => uint256) public userBalance;
    
    event UserBalanceUpdated(address indexed user, uint256 amount);
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    receive() payable external {}

    /**
     * @dev Initializes the contract
     * @param initialOwner The address of the initial owner
     */
    function initialize(address initialOwner) initializer public {
        __Ownable_init(initialOwner);
        __ERC1155Holder_init();
        __UUPSUpgradeable_init();
    }

    /**
     * @dev Function to authorize upgrades, can only be called by the owner
     * @param newImplementation Address of the new implementation
     */
    function _authorizeUpgrade(address newImplementation)
        internal
        onlyOwner
        override
    {}

    /**
     * @dev Updates the address of the OnchainPoints contract
     * @param _onchainPointsAddress The address of the OnchainPoints contract
     */
    function updateOnchainPointsAddress(
        address _onchainPointsAddress
    ) external onlyOwner {
        onchainPointsAddress = payable(_onchainPointsAddress);
    }

    /**
     * @dev Spends tokens using a signature for spending tokens
     * @param request The spending request
     * @param signature The signature for the spending request
     */
    function spendTokensWithSignature(OnchainPoints.Request calldata request, bytes calldata signature) nonReentrant external {

        address spender = OnchainPoints(onchainPointsAddress).spendToken(request, signature);
        userBalance[spender] += request.amount;
        userSpendings[spender] += request.amount;

        emit UserBalanceUpdated(spender, userBalance[spender]);
    }

    /**
     * @dev Buys a position on behalf of another user using a signature for spending tokens
     * @param request The spending request
     * @param signature The signature for the spending request
     */
    function spendTokensWithSignatureOnBehalf(OnchainPoints.DelegatedRequest calldata request, bytes calldata signature) nonReentrant external {

        OnchainPoints(onchainPointsAddress).spendTokensOnBehalf(request, signature);

        address spender = request.owner;

        userBalance[spender] += request.amount;
        userSpendings[spender] += request.amount;
        emit UserBalanceUpdated(spender, userBalance[spender]);

    }

    /**
     * @dev Gets the available spending for a user
     * @param user The address of the user
     * @return The available spending for the user
     */
    function getAvailableSpending(address user) external view returns (uint256) {
        return OnchainPoints(onchainPointsAddress).getAvailableSpending(user);
    }

    /**
     * @dev Spends tokens using locked tokens and optionally unlocked tokens (ETH)
     * @param amount The amount of tokens to spend
     */
    function spendTokens(uint256 amount) external nonReentrant payable {
        
        address spender = msg.sender;

        uint256 userAvailableSpending = OnchainPoints(onchainPointsAddress).getAvailableSpending(spender);

        require(userAvailableSpending + msg.value >= amount, "Insufficient funds");

        uint256 unlockedTokensToSpend = 0;
        if (userAvailableSpending >= amount){
            OnchainPoints(onchainPointsAddress).spendTokenWithoutSignature(amount);
        } else {
            OnchainPoints(onchainPointsAddress).spendTokenWithoutSignature(userAvailableSpending);
            unlockedTokensToSpend = amount - userAvailableSpending;
        }

        userBalance[spender] += amount;
        userSpendings[spender] += amount;

        emit UserBalanceUpdated(spender, userBalance[spender]);

        // Return any excess ETH sent
        if (msg.value > unlockedTokensToSpend) {
            payable(spender).transfer(msg.value - unlockedTokensToSpend);
        }
    }
    
    /**
     * @dev Spends tokens on behalf of another user using locked tokens
     * @param owner The address of the user to spend tokens on behalf of
     * @param amount The amount of tokens to spend
     */
    function spendTokensOnBehalf(address owner, uint256 amount) external nonReentrant{
        
        address spender = owner;

        uint256 userAvailableSpending = OnchainPoints(onchainPointsAddress).getAvailableSpending(spender);

        require(userAvailableSpending >= amount, "Insufficient funds");

        OnchainPoints(onchainPointsAddress).spendTokensOnBehalfWithoutSignature(amount, owner);

        userBalance[spender] += amount;
        userSpendings[spender] += amount;
        emit UserBalanceUpdated(spender, userBalance[spender]);
    }

    /**
     * @dev Claims the balance of the user
     */
    function claimBalance() external nonReentrant {
        uint256 balance = userBalance[msg.sender];
        userBalance[msg.sender] = 0;
        payable(msg.sender).transfer(balance);
    }

    /**
     * @dev Emergency withdraw all balance
     */
    function emergencyWithdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }
}