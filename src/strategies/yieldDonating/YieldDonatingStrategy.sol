// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {BaseStrategy} from "@octant-core/core/BaseStrategy.sol";
import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title YieldDonating Strategy Template (ERC-4626)
 * @author Octant (Modified for ERC-4626)
 * @notice Template for creating YieldDonating strategies that mint profits to donationAddress
 * @dev This strategy template works with the TokenizedStrategy pattern where
 * initialization and management functions are handled by a separate contract.
 * The strategy focuses on the core yield generation logic.
 *
 * NOTE: To implement permissioned functions you can use the onlyManagement,
 * onlyEmergencyAuthorized and onlyKeepers modifiers
 */
contract YieldDonatingStrategy is BaseStrategy {
    using SafeERC20 for ERC20;

    uint256 public minIdleToTend = 100 * 1e6; // Example: 100 USDC (set to your asset's decimals)

    /// @notice Address of the yield source (e.g., any ERC-4626 compliant vault)
    IERC4626 public immutable vault;

    /**
     * @param _vault Address of the ERC-4626 vault
     * @param _asset Address of the underlying asset
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

        // max allow Vault to withdraw assets from this strategy
        ERC20(_asset).forceApprove(_vault, type(uint256).max);

        // TokenizedStrategy initialization will be handled separately
    }

    // (In _harvestAndReport)
    function _harvestAndReport() internal view override returns (uint256 _totalAssets) {
        uint256 idleAssets = IERC20(asset).balanceOf(address(this));
        uint256 sharesHeld = vault.balanceOf(address(this));
        uint256 vaultAssets = vault.convertToAssets(sharesHeld);

        _totalAssets = idleAssets + vaultAssets;

        return _totalAssets;
    }

    function _deployFunds(uint256 _amount) internal override {
        // Do nothing to prevent MEV.
        // Funds will be deployed by _tend or _harvestAndReport.
    }

    function _tend(uint256 _totalIdle) internal virtual override {
        require(_totalIdle >= minIdleToTend);
        vault.deposit(_totalIdle, address(this));
        // if (_totalIdle >= minIdleToTend) {
        // vault.deposit(_totalIdle, address(this));
        // }
    }

    function _tendTrigger() internal view virtual override returns (bool) {
        uint256 idleAssets = IERC20(asset).balanceOf(address(this));
        return idleAssets >= minIdleToTend;
    }

    function setMinIdleToTend(uint256 _newMin) external onlyManagement {
        minIdleToTend = _newMin;
    }

    /**
     * @dev Frees '_amount' of 'asset' from the ERC-4626 vault.
     * @dev This is now defensive, withdrawing only up to the vault's
     * actual balance to prevent "withdraw more than max" errors.
     */
    function _freeFunds(uint256 _amount) internal override {
        // 1. Get the strategy's total share balance in the vault
        uint256 sharesHeld = vault.balanceOf(address(this));
        if (sharesHeld == 0) {
            return; // Nothing to withdraw
        }

        // find the actual asset value of those shares
        uint256 assetsInVault = vault.convertToAssets(sharesHeld);

        // determine the amount to withdraw:
        // it's the SMALLER of the amount requested OR what we actually have.
        uint256 amountToWithdraw = Math.min(_amount, assetsInVault);

        // 4. (Even safer) Also respect the vault's maxWithdraw limit.
        //    This handles cases where the vault is illiquid.
        uint256 maxVaultWithdraw = vault.maxWithdraw(address(this));
        amountToWithdraw = Math.min(amountToWithdraw, maxVaultWithdraw);

        if (amountToWithdraw > 0) {
            // Use standard ERC-4626 withdraw
            // We are the owner of the shares and the receiver of the assets
            vault.withdraw(amountToWithdraw, address(this), address(this));
        }
    }

    /**
     * @dev Frees funds during an emergency shutdown.
     */
    function _emergencyWithdraw(uint256 _amount) internal virtual override {
        // This now safely handles _amount = type(uint256).max
        _freeFunds(_amount);
    }

    /*//////////////////////////////////////////////////////////////
              OPTIONAL TO OVERRIDE BY STRATEGIST
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Gets the max amount of `asset` that can be withdrawn.
     */
    function availableWithdrawLimit(address) public view virtual override returns (uint256) {
        // Calculate total assets = idle + value held in vault
        uint256 idleBalance = IERC20(asset).balanceOf(address(this));

        uint256 sharesHeld = vault.balanceOf(address(this));
        uint256 vaultAssets = vault.convertToAssets(sharesHeld);

        return idleBalance + vaultAssets;
    }

    /**
     * @notice Gets the max amount of `asset` that can be deposited.
     */
    function availableDepositLimit(address) public view virtual override returns (uint256) {
        return type(uint256).max;
    }
}
