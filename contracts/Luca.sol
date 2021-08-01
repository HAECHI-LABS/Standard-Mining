// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Luca is ERC20 {
    address internal _owner;
    uint256 internal _supplyCap;

    mapping(address => uint256) public lockInfo;
    event OwnershipTransferred(address indexed currentOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == _owner, "Luca : Function called by unautorized user");
        _;
    }

    constructor(string memory name, string memory symbol, uint256 supplyCap) ERC20(name, symbol) {
        _owner = msg.sender;
        _supplyCap = supplyCap;
    }

    function transferOwnership(address account) external onlyOwner {
        require(account != address(0), "Luca : Cannot transfer ownership to zero address");
        emit OwnershipTransferred(_owner, account);
        _owner = account;
    }

    function owner() external view returns (address ownerAddress) {
        ownerAddress = _owner;
    }

    function mint(address account, uint256 amount) external onlyOwner {
        require(totalSupply() + amount <= _supplyCap, "Luca : Cannot mint more than supplyCap");
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) external onlyOwner {
        _burn(account, amount);
    }
}