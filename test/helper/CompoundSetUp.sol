// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "./UToken";
import "lib/compound-protocol/contracts/WhitePaperInterestRateModel.sol";
import "lib/compound-protocol/contracts/CErc20Delegate.sol";
import "lib/compound-protocol/contracts/CErc20Delegator.sol";
import "lib/compound-protocol/contracts/ComptrollerInterface.sol";
import "lib/compound-protocol/contracts/Comptroller.sol";
import "lib/compound-protocol/contracts/Unitroller.sol";
import "lib/compound-protocol/contracts/SimplePriceOracle.sol";
import "lib/compound-protocol/contracts/PriceOracle.sol";

contract CompoundSetUp is Test {
    address admin;
    address user1;
    address user2;

    UToken tokenA;
    UToken tokenB;

    WhitePaperInterestRateModel interestRateModelA;
    WhitePaperInterestRateModel interestRateModelB;

    CErc20Delegate cErc20DelegateA;
    CErc20Delegate cErc20DelegateB;

    CErc20Delegator CErc20DelegatorA;
    CErc20Delegator CErc20DelegatorB;

    SimplePriceOracle oracle;

    Comptroller comptroller;
    Unitroller unitroller;

    function setUp() public virtual {
        admin = makeAddr("admin");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        tokenA = new UToken("TokenA", "TKA", 18);
        tokenB = new UToken("TokenB", "TKB", 18);

        comptroller = new Comptroller();
        unitroller = new Unitroller();

        vm.startPrank(admin);

        uint errorCode = unitroller._setPendingImplementation(
            address(comptroller)
        );
        require(errorCode == 0, "failed");
        comptroller._become(unitroller);

        oracle = new SimplePriceOracle();
        Comptroller(address(unitroller))._setPriceOracle(PriceOracle(oracle));

        interestRateModelA = new WhitePaperInterestRateModel(0, 0);
        interestRateModelB = new WhitePaperInterestRateModel(0, 0);

        cErc20DelegateA = new CErc20Delegate();
        cErc20DelegateB = new CErc20Delegate();

        cErc20DelegatorA = new CErc20Delegator(
            address(tokenA),
            ComptrollerInterface(address(unitroller)),
            InterestRateModel(address(interestRateModelA)),
            10 ** 18,
            "CTokenA",
            "cTA",
            18,
            payable(admin),
            address(cErc20DelegateA),
            ""
        );

        cErc20DelegatorB = new CErc20Delegator(
            address(tokenB),
            ComptrollerInterface(address(unitroller)),
            InterestRateModel(address(interestRateModelB)),
            10 ** 18,
            "CTokenB",
            "cTB",
            18,
            payable(admin),
            address(cErc20DelegateB),
            ""
        );

        vm.stopPrank();
    }
}
