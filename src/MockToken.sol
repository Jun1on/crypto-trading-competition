// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/token/ERC20/ERC20.sol";
import "@openzeppelin/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/access/Ownable.sol";

contract MockToken is ERC20, ERC20Pausable, Ownable {
    mapping(address => bool) public isPreapproved;
    address private constant PERMIT2 =
        0x000000000022D473030F116dDEE9F6B43aC78BA3;
    address private constant UNISWAP_V2_ROUTER =
        0x4A7b5Da61326A6379179b40d00F57E5bbDC962c2;

    bool private _roundEnded;

    constructor(
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol) Ownable(msg.sender) {
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
     * @notice Changes both token name and symbol to "ROUND ENDED"
     */
    function markRoundEnded() external onlyOwner {
        _roundEnded = true;
        _pause();
    }

    function name() public view override returns (string memory) {
        if (_roundEnded) {
            return "ROUND ENDED";
        }
        return super.name();
    }

    function symbol() public view override returns (string memory) {
        if (_roundEnded) {
            return "ROUND ENDED";
        }
        return super.symbol();
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

    function _update(
        address from,
        address to,
        uint256 value
    ) internal override(ERC20, ERC20Pausable) {
        ERC20Pausable._update(from, to, value);
    }
}
