
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract YourContract {
    struct Pool {
        IERC20 stakingToken;
        IERC20 rewardToken;
        uint256 rewardRatePerBlock;
        uint256 lastRewardBlock;
        uint256 accRewardPerShare;
    }

    struct UserInfo {
        uint256 amount; // How many tokens the user has staked.
        uint256 rewardDebt; // Reward debt.
    }

    mapping(uint256 => Pool) public pools;
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    uint256 public poolCount;

    event PoolAdded(uint256 indexed poolId, address stakingToken, address rewardToken, uint256 rewardRatePerBlock);
    event Staked(address indexed user, uint256 indexed poolId, uint256 amount);
    event Unstaked(address indexed user, uint256 indexed poolId, uint256 amount);
    event RewardClaimed(address indexed user, uint256 indexed poolId, uint256 amount);

    constructor() {}

    function addPool(
        address _stakingToken,
        address _rewardToken,
        uint256 _rewardRatePerBlock
    ) external {
        pools[poolCount] = Pool({
            stakingToken: IERC20(_stakingToken),
            rewardToken: IERC20(_rewardToken),
            rewardRatePerBlock: _rewardRatePerBlock,
            lastRewardBlock: block.number,
            accRewardPerShare: 0
        });
        emit PoolAdded(poolCount, _stakingToken, _rewardToken, _rewardRatePerBlock);
        poolCount++;
    }

    function stake(uint256 _poolId, uint256 _amount) external {
        Pool storage pool = pools[_poolId];
        UserInfo storage user = userInfo[_poolId][msg.sender];

        updatePool(_poolId);

        if (user.amount > 0) {
            uint256 pending = user.amount * pool.accRewardPerShare / 1e12 - user.rewardDebt;
            safeRewardTransfer(msg.sender, pending);
        }

        pool.stakingToken.transferFrom(address(msg.sender), address(this), _amount);
        user.amount += _amount;
        user.rewardDebt = user.amount * pool.accRewardPerShare / 1e12;

        emit Staked(msg.sender, _poolId, _amount);
    }

    function unstake(uint256 _poolId, uint256 _amount) external {
        Pool storage pool = pools[_poolId];
        UserInfo storage user = userInfo[_poolId][msg.sender];

        require(user.amount >= _amount, "unstake: not good");

        updatePool(_poolId);

        uint256 pending = user.amount * pool.accRewardPerShare / 1e12 - user.rewardDebt;
        safeRewardTransfer(msg.sender, pending);

        user.amount -= _amount;
        user.rewardDebt = user.amount * pool.accRewardPerShare / 1e12;

        pool.stakingToken.transfer(address(msg.sender), _amount);

        emit Unstaked(msg.sender, _poolId, _amount);
    }

    function claimReward(uint256 _poolId) external {
        Pool storage pool = pools[_poolId];
        UserInfo storage user = userInfo[_poolId][msg.sender];

        updatePool(_poolId);

        uint256 pending = user.amount * pool.accRewardPerShare / 1e12 - user.rewardDebt;
        safeRewardTransfer(msg.sender, pending);
        user.rewardDebt = user.amount * pool.accRewardPerShare / 1e12;

        emit RewardClaimed(msg.sender, _poolId, pending);
    }

    function updatePool(uint256 _poolId) internal {
        Pool storage pool = pools[_poolId];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }

        uint256 lpSupply = pool.stakingToken.balanceOf(address(this));
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }

        uint256 blocks = block.number - pool.lastRewardBlock;
        uint256 reward = blocks * pool.rewardRatePerBlock;

        pool.accRewardPerShare += reward / lpSupply / 1e12;
        pool.lastRewardBlock = block.number;
    }

    function safeRewardTransfer(address _to, uint256 _amount) internal {
        Pool storage pool = pools[0]; // Assuming pool ID 0 is the reward pool
        uint256 rewardBal = pool.rewardToken.balanceOf(address(this));
        if (_amount > rewardBal) {
            pool.rewardToken.transfer(_to, rewardBal);
        } else {
            pool.rewardToken.transfer(_to, _amount);
        }
    }
}
