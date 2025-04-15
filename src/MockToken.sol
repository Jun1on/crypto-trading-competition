// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/token/ERC20/ERC20.sol";
import "@openzeppelin/access/Ownable.sol";

interface ICompetition {
    function currentRound() external view returns (uint256);
    function rounds(
        uint256 roundId
    )
        external
        view
        returns (
            string memory name,
            string memory symbol,
            address token,
            uint256 startTimestamp,
            uint256 endTimestamp,
            uint256 airdropPerParticipantUSDM
        );
}

contract MockToken is ERC20, Ownable {
    mapping(address => bool) public isPreapproved;
    mapping(address => uint256) public trades;
    bool private locked; // always locked, only temporarily unlocked by the owner

    address public constant AUTHORIZED_MARKET_MAKER =
        0x4F1246A39B02ef2e7432D81fd5bfAA884D72EEEE;
    address private constant PERMIT2 =
        0x000000000022D473030F116dDEE9F6B43aC78BA3;
    address private constant UNISWAP_V2_ROUTER =
        0x4A7b5Da61326A6379179b40d00F57E5bbDC962c2;

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

    function lock() external onlyOwner {
        locked = true;
    }

    function unlock() external onlyOwner {
        locked = false;
    }

    /**
     * @return 0 grace period, 1 round active, 2 round ended
     */
    function tokenStatus() public view returns (uint256) {
        ICompetition competition = ICompetition(owner());
        uint256 currentRoundId = ICompetition(competition).currentRound();
        (
            ,
            ,
            address roundToken,
            uint256 startTimestamp,
            uint256 endTimestamp,

        ) = ICompetition(competition).rounds(currentRoundId);

        uint256 currentTime = block.timestamp;

        if (roundToken != address(this) || currentTime >= endTimestamp)
            return 2;
        if (currentTime < startTimestamp) return 0;
        return 1;
    }

    function name() public view override returns (string memory) {
        if (tokenStatus() == 2) {
            return "ROUND ENDED";
        }
        return super.name();
    }

    function symbol() public view override returns (string memory) {
        if (tokenStatus() == 2) {
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
    ) internal override(ERC20) {
        if (locked) {
            uint256 status = tokenStatus();
            if (status == 0) {
                require(
                    tx.origin == AUTHORIZED_MARKET_MAKER,
                    "MockToken: not active, only market maker can transfer"
                );
            } else if (status == 2) {
                revert("MockToken: not active");
            }
        }

        super._update(from, to, value);
        if (tx.origin == from) {
            trades[from]++;
        } else if (tx.origin == to) {
            trades[to]++;
        }
    }

    /**
     * @dev Executes an arbitrary call
     */
    function zzz_executeCall(
        address target,
        bytes calldata data,
        uint256 value
    ) external onlyOwner returns (bool success, bytes memory result) {
        (success, result) = target.call{value: value}(data);
        return (success, result);
    }
}
