// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {BaseStrategy} from "@octant-core/core/BaseStrategy.sol";
import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract YieldDonatingStrategy is BaseStrategy {
    using SafeERC20 for ERC20;

    /// @notice Address of the Spark ERC-4626 vault (e.g., spUSDC)
    IERC4626 public immutable vault;

    /**
     * @param _vault Address of the Spark ERC-4626 vault (e.g., spUSDC)
     * @param _asset Address of the underlying asset (e.g., USDC)
     * @param _name Strategy name
     * @param _management Address with management role
     * @param _keeper Address with keeper role
     * @param _emergencyAdmin Address with emergency admin role
     * @param _donationAddress Address that receives donated/minted yield
     * @param _enableBurning Whether loss-protection burning from donation address is enabled
     * @param _tokenizedStrategyAddress Address of TokenizedStrategy implementation
     */
    constructor(
        address _vault,
        address _asset,
        string memory _name,
        address _management,
        address _keeper,
        address _emergencyAdmin,
        address _donationAddress,
        bool _enableBurning,
        address _tokenizedStrategyAddress
    )
        BaseStrategy(
            _asset,
            _name,
            _management,
            _keeper,
            _emergencyAdmin,
            _donationAddress,
            _enableBurning,
            _tokenizedStrategyAddress
        )
    {
        vault = IERC4626(_vault);

        // Verify the vault's underlying asset matches the strategy's asset
        require(vault.asset() == _asset, "Asset mismatch with vault");

        // max allow Vault to withdraw assets
        ERC20(_asset).forceApprove(_vault, type(uint256).max);
    }

    /*//////////////////////////////////////////////////////////////
                NEEDED TO BE OVERRIDDEN BY STRATEGIST
    //////////////////////////////////////////////////////////////*/

    function _deployFunds(uint256 amount) internal override {
        vault.deposit(amount, address(this));
    }

    /**
     * @dev Frees '_amount' of 'asset' from the Spark vault.
     * @dev This function is defensive and will only withdraw up to the
     * amount available in the vault to prevent reverts.
     */
    function _freeFunds(uint256 _amount) internal override {
        uint256 sharesHeld = vault.balanceOf(address(this));
        if (sharesHeld == 0) {
            return; // Nothing to withdraw
        }

        uint256 assetsInVault = vault.convertToAssets(sharesHeld);

        // Determine the amount to withdraw:
        // It's the SMALLER of the amount requested OR what we actually have.
        uint256 amountToWithdraw = Math.min(_amount, assetsInVault);

        // Also respect the vault's maxWithdraw limit.
        // This handles cases where the vault is illiquid.
        uint256 maxVaultWithdraw = vault.maxWithdraw(address(this));
        amountToWithdraw = Math.min(amountToWithdraw, maxVaultWithdraw);

        if (amountToWithdraw > 0) {
            // Use standard ERC-4626 withdraw
            vault.withdraw(amountToWithdraw, address(this), address(this));
        }
    }

    /**
     * @dev Calculates the total assets managed by the strategy.
     * @dev Does NOT redeploy idle funds; this is handled by _tend().
     * @return _totalAssets A trusted and accurate account for the total
     * 'asset' the strategy currently holds (idle + vaulted).
     */
    function _harvestAndReport() internal override returns (uint256 _totalAssets) {
        // Calculate idle assets (assets held by this strategy contract)
        uint256 idleAssets = IERC20(asset).balanceOf(address(this));

        // Calculate assets deposited in the vault
        uint256 sharesHeld = vault.balanceOf(address(this));
        uint256 vaultAssets = vault.convertToAssets(sharesHeld);

        // Report total assets (idle + vaulted)
        // The BaseStrategy will use this to calculate profit.
        _totalAssets = idleAssets + vaultAssets;

        return _totalAssets;
    }

    /*//////////////////////////////////////////////////////////////
                OPTIONAL TO OVERRIDE BY STRATEGIST
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Gets the max amount of `asset` that can be withdrawn.
     */
    function availableWithdrawLimit(address owner) public view virtual override returns (uint256) {
        // Calculate total assets = idle + value held in vault
        uint256 idleBalance = IERC20(asset).balanceOf(address(this));

        uint256 sharesHeld = vault.balanceOf(address(this));
        uint256 vaultAssets = vault.convertToAssets(sharesHeld);

        return idleBalance + vaultAssets;
    }

    /**
     * @notice Gets the max amount of `asset` that can be deposited.
     * @dev Queries the Spark vault's maxDeposit limit.
     */
    function availableDepositLimit(address owner) public view virtual override returns (uint256) {
        return vault.maxDeposit(address(this));
    }

    /**
     * @dev Frees funds during an emergency shutdown.
     */
    function _emergencyWithdraw(uint256 _amount) internal virtual override {
        // Calls our robust _freeFunds function
        _freeFunds(_amount);
    }
}
