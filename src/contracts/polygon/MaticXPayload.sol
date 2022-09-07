// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV3Polygon} from '@aave-address-book/AaveV3Polygon.sol';
import {IPoolConfigurator, ConfiguratorInputTypes} from '@aave-address-book/AaveV3.sol';
import {IERC20Metadata} from '@solidity-utils/contracts/oz-common/interfaces/IERC20Metadata.sol';
import {IProposalGenericExecutor} from '../../interfaces/IProposalGenericExecutor.sol';

/**
 * @author Llama
 * @dev This payload lists MaticX (MaticX) as a collateral and non-borrowing asset on Aave V3 Polygon
 * Governance Forum Post: https://governance.aave.com/t/proposal-to-add-maticx-to-aave-v3-polygon-market/7995
 * Parameter snapshot: https://snapshot.org/#/aave.eth/proposal/0x88e896a245ffeda703e0b8f5494f3e66628be6e32a7243e3341b545c2972857f
 */
contract MaticXPayload is IProposalGenericExecutor {
  // **************************
  // Protocol's contracts
  // **************************
  address public constant INCENTIVES_CONTROLLER =
    0x929EC64c34a17401F460460D4B9390518E5B473e;

  // **************************
  // New asset being listed (MaticX)
  // **************************

  address public constant UNDERLYING =
    0xfa68FB4628DFF1028CFEc22b4162FCcd0d45efb6;
  string public constant ATOKEN_NAME = 'Aave Polygon MATICX';
  string public constant ATOKEN_SYMBOL = 'aPolMATICX';
  string public constant VDTOKEN_NAME = 'Aave Polygon Variable Debt MATICX';
  string public constant VDTOKEN_SYMBOL = 'variableDebtPolMATICX';
  string public constant SDTOKEN_NAME = 'Aave Polygon Stable Debt MATICX';
  string public constant SDTOKEN_SYMBOL = 'stableDebtPolMATICX';

  // TODO: Confirm the price feed
  address public constant PRICE_FEED =
    0x5d37E4b374E6907de8Fc7fb33EE3b0af403C7403;

  // AAVE v3 Reserve Token implementation contracts
  address public constant ATOKEN_IMPL =
    0xa5ba6E5EC19a1Bf23C857991c857dB62b2Aa187B;
  address public constant VDTOKEN_IMPL =
    0x81387c40EB75acB02757C1Ae55D5936E78c9dEd3;
  address public constant SDTOKEN_IMPL =
    0x52A1CeB68Ee6b7B5D13E0376A1E0E4423A8cE26e;

  // Rate Strategy contract
  address public constant RATE_STRATEGY =
    0x03733F4E008d36f2e37F0080fF1c8DF756622E6F;

  // Params to set reserve as collateral
  uint256 public constant COL_LTV = 5000; // 50%
  uint256 public constant COL_LIQ_THRESHOLD = 6500; // 65%
  uint256 public constant COL_LIQ_BONUS = 11000; // 10%

  // Reserve Factor
  uint256 public constant RESERVE_FACTOR = 2000; // 20%
  // Supply Cap
  uint256 public constant SUPPLY_CAP = 6_000_000; // 6m MaticX
  // Liquidation Protocol Fee
  uint256 public constant LIQ_PROTOCOL_FEE = 2000; // 20%

  // eMode category
  uint8 public constant EMODE_CATEGORY = 2;

  // TODO: Remove new eMode Category once stMATIC goes live
  uint16 public constant EMODE_LTV = 9250; // 92.5%
  uint16 public constant EMODE_LIQ_THRESHOLD = 9500; // 95%
  uint16 public constant EMODE_LIQ_BONUS = 10100; // 1%
  string public constant EMODE_LABEL = 'MATIC correlated';

  // TODO: Remove this once stMATIC goes live
  // Other assets affected
  address public constant WMATIC = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;

  function execute() external override {
    // ----------------------------
    // 1. New price feed on oracle
    // ----------------------------
    address[] memory assets = new address[](1);
    assets[0] = UNDERLYING;
    address[] memory sources = new address[](1);
    sources[0] = PRICE_FEED;

    AaveV3Polygon.ORACLE.setAssetSources(assets, sources);

    // ------------------------------------------------
    // 2. Listing of MaticX, with all its configurations
    // ------------------------------------------------

    ConfiguratorInputTypes.InitReserveInput[]
      memory initReserveInputs = new ConfiguratorInputTypes.InitReserveInput[](
        1
      );
    initReserveInputs[0] = ConfiguratorInputTypes.InitReserveInput({
      aTokenImpl: ATOKEN_IMPL,
      stableDebtTokenImpl: SDTOKEN_IMPL,
      variableDebtTokenImpl: VDTOKEN_IMPL,
      underlyingAssetDecimals: IERC20Metadata(UNDERLYING).decimals(),
      interestRateStrategyAddress: RATE_STRATEGY,
      underlyingAsset: UNDERLYING,
      treasury: AaveV3Polygon.COLLECTOR,
      incentivesController: INCENTIVES_CONTROLLER,
      aTokenName: ATOKEN_NAME,
      aTokenSymbol: ATOKEN_SYMBOL,
      variableDebtTokenName: VDTOKEN_NAME,
      variableDebtTokenSymbol: VDTOKEN_SYMBOL,
      stableDebtTokenName: SDTOKEN_NAME,
      stableDebtTokenSymbol: SDTOKEN_SYMBOL,
      params: bytes('')
    });

    IPoolConfigurator configurator = AaveV3Polygon.POOL_CONFIGURATOR;

    configurator.initReserves(initReserveInputs);

    // Enable Reserve as Collateral with parameters
    configurator.configureReserveAsCollateral(
      UNDERLYING,
      COL_LTV,
      COL_LIQ_THRESHOLD,
      COL_LIQ_BONUS
    );

    // Set Reserve Factor
    configurator.setReserveFactor(UNDERLYING, RESERVE_FACTOR);

    // Set Supply Cap for Isolation Mode
    configurator.setSupplyCap(UNDERLYING, SUPPLY_CAP);

    // Set Liquidation Protocol Fee
    configurator.setLiquidationProtocolFee(UNDERLYING, LIQ_PROTOCOL_FEE);

    // TODO: Remove this configuration once stMATIC goes live
    // Create new EMode Category
    configurator.setEModeCategory(
      EMODE_CATEGORY,
      EMODE_LTV,
      EMODE_LIQ_THRESHOLD,
      EMODE_LIQ_BONUS,
      address(0),
      EMODE_LABEL
    );

    // Set the Asset EMode Category ID 2 for MaticX
    configurator.setAssetEModeCategory(UNDERLYING, EMODE_CATEGORY);
    // TODO: Remove this configuration once stMATIC goes live
    configurator.setAssetEModeCategory(WMATIC, EMODE_CATEGORY);
  }
}
