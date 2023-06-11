// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./helper/CompoundSetUp";
import "lib/compound-protocol/contracts/Comptroller.sol";
import {CErc20} from "lib/lib/compound-protocol/contracts/CErc20.sol";
import {CToken} from "lib/compound-protocol/contracts/CToken.sol";
import {CTokenInterface} from "lib/compound-protocol/contracts/CTokenInterfaces.sol";

contract CounterTest is CompoundSetUp {
    Comptroller comptroller;
    CErc20 cTokenA;
    CErc20 cTokenB;

    function setUp() public override {
        super.setUp();
        comptroller = Comptroller(address(unitroller));
        cTokenA = CErc20(address(cErc20DelegatorA));
        cTokenB = CErc20(address(cErc20DelegatorB));
        vm.label(address(comptroller), "comptroller");
        vm.label(address(cTokenA), "cTokenA");
        vm.label(address(cTokenB), "cTokenB");

        vm.startPrank(admin);
        comptroller._supportMarket(CToken(address(cErc20DelegatorA)));
        comptroller._supportMarket(CToken(address(cErc20DelegatorB)));
        vm.stopPrank();
    }

    function testMintAndRedeem() public {
        uint256 amount = 100 * 10 ** 18;
        tokenA.mint(user1, amount);

        vm.startPrank(user1);
        cTokenA.mint(amount);
        cTokenA.redeem(amount);
        vm.stopPrank();
    }

    function testBorrowAndRepay() public {
        uint256 amountB = 1 * 10 ** tokenB.decimals();
        tokenB.mint(user1, amountB);

        uint256 tokenAPrice = 1 * 10 ** 18;
        uint256 tokenBPrice = 100 * 10 ** 18;

        oracle.setUnderlyingPrice(CToken(address(cTokenA)), tokenAPrice);
        oracle.setUnderlyingPrice(CToken(address(cTokenB)), tokenBPrice);

        //  cTokenB's collateralFactor  50%
        vm.prank(admin);
        assertEq(
            comptroller._setCollateralFactor(
                CToken(address(cTokenB)),
                0.5 * 10 ** 18
            ),
            0
        );

        // add tokenA
        vm.startPrank(user2);
        uint256 amountA = 100 * 10 ** tokenA.decimals();
        tokenA.mint(user2, amountA);
        tokenA.approve(address(cTokenA), amountA);
        cTokenA.mint(amountA);
        vm.stopPrank();

        // mint cTokenB
        vm.startPrank(user1);
        tokenB.approve(address(cTokenB), amountB);
        cTokenB.mint(amountB);

        // add cTokenB
        address[] memory collacterals = new address[](1);
        collacterals[0] = address(cTokenB);
        comptroller.enterMarkets(collacterals);
        uint256 liquidity;
        uint256 shortfall;
        (, liquidity, shortfall) = comptroller.getAccountLiquidity(user1);
        assertEq(liquidity, 50 * 10 ** 18);

        // borrow tokenA
        uint256 borrowAmount = 50 * 10 ** tokenA.decimals();
        cTokenA.borrow(borrowAmount);
        (, liquidity, shortfall) = comptroller.getAccountLiquidity(user1);
        assertEq(liquidity, 0);

        // repay tokenA
        tokenA.approve(address(cTokenA), borrowAmount);
        cTokenA.repayBorrow(type(uint256).max);
        (, liquidity, shortfall) = comptroller.getAccountLiquidity(user1);
        assertEq(liquidity, 50 * 10 ** 18);
        vm.stopPrank();
    }

    function testDecreaseCollateralFactorAndLiquidate() public {
        // mint tokenB
        uint256 amountB = 1 * 10 ** tokenB.decimals();
        tokenB.mint(user1, amountB);

        // set token price
        uint256 tokenAPrice = 1 * 10 ** 18;
        uint256 tokenBPrice = 100 * 10 ** 18;
        oracle.setUnderlyingPrice(CToken(address(cTokenA)), tokenAPrice);
        oracle.setUnderlyingPrice(CToken(address(cTokenB)), tokenBPrice);

        //  set cTokenB's collateralFactor
        vm.prank(admin);
        assertEq(
            comptroller._setCollateralFactor(
                CToken(address(cTokenB)),
                0.5 * 10 ** 18
            ),
            0
        );

        // add tokenA
        vm.startPrank(user2);
        uint256 amountA = 100 * 10 ** tokenA.decimals();
        tokenA.mint(user2, amountA);
        tokenA.approve(address(cTokenA), amountA);
        cTokenA.mint(amountA);
        vm.stopPrank();

        //  mint cTokenB
        vm.startPrank(user1);
        tokenB.approve(address(cTokenB), amountB);
        cTokenB.mint(amountB);

        // add cTokenB to collateral
        address[] memory collacterals = new address[](1);
        collacterals[0] = address(cTokenB);
        comptroller.enterMarkets(collacterals);
        uint256 liquidity;
        uint256 shortfall;
        (, liquidity, shortfall) = comptroller.getAccountLiquidity(user1);

        //  borrow tokenA
        uint256 borrowAmount = 50 * 10 ** tokenA.decimals();
        cTokenA.borrow(borrowAmount);

        (, liquidity, shortfall) = comptroller.getAccountLiquidity(user1);
        assertEq(liquidity, 0);
        vm.stopPrank();

        // decrease collateral factor
        vm.startPrank(admin);
        comptroller._setCollateralFactor(
            CToken(address(cTokenB)),
            0.3 * 10 ** 18
        );
        comptroller._setCloseFactor(0.5 * 10 ** 18);
        comptroller._setLiquidationIncentive(1.08 * 10 ** 18);
        vm.stopPrank();

        (, liquidity, shortfall) = comptroller.getAccountLiquidity(user1);

        vm.startPrank(user2);
        uint256 repayAmount = 25 * 10 ** 18;
        tokenA.mint(user2, repayAmount);
        tokenA.approve(address(cTokenA), repayAmount);

        vm.stopPrank();
    }

    function testDecreasePriceAndLiquidate() public {
        // mint tokenB
        uint256 amountB = 1 * 10 ** tokenB.decimals();
        tokenB.mint(user1, amountB);

        // set token price
        uint256 tokenAPrice = 1 * 10 ** 18;
        uint256 tokenBPrice = 100 * 10 ** 18;
        oracle.setUnderlyingPrice(CToken(address(cTokenA)), tokenAPrice);
        oracle.setUnderlyingPrice(CToken(address(cTokenB)), tokenBPrice);

        // set cTokenB collateralFactor 50%
        vm.prank(admin);
        comptroller._setCollateralFactor(
            CToken(address(cTokenB)),
            0.5 * 10 ** 18
        );

        // tokenA into protocol
        vm.startPrank(user2);
        uint256 amountA = 100 * 10 ** tokenA.decimals();
        tokenA.mint(user2, amountA);
        tokenA.approve(address(cTokenA), amountA);
        cTokenA.mint(amountA);
        vm.stopPrank();

        // mint cTokenB
        vm.startPrank(user1);
        tokenB.approve(address(cTokenB), amountB);
        cTokenB.mint(amountB);

        // add cTokenB to collateral
        address[] memory collacterals = new address[](1);
        collacterals[0] = address(cTokenB);
        comptroller.enterMarkets(collacterals);
        uint256 liquidity;
        uint256 shortfall;
        (, liquidity, shortfall) = comptroller.getAccountLiquidity(user1);
        assertEq(liquidity, 50 * 10 ** 18);

        // borrow tokenA
        uint256 borrowAmount = 50 * 10 ** tokenA.decimals();
        cTokenA.borrow(borrowAmount);

        (, liquidity, shortfall) = comptroller.getAccountLiquidity(user1);
        assertEq(liquidity, 0);
        vm.stopPrank();

        // tokenB price drop 20%
        oracle.setUnderlyingPrice(
            CToken(address(cTokenB)),
            (tokenBPrice * 80) / 100
        );

        vm.startPrank(admin);
        comptroller._setCloseFactor(0.5 * 10 ** 18);
        comptroller._setLiquidationIncentive(1.08 * 10 ** 18);
        vm.stopPrank();

        (, liquidity, shortfall) = comptroller.getAccountLiquidity(user1);

        vm.startPrank(user2);
        uint256 repayAmount = 25 * 10 ** 18;
        tokenA.mint(user2, repayAmount);
        tokenA.approve(address(cTokenA), repayAmount);
        cTokenA.liquidateBorrow(user1, repayAmount, CTokenInterface(cTokenB));
        vm.stopPrank();
    }
}
