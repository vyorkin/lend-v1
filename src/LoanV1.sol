// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import { IERC20 } from "openzeppelin/interfaces/IERC20.sol";

contract LoanV1 {
  error InvalidState(LoanState state);
  error InvalidCollateral(uint256 expected, uint256 actual);
  error InvalidBorrower();
  error InvalidLender();
  error LoanIsNotExpired();
  error FailedSendCollateral();

  struct Terms {
    uint256 daiAmount;
    uint256 daiFee;
    uint256 collateralAmount;
    uint256 repayBy;
  }

  enum LoanState {
    Created,
    Funded,
    Borrowed
  }

  IERC20 private constant dai =
    IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);

  Terms private terms;
  LoanState private state;

  address payable private immutable deployer;
  address payable private immutable lender;
  address payable private borrower;

  constructor(address _lender, Terms memory _terms) {
    deployer = payable(msg.sender);
    terms = _terms;
    lender = payable(_lender);
    state = LoanState.Created;
  }

  modifier atState(LoanState _state) {
    if (state != _state) {
      revert InvalidState(_state);
    }
    _;
  }

  function fund() public atState(LoanState.Created) {
    state = LoanState.Funded;
    dai.transferFrom(msg.sender, address(this), terms.daiAmount);
  }

  function borrow() public payable atState(LoanState.Funded) {
    if (msg.value < terms.collateralAmount) {
      revert InvalidCollateral(terms.collateralAmount, msg.value);
    }

    state = LoanState.Borrowed;
    borrower = payable(msg.sender);
    dai.transfer(borrower, terms.daiAmount);
  }

  function repay() public atState(LoanState.Borrowed) {
    if (msg.sender != borrower) {
      revert InvalidBorrower();
    }
    dai.transferFrom(borrower, lender, terms.daiAmount + terms.daiFee);
    (bool sent, ) = borrower.call{ value: terms.collateralAmount }("");
    if (!sent) {
      revert FailedSendCollateral();
    }
    selfdestruct(lender);
  }

  function liquidate() public atState(LoanState.Borrowed) {
    if (msg.sender != lender) {
      revert InvalidLender();
    }
    if (block.timestamp < terms.repayBy) {
      revert LoanIsNotExpired();
    }
    (bool sent, ) = lender.call{ value: terms.collateralAmount }("");
    if (!sent) {
      revert FailedSendCollateral();
    }
    selfdestruct(deployer);
  }
}
