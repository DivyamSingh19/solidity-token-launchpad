// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title SimpleMintableToken
/// @notice ERC20 token where the owner can mint. Intended for use with a Launchpad that will mint allocation to buyers.
contract SimpleMintableToken is ERC20, Ownable {
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {}

    /// @notice Mint tokens to `to`. Only owner (deployer or custodian e.g. factory/launchpad) can mint.
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    /// @notice Convenient burn (optional)
    function burn(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
    }
}
