// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title BasicLaunchpad
/// @notice Collects ETH contributions, enforces caps, supports optional whitelist, refunds if soft cap not met, and mints tokens on finalize.
/// @dev Assumes token is a SimpleMintableToken (owner can mint). The Launchpad should be set as token owner before sale or token's mint permission given.
contract BasicLaunchpad is Ownable, ReentrancyGuard {
    // Sale parameters
    uint256 public startTime;
    uint256 public endTime;
    uint256 public softCap;      // in wei
    uint256 public hardCap;      // in wei
    uint256 public minContribution; // per wallet (wei)
    uint256 public maxContribution; // per wallet (wei)
    uint256 public rate; // tokens per 1 ETH (i.e. tokens per 1e18 wei)

    IERC20 public token; // token to distribute (must be mintable by this contract)

    // State
    uint256 public totalRaised; // in wei
    bool public finalized;
    bool public whitelistEnabled;

    mapping(address => uint256) public contributions;
    mapping(address => bool) public whitelist;

    // Events
    event Contributed(address indexed buyer, uint256 amount);
    event Finalized(bool success);
    event Claimed(address indexed buyer, uint256 tokenAmount);
    event Refunded(address indexed buyer, uint256 amount);
    event WhitelistUpdated(address indexed user, bool allowed);
    event EmergencyWithdraw(address indexed to, uint256 amount);

    constructor(
        address tokenAddress_,
        uint256 startTime_,
        uint256 endTime_,
        uint256 softCap_,
        uint256 hardCap_,
        uint256 minContribution_,
        uint256 maxContribution_,
        uint256 rate_
    ) {
        require(tokenAddress_ != address(0), "token=0");
        require(startTime_ < endTime_, "bad time");
        require(softCap_ <= hardCap_, "cap mismatch");
        require(rate_ > 0, "rate>0");

        token = IERC20(tokenAddress_);
        startTime = startTime_;
        endTime = endTime_;
        softCap = softCap_;
        hardCap = hardCap_;
        minContribution = minContribution_;
        maxContribution = maxContribution_;
        rate = rate_;
        whitelistEnabled = false;
    }

    modifier onlyWhileOpen() {
        require(block.timestamp >= startTime && block.timestamp <= endTime, "not open");
        _;
    }

    /// @notice Contribute ETH to the sale
    receive() external payable {
        contribute();
    }

    function contribute() public payable nonReentrant onlyWhileOpen {
        require(msg.value > 0, "zero eth");
        if (whitelistEnabled) {
            require(whitelist[msg.sender], "not whitelisted");
        }

        uint256 newContribution = contributions[msg.sender] + msg.value;
        require(newContribution >= minContribution, "below min");
        require(newContribution <= maxContribution, "above max");

        uint256 newTotal = totalRaised + msg.value;
        require(newTotal <= hardCap, "hard cap reached");

        contributions[msg.sender] = newContribution;
        totalRaised = newTotal;

        emit Contributed(msg.sender, msg.value);
    }

    /// @notice Finalize sale. Can be called by owner after endTime or when hardCap reached.
    /// If softCap met -> successful: tokens become claimable (mint on claim). Owner can withdraw funds.
    /// If softCap not met -> unsuccessful: contributors can refund.
    function finalize() external nonReentrant onlyOwner {
        require(!finalized, "already finalized");
        require(block.timestamp > endTime || totalRaised >= hardCap, "not ended");

        finalized = true;
        emit Finalized(totalRaised >= softCap);
    }

    /// @notice Claim tokens if sale successful. Mints tokens according to contribution and rate.
    function claim() external nonReentrant {
        require(finalized, "not finalized");
        require(totalRaised >= softCap, "softcap not reached");

        uint256 contributed = contributions[msg.sender];
        require(contributed > 0, "nothing to claim");

        contributions[msg.sender] = 0;

        // tokens = contributed (wei) * rate / 1e18
        uint256 tokenAmount = (contributed * rate) / 1 ether;
        require(tokenAmount > 0, "zero tokens");

        // mint tokens to buyer — token contract must have owner = this contract or allow minting by this contract
        // using low-level call to support either IERC20-mintable or other mint signature. We'll try the common mint(address,uint256).
        // If the token does not implement mint and instead has transfer, owner must pre-mint or set things up.
        _mintTokens(msg.sender, tokenAmount);

        emit Claimed(msg.sender, tokenAmount);
    }

    /// @notice Refunds contributor if sale failed (softCap not met)
    function refund() external nonReentrant {
        require(finalized, "not finalized");
        require(totalRaised < softCap, "softcap met; no refunds");
        uint256 contributed = contributions[msg.sender];
        require(contributed > 0, "nothing to refund");
        contributions[msg.sender] = 0;
        (bool sent, ) = msg.sender.call{value: contributed}("");
        require(sent, "refund failed");
        emit Refunded(msg.sender, contributed);
    }

    /// @notice Owner withdraws raised ETH when sale successful
    function withdrawFunds(address payable to) external onlyOwner nonReentrant {
        require(finalized, "not finalized");
        require(totalRaised >= softCap, "softcap not met");
        require(to != address(0), "bad to");
        uint256 balance = address(this).balance;
        require(balance > 0, "no funds");
        (bool sent, ) = to.call{value: balance}("");
        require(sent, "transfer failed");
    }

    /// @notice Add or remove multiple addresses from whitelist
    function setWhitelist(address[] calldata addrs, bool allowed) external onlyOwner {
        for (uint i = 0; i < addrs.length; i++) {
            whitelist[addrs[i]] = allowed;
            emit WhitelistUpdated(addrs[i], allowed);
        }
    }

    /// @notice Toggle whitelist requirement
    function setWhitelistEnabled(bool enabled) external onlyOwner {
        whitelistEnabled = enabled;
    }

    /// @notice Emergency withdraw of non-ETH tokens accidentally sent to the contract (e.g., admin token rescue)
    function emergencyWithdrawToken(address tokenAddr, address to, uint256 amount) external onlyOwner {
        require(to != address(0), "bad to");
        IERC20(tokenAddr).transfer(to, amount);
    }

    /// @notice Emergency withdraw ETH (owner only). Use with caution.
    function emergencyWithdrawETH(address payable to, uint256 amount) external onlyOwner {
        require(to != address(0), "bad to");
        require(amount <= address(this).balance, "insufficient");
        (bool sent, ) = to.call{value: amount}("");
        require(sent, "failed");
        emit EmergencyWithdraw(to, amount);
    }

    /// @dev internal helper trying to mint tokens using common mint signature.
    function _mintTokens(address to, uint256 amount) internal {
        // try standard mint(address,uint256)
        (bool ok, bytes memory res) = address(token).call(abi.encodeWithSignature("mint(address,uint256)", to, amount));
        if (ok) { return; }

        // try owner-only mint (token may require msg.sender == owner) - in that case Launchpad must already be owner
        // fallback to ERC20.transfer if tokens were pre-minted to this contract
        (bool ok2, ) = address(token).call(abi.encodeWithSignature("transfer(address,uint256)", to, amount));
        require(ok2, "mint/transfer failed");
    }

    /// @notice Helper to compute tokens for given wei amount
    function tokensForAmount(uint256 weiAmount) public view returns (uint256) {
        return (weiAmount * rate) / 1 ether;
    }
}
