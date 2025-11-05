// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Test.sol";
import "../src/ServiceAgentPaymentHandler.sol";
import "../src/mocks/MockERC20.sol";

contract ServiceAgentPaymentHandlerTest is Test {
    MockERC20 public mockToken;

    function setUp() public {
        mockToken = new MockERC20();
    }
}
