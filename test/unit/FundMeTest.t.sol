// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Test} from "forge-std/Test.sol";
import {FundMe} from "../../src/FundMe.sol";
import {DeployFundMe} from "../../script/DeployFundMe.s.sol";

contract FundMeTest is Test {
    FundMe fundMe;

    address USER = makeAddr("USER");
    uint SEND_VALUE = 10e18;

    function setUp() external {
        DeployFundMe deployFundMe = new DeployFundMe();
        fundMe = deployFundMe.run();
    }

    function testMinimumDollarIsFive() public view {
        assertEq(fundMe.MINIMUM_USD(), 5e18);
    }

    function testOwnerIsMsgSender() public view {
        assertEq(fundMe.getOwner(), msg.sender);
    }

    function testPriceFeedAddressIsAccurate() public view {
        assertEq(fundMe.getVersion(), 4);
    }

    function testFundFailWithoutEnoughEth() public {
        vm.expectRevert(bytes("You need to spend more ETH!"));
        fundMe.fund();
    }

    function testFundUpdatesFundedDataStructure() public {
        hoax(USER);
        fundMe.fund{value: 10e18}();
        uint amount = fundMe.getAddressToAmountFunded(USER);
        assertEq(amount, 10e18);
    }

    function testAddsFunderToDataStructure() public {
        hoax(USER);
        fundMe.fund{value: 10e18}();
        address funders = fundMe.getFunders(0);
        assertEq(funders, USER);
    }

    modifier funded() {
        hoax(USER, SEND_VALUE);
        fundMe.fund{value: SEND_VALUE}();
        _;
    }

    function testOnlyOwnerCanWithdraw() public funded {
        vm.prank(USER);
        vm.expectRevert();
        fundMe.withdraw();
    }

    function testWithdrawWithASingleFunder() public funded {
        // Arrange
        uint ownerStartingBalance = fundMe.getOwner().balance;
        uint contractStartingBalance = address(fundMe).balance;

        // Act
        vm.prank(fundMe.getOwner());
        fundMe.withdraw();

        // Assert
        uint ownerEndingBalance = fundMe.getOwner().balance;
        uint contractEndingBalance = address(fundMe).balance;
        assertEq(contractEndingBalance, 0);
        assertEq(
            ownerEndingBalance,
            ownerStartingBalance + contractStartingBalance
        );
    }

    function testWithdrawWithMultipleFunders() public funded {
        uint160 numberOfFunders = 10;
        uint160 startingFundingIndex = 1;

        for (uint160 i = startingFundingIndex; i <= numberOfFunders; i++) {
            hoax(address(i), SEND_VALUE);
            fundMe.fund{value: SEND_VALUE}();
        }

        // Arrange
        uint ownerStartingBalance = fundMe.getOwner().balance;
        uint contractStartingBalance = address(fundMe).balance;

        // Act
        vm.prank(fundMe.getOwner());
        fundMe.withdraw();

        // Assert
        uint ownerEndingBalance = fundMe.getOwner().balance;
        uint contractEndingBalance = address(fundMe).balance;

        assertEq(contractEndingBalance, 0);
        assertEq(
            ownerEndingBalance,
            ownerStartingBalance + contractStartingBalance
        );
    }
}
