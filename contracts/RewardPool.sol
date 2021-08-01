// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract RewardPool {
    IERC20 internal immutable _stakingToken;
    IERC20 internal immutable _rewardToken;

    address internal _owner;

    uint256 internal _totalSupply;
    uint256 internal _validSupply;
    uint256 internal _rewardPhase;

    mapping(uint256 => uint256) internal _rewardHistory;

    event RewardAdded(uint256 reward);
    event Deposited(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event OwnershipTransferred(address indexed currentOwner, address indexed newOwner);

    struct UserInfo {
        uint256 balance;
        uint256 reward;
        uint256[] phase;
        uint256[] amount;
        uint256 state;
    }

    mapping(address => UserInfo) public user;

    constructor(address stakingToken, address rewardToken) {
        _stakingToken = IERC20(stakingToken);
        _rewardToken = IERC20(rewardToken);
        _owner = msg.sender;
    }

    // modifier
    modifier onlyOwner() {
        require(msg.sender == _owner, "RewardPool : Function called by unautorized user");
        _;
    }

    modifier updateReward(address account) {
        if(user[account].state == 1) {
            uint256 i;
            uint256 start = user[account].phase[0];
            uint256 end = _rewardPhase;

            for(i = start + 1; i < end; i++) {
                user[account].reward += user[account].amount[0] * _rewardHistory[i] / 1e18;
            }

            if(_rewardPhase == start) {
                user[account].phase[0] = _rewardPhase;
            }

            else {
                user[account].phase[0] = end - 1;
            }
        }

        else if(user[account].state == 2) {
            if(user[account].phase[0] != _rewardPhase && user[account].phase[1] != _rewardPhase) {
                uint256 i;
                uint256 j;
                uint256 start = user[account].phase[0];
                uint256 nstart = user[account].phase[1];
                uint256 end = _rewardPhase;
                for(i = start + 1; i < end; i++) {
                    user[account].reward += user[account].amount[0] * _rewardHistory[i] / 1e18;
                }

                for(j = nstart + 1; j < end; j++) {
                    user[account].reward += user[account].amount[1] * _rewardHistory[j] / 1e18;
                }

                user[account].amount[0] = user[account].amount[0] + user[account].amount[1];
                user[account].phase[0] = end -1;
                user[account].amount.pop();
                user[account].phase.pop();
                user[account].state = 1;
            }

            else {
                require(user[account].phase[0] == _rewardPhase-1 && user[account].phase[1] == _rewardPhase, "RewardPool : unintended behavior");
            }
        }

        else {
            require(user[account].state == 0, "RewardPool : not valid state");
        }

        _;
    }

    modifier isValid(address account) {
        require(user[msg.sender].state == user[msg.sender].phase.length && user[msg.sender].state == user[msg.sender].amount.length, "RewardPool : Not Valid State");
        
        if(user[msg.sender].state == 1) {
            require(user[account].phase[0] == _rewardPhase - 1 || user[account].phase[0] == _rewardPhase, "RewardPool : Not Valid State");
        }

        else if(user[msg.sender].state == 2) {
            require(user[account].phase[0] == _rewardPhase - 1 && user[account].phase[1] == _rewardPhase, "RewardPool : Not Valid State");
        }

        else {
            require(user[msg.sender].state == 0, "RewardPool : Not Valid State");
        }

        _;
    }

    function owner() external view returns(address) {
        return _owner;
    }

    function totalSupply() external view returns(uint256) {
        return _totalSupply;
    }

    function validSupply() external view returns(uint256) {
        return _validSupply;
    }

    function getRewardHistory(uint256 phase) external view returns(uint256) {
        return _rewardHistory[phase];
    }

    function getUserInfo(address account) external view returns(uint256 userBal, uint256 userReward, uint256[] memory phaseHistory, uint256[] memory amountHistory) {
        userBal = user[account].balance;
        userReward = user[account].reward;
        phaseHistory = user[account].phase;
        amountHistory = user[account].amount;
    }

    function getPoolInfo() external view returns(address stakingToken, address rewardToken) {
        stakingToken = address(_stakingToken);
        rewardToken = address(_rewardToken);
    }

    // acting functions
    function deposit(uint256 amount) external updateReward(msg.sender) isValid(msg.sender) {
        require(amount > 0, "RewardPool : deposit amount should over 0");

        _totalSupply = _totalSupply + amount;
        user[msg.sender].balance = user[msg.sender].balance + amount;
        _stakingToken.transferFrom(msg.sender, address(this), amount);

        if(user[msg.sender].state == 0) {
            user[msg.sender].phase.push(_rewardPhase);
            user[msg.sender].amount.push(amount);
            user[msg.sender].state = 1;
        }

        else if(user[msg.sender].state == 1) {
            if(_rewardPhase == user[msg.sender].phase[0]) {
                user[msg.sender].amount[0] = user[msg.sender].amount[0] + amount;
            }

            else {
                user[msg.sender].phase.push(_rewardPhase);
                user[msg.sender].amount.push(amount);
                user[msg.sender].state = 2;
            }
        }

        else if(user[msg.sender].state == 2){
            user[msg.sender].amount[1] = user[msg.sender].amount[1] + amount;
        }

        emit Deposited(msg.sender, amount);
    }

    function withdraw(uint256 amount) external updateReward(msg.sender) isValid(msg.sender) {
        require(amount > 0, "RewardPool : Cannot withdraw 0");

        _totalSupply = _totalSupply - amount;
        user[msg.sender].balance = user[msg.sender].balance - amount;
        _stakingToken.transfer(msg.sender, amount);
        
        if(user[msg.sender].state == 1){
            if(user[msg.sender].phase[0] != _rewardPhase) {
                _validSupply = _validSupply - amount;

                if(user[msg.sender].balance == 0) {
                    user[msg.sender].phase.pop();
                    user[msg.sender].amount.pop();
                    user[msg.sender].state = 0;
                }

                else {
                    user[msg.sender].amount[0] = user[msg.sender].amount[0] - amount;
                }
            }

            else {
                if(user[msg.sender].balance == 0) {
                    user[msg.sender].phase.pop();
                    user[msg.sender].amount.pop();
                    user[msg.sender].state = 0;
                }

                else {
                    user[msg.sender].amount[0] = user[msg.sender].amount[0] - amount;
                }
            }
        }

        else if(user[msg.sender].state ==2) {
            if(user[msg.sender].amount[1] < amount) {
                _validSupply = _validSupply + user[msg.sender].amount[1] - amount;

                if(user[msg.sender].balance == 0) {
                    user[msg.sender].phase.pop();
                    user[msg.sender].phase.pop();
                    user[msg.sender].amount.pop();
                    user[msg.sender].amount.pop();
                    user[msg.sender].state = 0;
                }

                else {
                    user[msg.sender].amount[0] = user[msg.sender].balance;
                    user[msg.sender].phase.pop();
                    user[msg.sender].amount.pop();
                    user[msg.sender].state = 1;
                }
            }

            else {
                if(amount == user[msg.sender].amount[1]) {
                    user[msg.sender].phase.pop();
                    user[msg.sender].amount.pop();
                    user[msg.sender].state = 1;
                }

                else {
                    user[msg.sender].amount[1] = user[msg.sender].amount[1] - amount;
                }
            }
        }

        emit Withdrawn(msg.sender, amount);
    }

    function claim() external updateReward(msg.sender) isValid(msg.sender) {
        uint256 rewardAmount = user[msg.sender].reward;
        if(rewardAmount > 0) {
            user[msg.sender].reward = 0;
            _rewardToken.transfer(msg.sender, rewardAmount);
            emit RewardPaid(msg.sender, rewardAmount);
        }
    }

    function update() external updateReward(msg.sender) {}

    function notifyReward(uint256 amount) external onlyOwner {
        uint256 currentPhase = _rewardPhase;
        uint256 rewardPerToken;

        if(_validSupply > 0) {
            rewardPerToken = amount * 1e18 / _validSupply;
        }

        else {
            rewardPerToken = 0;
        }

        _rewardHistory[currentPhase] = rewardPerToken;
        _rewardPhase = _rewardPhase + 1;
        _validSupply = _totalSupply;
    }
}
