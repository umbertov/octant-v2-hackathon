// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {BaseStrategy} from "@octant-core/core/BaseStrategy.sol";
import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC6426} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
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

    /*//////////////////////////////////////////////////////////////
              NEEDED TO BE OVERRIDDEN BY STRATEGIST
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Deploys '_amount' of 'asset' into the ERC-4626 vault.
     */
    function _deployFunds(uint256 _amount) internal override {
        // Use standard ERC-4626 deposit
        vault.deposit(_amount, address(this));
    }

    /**
     * @dev Frees '_amount' of 'asset' from the ERC-4626 vault.
     */
    function _freeFunds(uint256 _amount) internal override {
        // Use standard ERC-4626 withdraw
        // We are the owner of the shares and the receiver of the assets
        vault.withdraw(_amount, address(this), address(this));
    }

    /**
     * @dev Internal function to harvest, redeploy idle funds, and report
     * total assets.
     */
    function _harvestAndReport() internal override returns (uint256 _totalAssets) {
        // This logic faithfully translates the original Aave-based implementation.
        // It reports the total assets *before* the new supply is factored in,
        // which is a common and correct pattern for profit calculation.

        // 1. Calculate idle assets (assets held by this strategy contract)
        uint256 idleAssets = IERC20(asset).balanceOf(address(this));

        // 2. Calculate assets deposited in the vault
        //    a. Get the number of shares this strategy holds
        uint256 sharesHeld = vault.balanceOf(address(this));
        //    b. Convert those shares to their underlying asset value
        uint256 vaultAssets = vault.convertToAssets(sharesHeld);

        // 3. If there are idle assets, deploy (compound) them
        if (idleAssets > 0) {
            vault.deposit(idleAssets, address(this));
        }

        // 4. Report total assets *before* the new deposit.
        //    The BaseStrategy will use this to calculate profit.
        //    (e.g., 100 idle + 1000 in vault = 1100 total.
        //    The 100 idle is compounded for the *next* period).
        _totalAssets = idleAssets + vaultAssets;

        return _totalAssets;
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

    // /**
    //  * @dev Optional function for strategist to override...
    //  */
    // function _tend(uint256 _totalIdle) internal virtual override {}

    // /**
    //  * @dev Optional trigger to override if tend() will be used...
    //  */
    // function _tendTrigger() internal view virtual override returns (bool) {
    //     return false;
    // }

    /**
     * @dev Frees funds during an emergency shutdown.
     */
    function _emergencyWithdraw(uint256 _amount) internal virtual override {
        // This function correctly calls _freeFunds, which we've already
        // updated to use vault.withdraw(). No change needed here.
        _freeFunds(_amount);
    }
}
