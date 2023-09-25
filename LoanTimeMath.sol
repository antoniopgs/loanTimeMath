// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

abstract contract LoanTimeMath {

    // Structs
    struct Loan {
        address borrower;
    }

    // Events
    event NewInterestRate(uint newRate, uint timestamp);

    // Tokens
    address debtToken;
    address receiptToken;

    // State
    uint lastOperationTime;
    uint currentInterestRate;
    uint savedSystemDebt;

    uint idealUtilization;
    uint line1;
    uint line2;

    // Loans
    mapping(uint => Loan) loans;

    function lastOperationTimeDelta() internal view returns(uint) {
        return block.timestamp - lastOperationTime;
    }

    function currentExponent() private view returns(uint) {
        return currentInterestRate * lastOperationTimeDelta;
    }

    function systemDebt() internal view returns(uint) {
        return savedSystemDebt * e ** currentExponent();
    }

    function loanDebt(uint id) public view returns(uint) {
        return yLiqToLiq(systemDebt(), debtToken.balanceOf(loans[id].borrower));
    }

    function utilization(uint _systemDebt) internal view returns(uint) {

        // Get realLiqSupply
        uint _realLiqSupply = realLiqSupply(_systemDebt);

        // Zero Case
        if (realLiqSupply == 0) {
            return 0; // Note: 0%

        } else {
            return _systemDebt.liqDivToRate(realLiqSupply);
        }
    }

    function realLiqSupply(uint _systemDebt) internal view returns(uint) {
        return totalSupply + systemAccruedSinceLastOp(_systemDebt);
    }

    function systemAccruedSinceLastOp(uint _systemDebt) internal view returns(uint) {
        return systemDebt.sub(savedSystemDebt);
    }

    function yLiqToLiq(uint yLiqAmount, uint _systemDebt) internal view returns(uint liqAmount) {

        // If systemDebt or yLiqSupply = 0, 1:1
        if (systemDebt == 0 || _yLiqSupply == 0) {
            return liqAmount = yLiqAmount;
        }

        // Calculate & Return liqAmount
        return liqAmount = yLiqAmount.mul(systemDebt).div(_yLiqSupply);
    }

    function liqToYLiq(uint liqAmount, uint _systemDebt) internal view returns(uint yLiqAmount) {

        // If systemDebt or yLiqSupply = 0, 1:1
        if (systemDebt == 0 || _yLiqSupply == 0) {
            return yLiqAmount = liqAmount;
        }

        // Calculate & Return yLiqAmount
        return yLiqAmount = liqAmount.mul(_yLiqSupply).div(systemDebt);
    }

    function calculateNewInterestRate() private view returns (uint) {

        uint newYearlyRate;
        uint _utilization = utilization();
        
        // If utilization is less than ideal than uses the first line to calculate the interest rate.
        if (_utilization.lt(idealUtilization)) {
            newYearlyRate = _utilization.mul(line1.slope).addSD59x18(line1.yIntercept);

        } else {
            newYearlyRate = _utilization.mul(line2.slope).addSD59x18(line2.yIntercept);
        }

        // Return rate per second
        return newYearlyRate / 365 days;
    }

    function preUtilzationChange() internal returns(uint _systemDebt) {

        // Get systemDebt
        systemDebt = _systemDebt();

        // Get accrued
        uint accrued = systemAccruedSinceLastOp(systemDebt);

        // Mint accrued
        LIQ.defaultOperatorMint(accrued);
    }

    function postUtilzationChange() internal {

        // Get now
        uint _now = block.timestamp;

        // Update currentExponent()
        currentInterestRate = calculateNewInterestRate(utilization(savedSystemDebt)); // Note: ensure savedSystemDebt is always updated during main function call
        lastOperationTime = _now;

        // Emit New Interest Rate
        emit NewInterestRate(currentInterestRate, _now);
    }
}
