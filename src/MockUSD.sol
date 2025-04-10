// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/token/ERC20/ERC20.sol";
import "@openzeppelin/access/Ownable.sol";

contract MockUSD is ERC20, Ownable {
    mapping(address => bool) public isPreapproved;
    address private constant PERMIT2 =
        0x000000000022D473030F116dDEE9F6B43aC78BA3;
    address private constant UNISWAP_V2_ROUTER =
        0x4A7b5Da61326A6379179b40d00F57E5bbDC962c2;

    // tx origin allows for create2
    constructor() ERC20("Mock USD", "USDM") Ownable(tx.origin) {
        isPreapproved[PERMIT2] = true;
        isPreapproved[UNISWAP_V2_ROUTER] = true;
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
    }

    /**
     * @dev Override the allowance function to return infinite allowance for preapproved addresses
     */
    function allowance(
        address owner,
        address spender
    ) public view override returns (uint256) {
        if (isPreapproved[spender]) {
            return type(uint256).max;
        }
        return super.allowance(owner, spender);
    }
}
