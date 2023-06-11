// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {CToken} from "../lib/compound-protocol/contracts/CToken.sol";
import {CTokenInterface, CErc20Interface} from "../lib/compound-protocol/contracts/CTokenInterfaces.sol";
import {CErc20} from "../lib/compound-protocol/contracts/CErc20.sol";
import {CErc20Delegator} from "../lib/compound-protocol/contracts/CErc20Delegator.sol";
import {CErc20Delegate} from "../lib/compound-protocol/contracts/CErc20Delegate.sol";
import {Unitroller} from "../lib/compound-protocol/contracts/Unitroller.sol";
import {Comptroller} from "../lib/compound-protocol/contracts/Comptroller.sol";
import {SimplePriceOracle} from "../lib/compound-protocol/contracts/SimplePriceOracle.sol";
import {WhitePaperInterestRateModel} from "../lib/compound-protocol/contracts/WhitePaperInterestRateModel.sol";
import {InterestRateModel} from "../lib/compound-protocol/contracts/InterestRateModel.sol";

contract CompoundScript is Script {
    ERC20 comp;
    Comptroller comptrollerImplementation;
    Unitroller unitroller;
    Comptroller comptroller;
    InterestRateModel interestRateModel;
    SimplePriceOracle oracle;

    CErc20Delegate cErc20Delegate;
    ERC20 T;
    CErc20 cT;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint(
            "LoaSQDIZCEe2Hw6PdqPDRFZJAqBsU5p7"
        );
        vm.startBroadcast("deployerPrivateKey");

        unitroller = new Unitroller();
        comptrollerImplementation = new Comptroller();
        unitroller._setPendingImplementation(
            address(comptrollerImplementation)
        );
        comptrollerImplementation._become(unitroller);
        comptroller = Comptroller(address(unitroller));
        interestRateModel = new WhitePaperInterestRateModel(0, 0);
        oracle = new SimplePriceOracle();
        comptroller._setPriceOracle(oracle);
        cErc20Delegate = new CErc20Delegate();

        bytes memory callbackData = new bytes(0);
        CErc20Delegator cToken = new CErc20Delegator(
            address(T),
            comptroller,
            interestRateModel,
            1e18,
            "CToken",
            "cT",
            18,
            payable(address(this)),
            address(cErc20Delegate),
            callbackData
        );

        T = new ERC20("Token", "T");
        cT = CErc20(address(cToken));

        comptroller._supportMarket(CToken(address(cT)));
        CToken(address(cT))._setComptroller(comptroller);
        oracle.setUnderlyingPrice(CToken(address(cT)), 1);
        vm.stopBroadcast();
    }
}
