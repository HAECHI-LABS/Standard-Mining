// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract RewardTreasury {
    IERC20 internal immutable _rewardToken;
    address internal _owner;
    address internal _pool;

    mapping(uint256=>uint256) internal _notifyHistory;
    uint256 internal _phase;

    constructor(address rewardToken, address rewardPool) {
        _rewardToken = IERC20(rewardToken);
        _pool = rewardPool;
        _owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == _owner, "RewardTreasury : Function called by unautorized user");
        _;
    }

    function notifyReward(uint256 amount) external onlyOwner {
        if(amount > 0) {
            _rewardToken.transfer(_pool, amount);
        }
        _notifyHistory[_phase] = amount;
        _phase ++;
    }

    function getNotifyHistory(uint256 phase) external view returns(uint256) {
        return _notifyHistory[phase];
    }
}