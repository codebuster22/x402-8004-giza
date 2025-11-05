// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract StrategyRegistry is ERC721 {
    constructor() ERC721("Strategy Registry", "STRATEGY") {}
}
