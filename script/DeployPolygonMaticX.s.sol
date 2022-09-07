// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@forge-std/console.sol';
import {Script} from '@forge-std/Script.sol';
import {MaticXPayload} from '../src/contracts/polygon/MaticXPayload.sol';

contract DeployPolygonMaticX is Script {
  function run() external {
    vm.startBroadcast();
    MaticXPayload maticxPayload = new MaticXPayload();
    console.log('MaticX Payload address', address(maticxPayload));
    vm.stopBroadcast();
  }
}
