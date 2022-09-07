// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@forge-std/Test.sol';
import {GovHelpers} from '@aave-helpers/GovHelpers.sol';
import {AaveGovernanceV2, IExecutorWithTimelock} from '@aave-address-book/AaveGovernanceV2.sol';

import {CrosschainForwarderPolygon} from '../contracts/polygon/CrosschainForwarderPolygon.sol';
import {MaticXPayload} from '../contracts/polygon/MaticXPayload.sol';
import {IStateReceiver} from '../interfaces/IFx.sol';
import {IBridgeExecutor} from '../interfaces/IBridgeExecutor.sol';
import {AaveV3Helpers, ReserveConfig, ReserveTokens, IERC20} from './helpers/AaveV3Helpers.sol';
import {DeployL1PolygonProposal} from '../../script/DeployL1PolygonProposal.s.sol';

contract PolygonMaticXE2ETest is Test {
  // the identifiers of the forks
  uint256 mainnetFork;
  uint256 polygonFork;

  MaticXPayload public maticXPayload;

  address public constant CROSSCHAIN_FORWARDER_POLYGON =
    0x158a6bC04F0828318821baE797f50B0A1299d45b;
  address public constant BRIDGE_ADMIN =
    0x0000000000000000000000000000000000001001;
  address public constant FX_CHILD_ADDRESS =
    0x8397259c983751DAf40400790063935a11afa28a;
  address public constant POLYGON_BRIDGE_EXECUTOR =
    0xdc9A35B16DB4e126cFeDC41322b3a36454B1F772;

  address public constant MATICX = 0xfa68FB4628DFF1028CFEc22b4162FCcd0d45efb6;
  address public constant MATICX_WHALE =
    0xb0e69f24982791dd49e316313fD3A791020B8bF7;

  address public constant DAI = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;
  address public constant DAI_WHALE =
    0xd7052EC0Fe1fe25b20B7D65F6f3d490fCE58804f;

  address public constant AAVE_WHALE =
    address(0x25F2226B597E8F9514B3F68F00f494cF4f286491);

  function setUp() public {
    polygonFork = vm.createFork(vm.rpcUrl('polygon'), 32817935);
    mainnetFork = vm.createSelectFork(vm.rpcUrl('mainnet'), 15492382);
  }

  // utility to transform memory to calldata so array range access is available
  function _cutBytes(bytes calldata input)
    public
    pure
    returns (bytes calldata)
  {
    return input[64:];
  }

  // Execute StMatic Proposal to set eMode Category of 2
  // Can be removed once stMATIC actually executes on Mainnet
  function executeStMaticProposal() private {
    // stMATIC listing Proposal ID
    uint256 proposalId = 99;

    // execute proposal and record logs so we can extract the emitted StateSynced event
    vm.selectFork(mainnetFork);
    vm.recordLogs();
    GovHelpers.passVoteAndExecute(vm, proposalId);

    Vm.Log[] memory entries = vm.getRecordedLogs();
    assertEq(
      keccak256('StateSynced(uint256,address,bytes)'),
      entries[2].topics[0]
    );
    assertEq(address(uint160(uint256(entries[2].topics[2]))), FX_CHILD_ADDRESS);

    // mock the receive on l2 with the data emitted on StateSynced
    vm.selectFork(polygonFork);
    vm.startPrank(BRIDGE_ADMIN);
    IStateReceiver(FX_CHILD_ADDRESS).onStateReceive(
      uint256(entries[2].topics[1]),
      this._cutBytes(entries[2].data)
    );
    vm.stopPrank();

    // execute proposal on l2
    vm.warp(
      block.timestamp + IBridgeExecutor(POLYGON_BRIDGE_EXECUTOR).getDelay() + 1
    );

    // execute the proposal
    IBridgeExecutor(POLYGON_BRIDGE_EXECUTOR).execute(
      IBridgeExecutor(POLYGON_BRIDGE_EXECUTOR).getActionsSetCount() - 1
    );
  }

  function testProposalE2E() public {
    // Execute StMatic Proposal to set eMode Category of 2
    // Can be removed once stMATIC actually executes on Mainnet
    executeStMaticProposal();

    vm.selectFork(polygonFork);

    // we get all configs to later on check that payload only changes MaticX
    ReserveConfig[] memory allConfigsBefore = AaveV3Helpers._getReservesConfigs(
      false
    );

    // 1. deploy l2 payload
    vm.selectFork(polygonFork);
    maticXPayload = new MaticXPayload();

    // 2. create l1 proposal
    vm.selectFork(mainnetFork);
    vm.startPrank(AAVE_WHALE);
    uint256 proposalId = DeployL1PolygonProposal._deployL1Proposal(
      address(maticXPayload),
      0x344d3181f08b3186228b93bac0005a3a961238164b8b06cbb5f0428a9180b8a7 // TODO: Replace with actual MaticX IPFS Hash
    );
    vm.stopPrank();

    // 3. execute proposal and record logs so we can extract the emitted StateSynced event
    vm.recordLogs();
    GovHelpers.passVoteAndExecute(vm, proposalId);

    Vm.Log[] memory entries = vm.getRecordedLogs();
    assertEq(
      keccak256('StateSynced(uint256,address,bytes)'),
      entries[2].topics[0]
    );
    assertEq(address(uint160(uint256(entries[2].topics[2]))), FX_CHILD_ADDRESS);

    // 4. mock the receive on l2 with the data emitted on StateSynced
    vm.selectFork(polygonFork);
    vm.startPrank(BRIDGE_ADMIN);
    IStateReceiver(FX_CHILD_ADDRESS).onStateReceive(
      uint256(entries[2].topics[1]),
      this._cutBytes(entries[2].data)
    );
    vm.stopPrank();

    // 5. execute proposal on l2
    vm.warp(
      block.timestamp + IBridgeExecutor(POLYGON_BRIDGE_EXECUTOR).getDelay() + 1
    );
    // execute the proposal
    IBridgeExecutor(POLYGON_BRIDGE_EXECUTOR).execute(
      IBridgeExecutor(POLYGON_BRIDGE_EXECUTOR).getActionsSetCount() - 1
    );

    // 6. verify results
    ReserveConfig[] memory allConfigsAfter = AaveV3Helpers._getReservesConfigs(
      false
    );

    ReserveConfig memory expectedAssetConfig = ReserveConfig({
      symbol: 'MaticX',
      underlying: MATICX,
      aToken: address(0), // Mock, as they don't get validated, because of the "dynamic" deployment on proposal execution
      variableDebtToken: address(0), // Mock, as they don't get validated, because of the "dynamic" deployment on proposal execution
      stableDebtToken: address(0), // Mock, as they don't get validated, because of the "dynamic" deployment on proposal execution
      decimals: 18,
      ltv: 5000,
      liquidationThreshold: 6500,
      liquidationBonus: 11000,
      liquidationProtocolFee: 2000,
      reserveFactor: 2000,
      usageAsCollateralEnabled: true,
      borrowingEnabled: false,
      interestRateStrategy: AaveV3Helpers
        ._findReserveConfig(allConfigsAfter, 'MaticX', true)
        .interestRateStrategy,
      stableBorrowRateEnabled: false,
      isActive: true,
      isFrozen: false,
      isSiloed: false,
      supplyCap: 6_000_000,
      borrowCap: 0,
      debtCeiling: 0,
      eModeCategory: 2
    });

    AaveV3Helpers._validateReserveConfig(expectedAssetConfig, allConfigsAfter);

    AaveV3Helpers._noReservesConfigsChangesApartNewListings(
      allConfigsBefore,
      allConfigsAfter
    );

    AaveV3Helpers._validateReserveTokensImpls(
      vm,
      AaveV3Helpers._findReserveConfig(allConfigsAfter, 'MaticX', false),
      ReserveTokens({
        aToken: maticXPayload.ATOKEN_IMPL(),
        stableDebtToken: maticXPayload.SDTOKEN_IMPL(),
        variableDebtToken: maticXPayload.VDTOKEN_IMPL()
      })
    );

    AaveV3Helpers._validateAssetSourceOnOracle(
      MATICX,
      maticXPayload.PRICE_FEED()
    );

    // Reserve token implementation contracts should be same as USDC
    AaveV3Helpers._validateReserveTokensImpls(
      vm,
      AaveV3Helpers._findReserveConfig(allConfigsAfter, 'USDC', false),
      ReserveTokens({
        aToken: maticXPayload.ATOKEN_IMPL(),
        stableDebtToken: maticXPayload.SDTOKEN_IMPL(),
        variableDebtToken: maticXPayload.VDTOKEN_IMPL()
      })
    );

    string[] memory expectedAssetsEmode = new string[](3);
    expectedAssetsEmode[0] = 'WMATIC';
    expectedAssetsEmode[1] = 'stMATIC';
    expectedAssetsEmode[2] = 'MaticX';

    AaveV3Helpers._validateAssetsOnEmodeCategory(
      2,
      allConfigsAfter,
      expectedAssetsEmode
    );

    _validatePoolActionsPostListing(allConfigsAfter);
  }

  function _validatePoolActionsPostListing(
    ReserveConfig[] memory allReservesConfigs
  ) internal {
    address aMATICX = AaveV3Helpers
      ._findReserveConfig(allReservesConfigs, 'MaticX', false)
      .aToken;
    address vMATICX = AaveV3Helpers
      ._findReserveConfig(allReservesConfigs, 'MaticX', false)
      .variableDebtToken;
    address sMATICX = AaveV3Helpers
      ._findReserveConfig(allReservesConfigs, 'MaticX', false)
      .stableDebtToken;
    address vDAI = AaveV3Helpers
      ._findReserveConfig(allReservesConfigs, 'DAI', false)
      .variableDebtToken;

    // Deposit MATICX from MATICX Whale and receive aMATICX
    AaveV3Helpers._deposit(
      vm,
      MATICX_WHALE,
      MATICX_WHALE,
      MATICX,
      666 ether,
      true,
      aMATICX
    );

    // Testing borrowing of DAI against MATICX as collateral
    AaveV3Helpers._borrow(
      vm,
      MATICX_WHALE,
      MATICX_WHALE,
      DAI,
      2 ether,
      2,
      vDAI
    );

    // Expecting to Revert with error code '30' ('BORROWING_NOT_ENABLED') for stable rate borrowing
    // https://github.com/aave/aave-v3-core/blob/master/contracts/protocol/libraries/helpers/Errors.sol#L39
    vm.expectRevert(bytes('30'));
    AaveV3Helpers._borrow(
      vm,
      MATICX_WHALE,
      MATICX_WHALE,
      MATICX,
      10 ether,
      1,
      sMATICX
    );
    vm.stopPrank();

    // Expecting to Revert with error code '30' ('BORROWING_NOT_ENABLED') for variable rate borrowing
    // https://github.com/aave/aave-v3-core/blob/master/contracts/protocol/libraries/helpers/Errors.sol#L39
    vm.expectRevert(bytes('30'));
    AaveV3Helpers._borrow(
      vm,
      MATICX_WHALE,
      MATICX_WHALE,
      MATICX,
      10 ether,
      2,
      vMATICX
    );
    vm.stopPrank();

    // Transferring some extra DAI to MATICX whale for repaying back the loan.
    vm.startPrank(DAI_WHALE);
    IERC20(DAI).transfer(MATICX_WHALE, 300 ether);
    vm.stopPrank();

    // Not possible to borrow and repay when vdebt index doesn't changing, so moving ahead 10000s
    skip(10000);

    // Repaying back DAI loan
    AaveV3Helpers._repay(
      vm,
      MATICX_WHALE,
      MATICX_WHALE,
      DAI,
      IERC20(DAI).balanceOf(MATICX_WHALE),
      2,
      vDAI,
      true
    );

    // Withdrawing MATICX
    AaveV3Helpers._withdraw(
      vm,
      MATICX_WHALE,
      MATICX_WHALE,
      MATICX,
      type(uint256).max,
      aMATICX
    );
  }
}
