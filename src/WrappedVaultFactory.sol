// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import { Owned } from "lib/solmate/src/auth/Owned.sol";
import { ERC4626 } from "lib/solmate/src/tokens/ERC4626.sol";
import { LibString } from "lib/solmate/src/utils/LibString.sol";
import { VaultWrapper } from "src/VaultWrapper.sol";

/// @title WrappedVaultFactory
/// @author CopyPaste, corddry
/// @dev A factory for deploying wrapped vaults, and managing protocol or other fees
contract WrappedVaultFactory is Owned(msg.sender) {
    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    constructor(address _protocolFeeRecipient, uint256 _protocolFee, uint256 _minimumFrontendFee, address _pointsFactory) payable {
        if (_protocolFee > MAX_PROTOCOL_FEE) revert ProtocolFeeTooHigh();
        if (_minimumFrontendFee > MAX_MIN_REFERRAL_FEE) revert ReferralFeeTooHigh();

        protocolFeeRecipient = _protocolFeeRecipient;
        protocolFee = _protocolFee;
        minimumFrontendFee = _minimumFrontendFee;
        pointsFactory = _pointsFactory;
    }

    /*//////////////////////////////////////////////////////////////
                                STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 public constant MAX_PROTOCOL_FEE = 0.3e18;
    uint256 public constant MAX_MIN_REFERRAL_FEE = 0.3e18;

    address public immutable pointsFactory;

    address public protocolFeeRecipient;

    /// @dev The protocolFee for all incentivized vaults
    uint256 public protocolFee;
    /// @dev The default minimumFrontendFee to initialize incentivized vaults with
    uint256 public minimumFrontendFee;

    /// @dev All incentivized vaults deployed by this factory
    address[] public incentivizedVaults;
    mapping(address => bool) public isVault;

    /*//////////////////////////////////////////////////////////////
                               INTERFACE
    //////////////////////////////////////////////////////////////*/
    error ProtocolFeeTooHigh();
    error ReferralFeeTooHigh();

    event ProtocolFeeUpdated(uint256 newProtocolFee);
    event ReferralFeeUpdated(uint256 newReferralFee);
    event ProtocolFeeRecipientUpdated(address newRecipient);
    event VaultCreated(
        ERC4626 indexed underlyingVaultAddress,
        VaultWrapper indexed incentivizedVaultAddress,
        address owner,
        address inputToken,
        uint256 frontendFee,
        string name,
        string vaultSymbol
    );

    /*//////////////////////////////////////////////////////////////
                             OWNER CONTROLS
    //////////////////////////////////////////////////////////////*/

    /// @param newProtocolFee The new protocol fee to set for a given vault
    function updateProtocolFee(uint256 newProtocolFee) external payable onlyOwner {
        if (newProtocolFee > MAX_PROTOCOL_FEE) revert ProtocolFeeTooHigh();
        protocolFee = newProtocolFee;
        emit ProtocolFeeUpdated(newProtocolFee);
    }

    /// @param newMinimumReferralFee The new minimum referral fee to set for all incentivized vaults
    function updateMinimumReferralFee(uint256 newMinimumReferralFee) external payable onlyOwner {
        if (newMinimumReferralFee > MAX_MIN_REFERRAL_FEE) revert ReferralFeeTooHigh();
        minimumFrontendFee = newMinimumReferralFee;
        emit ReferralFeeUpdated(newMinimumReferralFee);
    }

    /// @param newRecipient The new protocol fee recipient to set for all incentivized vaults
    function updateProtocolFeeRecipient(address newRecipient) external payable onlyOwner {
        protocolFeeRecipient = newRecipient;
        emit ProtocolFeeRecipientUpdated(newRecipient);
    }

    /*//////////////////////////////////////////////////////////////
                             VAULT CREATION
    //////////////////////////////////////////////////////////////*/

    /// @param vault The ERC4626 Vault to deploy an incentivized vault for
    function createIncentivizedVault(
        ERC4626 vault,
        address owner,
        string calldata name,
        uint256 initialFrontendFee
    )
        external
        payable
        returns (VaultWrapper incentivizedVault)
    {
        bytes32 salt = keccak256(abi.encodePacked(address(vault), owner, name, initialFrontendFee));
        incentivizedVault = new VaultWrapper{ salt: salt }(owner, name, getNextSymbol(), address(vault), initialFrontendFee, pointsFactory);

        incentivizedVaults.push(address(incentivizedVault));
        isVault[address(incentivizedVault)] = true;

        emit VaultCreated(vault, incentivizedVault, owner, address(incentivizedVault.asset()), initialFrontendFee, name, getNextSymbol());
    }

    /// @dev Helper function to get the symbol for a new incentivized vault, ROY-0, ROY-1, etc.
    function getNextSymbol() internal view returns (string memory) {
        return string.concat("ROY-", LibString.toString(incentivizedVaults.length));
    }
}
