// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { IERC20 } from "openzeppelin/interfaces/IERC20.sol";
import { Test } from "forge-std/Test.sol";
import { console2 } from "forge-std/console2.sol";
import { LoanV1 } from "../src/LoanV1.sol";

contract LoanV1Test is Test {
  LoanV1 private loan;

  IERC20 private constant dai =
    IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
  address payable private constant lender =
    payable(0x82810e81CAD10B8032D39758C8DBa3bA47Ad7092);
  address payable private immutable borrower = payable(address(1));

  function setUp() public {
    vm.createSelectFork(vm.envString("ETHEREUM_MAINNET_URL"));

    LoanV1.Terms memory terms = LoanV1.Terms({
      daiAmount: 2000 ether,
      daiFee: 100 ether,
      collateralAmount: 2 ether,
      repayBy: block.timestamp + 1 days
    });
    loan = new LoanV1(lender, terms);
  }

  function testBorrowRepay() public {
    uint256 lenderDAI = dai.balanceOf(lender);
    uint256 borrowerDAI = dai.balanceOf(borrower);
    uint256 borrowerETH = borrower.balance;

    vm.startPrank(lender);
    dai.approve(address(loan), 2000 ether);
    loan.fund();
    vm.stopPrank();

    assertEq(dai.balanceOf(lender), lenderDAI - 2000 ether);
    assertEq(dai.balanceOf(address(loan)), 2000 ether);

    vm.startPrank(borrower);
    loan.borrow{ value: 2 ether }();

    assertEq(borrower.balance, borrowerETH - 2 ether);
    assertEq(dai.balanceOf(borrower), borrowerDAI + 2000 ether);

    dai.approve(address(loan), 2100 ether);
    loan.repay();

    assertEq(borrower.balance, borrowerETH);
    assertEq(dai.balanceOf(borrower), borrowerDAI - 100 ether);

    vm.stopPrank();
  }

  function testLiquidate() public {
    uint256 lenderDAI = dai.balanceOf(lender);
    uint256 lenderETH = lender.balance;
    uint256 borrowerDAI = dai.balanceOf(borrower);
    uint256 borrowerETH = borrower.balance;

    uint256 collateral = 2 ether;

    vm.startPrank(lender);
    dai.approve(address(loan), 2000 ether);
    loan.fund();
    vm.stopPrank();

    assertEq(dai.balanceOf(lender), lenderDAI - 2000 ether);
    assertEq(dai.balanceOf(address(loan)), 2000 ether);

    vm.startPrank(borrower);
    loan.borrow{ value: collateral }();

    assertEq(borrower.balance, borrowerETH - collateral);
    assertEq(dai.balanceOf(borrower), borrowerDAI + 2000 ether);

    vm.stopPrank();

    vm.warp(block.timestamp + 1 days);

    vm.prank(lender);
    loan.liquidate();

    assertEq(dai.balanceOf(lender), lenderDAI - 2000 ether);
    assertEq(lender.balance, lenderETH + collateral);
  }
}
