// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

contract GrabClub is ERC20, ERC20Burnable, ERC20Permit {
    constructor() ERC20("GrabClub", "GC") ERC20Permit("GrabClub") {
        _mint(_msgSender(), 6_000_000_000 * 10**decimals());
    }
}
