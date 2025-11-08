// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

// OpenZeppelin contracts
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @dev This is the interface for your Octant YieldDonatingStrategy.
 * It's an ERC4626, so it has redeem() and asset() functions.
 */
interface ITokenizedStrategy is IERC20 {
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256);
    function asset() external view returns (address);
}

interface ISuperToken is IERC20 {
    function getUnderlyingToken() external view returns (address tokenAddr);
    function upgrade(uint256 amount) external;
}

interface CFAv1Forwarder {
    function createFlow(ISuperToken token, address sender, address receiver, int96 flowrate, bytes memory userData)
        external
        returns (bool);
    function deleteFlow(ISuperToken token, address sender, address receiver, bytes memory userData)
        external
        returns (bool);
    function updateFlow(ISuperToken token, address sender, address receiver, int96 flowrate, bytes memory userData)
        external
        returns (bool);
}

/**
 * @title StrategyVestingDonation
 * @author (You)
 * @notice This contract acts as the `donationAddress` for an Octant strategy.
 * It receives strategy shares, allows an owner to redeem them for the
 * underlying asset (e.g., USDC), wraps that asset into a SuperToken (e.g., USDCx),
 * and streams it to a final beneficiary over 90 days.
 */
contract StrategyVestingDonation is Ownable {
    using SafeERC20 for IERC20;
    IERC20 public immutable underlying;
    // --- Superfluid ---
    ISuperToken public immutable superToken; // e.g., USDCx
    CFAv1Forwarder public immutable forwarder; // e.g., USDCx

    // --- Octant ---
    ITokenizedStrategy public immutable strategy;

    // --- Vesting ---
    address public beneficiary;
    uint256 public constant STREAMING_DURATION = 90 days;

    /// @notice Emitted when a new stream is started or updated
    event StreamStarted(address indexed beneficiary, int96 flowRate);
    /// @notice Emitted when the beneficiary is updated
    event BeneficiaryUpdated(address indexed newBeneficiary);

    /**
     * @param _superTokenAddress The Superfluid Token address (e.g., from Superfluid docs)
     * @param _strategyAddress The address of the Octant YieldDonatingStrategy
     * @param _beneficiary The final address to receive the streamed funds
     */
    constructor(address _superTokenAddress, address _strategyAddress, address _beneficiary) Ownable(msg.sender) {
        // Set initial owner (e.g., your multisig)
        strategy = ITokenizedStrategy(_strategyAddress);
        underlying = IERC20(strategy.asset());

        superToken = ISuperToken(_superTokenAddress);
        require(superToken.getUnderlyingToken() == address(underlying), "token & underlying mismatch");

        require(_beneficiary != address(0), "Beneficiary cannot be zero");
        beneficiary = _beneficiary;

        // Approve the SuperToken contract to pull the underlying for wrapping
        underlying.forceApprove(address(superToken), type(uint256).max);
    }

    /**
     * @notice Redeems all held strategy shares, wraps them, and starts/updates the stream.
     * @dev This must be called by the owner (e.g., a keeper or multisig).
     * The strategy mints shares to this contract, which just sit here until
     * this function is called to process them.
     */
    function redeemAndStream() external onlyOwner {
        // 1. Get strategy shares held by this contract
        uint256 sharesToRedeem = strategy.balanceOf(address(this));
        if (sharesToRedeem == 0) {
            return; // Nothing to do
        }

        // Redeem shares for underlying asset (e.g., USDC)
        // We check the balance *before* and *after* to see how much we received.
        uint256 underlyingBefore = underlying.balanceOf(address(this));
        strategy.redeem(sharesToRedeem, address(this), address(this));
        uint256 underlyingAfter = underlying.balanceOf(address(this));

        uint256 underlyingReceived = underlyingAfter - underlyingBefore;
        if (underlyingReceived == 0) {
            return; // Redeem failed or gave 0
        }

        // 3. Wrap the received underlying (e.g., USDC -> USDCx)
        // The SuperToken (USDCx) is now in this contract's balance
        superToken.upgrade(underlyingReceived);

        // 4. Calculate new flow rate
        // We stream *all* SuperTokens this contract holds, divided by the duration
        // This means any new funds just add to the existing stream's principal
        uint256 totalStreamable = superToken.balanceOf(address(this));
        int96 newFlowRate = int96(int256(totalStreamable / STREAMING_DURATION));

        if (newFlowRate == 0) {
            return; // Amount too small to stream
        }

        // Create or update the stream
        // The .flow() library function handles creating or updating
        forwarder.createFlow(superToken, address(this), beneficiary, newFlowRate, "");

        emit StreamStarted(beneficiary, newFlowRate);
    }

    /**
     * @notice Updates the beneficiary. Stops the old stream.
     * @dev The new beneficiary will start at 0. redeemAndStream must be called
     * to start the stream to the new beneficiary.
     * @param _newBeneficiary The new address to stream funds to.
     */
    function setBeneficiary(address _newBeneficiary) external onlyOwner {
        require(_newBeneficiary != address(0), "Beneficiary cannot be zero");

        // Stop the old stream
        forwarder.deleteFlow(superToken, address(this), beneficiary, "");

        beneficiary = _newBeneficiary;
        emit BeneficiaryUpdated(_newBeneficiary);
    }

    /**
     * @notice Stops the stream and allows the owner to withdraw any
     * remaining SuperTokens (e.g., if the project is migrating).
     */
    function emergencyStopAndWithdraw() external onlyOwner {
        // Stop the stream
        forwarder.deleteFlow(superToken, address(this), beneficiary, "");

        // Withdraw all remaining SuperTokens
        uint256 balance = superToken.balanceOf(address(this));
        if (balance > 0) {
            superToken.transfer(owner(), balance);
        }
        // Withdraw all remaining underlying
        balance = underlying.balanceOf(address(this));
        if (balance > 0) {
            underlying.transfer(owner(), balance);
        }
        // Withdraw all remaining vault shares
        balance = strategy.balanceOf(address(this));
        if (balance > 0) {
            strategy.transfer(owner(), balance);
        }
    }

    /**
     * @notice Fallback receive function to accept ETH (e.g., for gas).
     */
    receive() external payable {}
}
