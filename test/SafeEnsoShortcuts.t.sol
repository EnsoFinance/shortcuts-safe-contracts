// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";
import {SafeTestTools, SafeTestLib, SafeInstance, Enum} from "safe-tools/SafeTestTools.sol";
import {Deployer, DeployerResult} from "../script/Deployer.s.sol";
import {SafeEnsoShortcuts} from "../src/SafeEnsoShortcuts.sol";
import {WeirollPlanner} from "./utils/WeirollPlanner.sol";

contract SafeEnsoShortcutsTest is Test, SafeTestTools {
    using SafeTestLib for SafeInstance;

    SafeEnsoShortcuts shortcuts;
    SafeInstance safeInstance;

    address alice = makeAddr("alice");

    function setUp() public {
        address deployer = vm.addr(vm.envUint("PRIVATE_KEY"));
        deal(deployer, 1 ether);

        DeployerResult memory result = new Deployer().run();

        shortcuts = result.shortcuts;

        safeInstance = _setupSafe();
    }

    function testSafeCanRunShortcutTransferringERC20() public {
        bytes32[] memory commands = new bytes32[](1);
        commands[0] = WeirollPlanner.buildCommand(
            weth.transfer.selector,
            0x01, // call
            0x0001ffffffff, // 2 inputs
            0xff, // no output
            address(this)
        );

        bytes[] memory state = new bytes[](2);
        state[0] = abi.encode(alice);
        state[1] = abi.encode(10 ether);

        bytes memory data = abi.encodeCall(SafeEnsoShortcuts.executeShortcut, (bytes32(0), commands, state));

        assertEq(weth.balanceOf(address(safeInstance.safe)), 0);
        assertEq(weth.balanceOf(alice), 0);

        deal(address(weth), address(safeInstance.safe), 10 ether);

        assertEq(weth.balanceOf(address(safeInstance.safe)), 10 ether);
        assertEq(weth.balanceOf(alice), 0);

        safeInstance.execTransaction({
            to: address(shortcuts),
            value: 0 ether,
            data: data,
            operation: Enum.Operation.DelegateCall
        });

        assertEq(weth.balanceOf(address(safeInstance.safe)), 0);
        assertEq(weth.balanceOf(alice), 10 ether);
    }
}
