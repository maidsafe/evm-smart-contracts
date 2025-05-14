// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import "./Helper.sol";
import "../src/AppRegistry.sol";

contract AppRegistryTest is Helper {
    AppRegistry public appRegistry;

    function setUp() public {
        vm.startPrank(dev);
        forkArbitrum();

        appRegistry = new AppRegistry(dev);
        vm.stopPrank();
    }

    /* 
       ====================================== 
       ============ registerApp =============
       ======================================
    */
    function test_registerApp() public {
        vm.prank(dev);
        bytes32 expectedAppId =
            keccak256(abi.encode(dev, address(appRegistry), dev, "TestApp", "This is a test app", block.timestamp, 1));

        vm.expectEmit(true, false, false, false);
        emit IAppRegistry.RegisteredApp(expectedAppId);

        appRegistry.registerApp(dev, "TestApp", "This is a test app", "https://example.com");

        vm.assertTrue(appRegistry.isRegisteredApp(expectedAppId));

        bytes32[] memory appsList = appRegistry.getAppIds();
        assertEq(appsList.length, 1);
        assertEq(appsList[0], expectedAppId);

        assertEq(appRegistry.getAppsLength(), 1);
        vm.stopPrank();

        (
            bytes32 id,
            bool isInPhase2,
            bool isLive,
            address controller,
            string memory name,
            string memory description,
            string memory appInfoURI
        ) = appRegistry.apps(expectedAppId);

        assertEq(id, expectedAppId);
        assertFalse(isInPhase2);
        assertFalse(isLive);
        assertEq(controller, dev);
        assertEq(name, "TestApp");
        assertEq(description, "This is a test app");
        assertEq(appInfoURI, "https://example.com");
    }

    function test_cannot_registerApp_NotAutonomi() public {
        vm.prank(users[2]);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users[2]));
        appRegistry.registerApp(dev, "TestApp", "This is a test app", "https://example.com");
    }

    function test_cannot_registerApp_ZeroAddress() public {
        vm.prank(dev);
        vm.expectRevert(IAppRegistry.ZeroAddress.selector);
        appRegistry.registerApp(address(0), "TestApp", "This is a test app", "https://example.com");
    }

    function test_cannot_registerApp_EmptyString() public {
        vm.prank(dev);
        vm.expectRevert(IAppRegistry.EmptyString.selector);
        appRegistry.registerApp(dev, "", "This is a test app", "https://example.com");

        vm.prank(dev);
        vm.expectRevert(IAppRegistry.EmptyString.selector);
        appRegistry.registerApp(dev, "TestApp", "", "https://example.com");

        vm.prank(dev);
        vm.expectRevert(IAppRegistry.EmptyString.selector);
        appRegistry.registerApp(dev, "TestApp", "This is a test app", "");
    }

    /* 
       ====================================== 
       ======== changeAppController =========
       ======================================
    */
    function test_changeAppController() public {
        vm.startPrank(dev);
        appRegistry.registerApp(dev, "TestApp", "This is a test app", "https://example.com");

        bytes32 expectedAppId =
            keccak256(abi.encode(dev, address(appRegistry), dev, "TestApp", "This is a test app", block.timestamp, 1));

        vm.expectEmit(true, true, false, false);
        emit IAppRegistry.ChangedAppController(expectedAppId, users[1]);
        appRegistry.changeAppController(expectedAppId, users[1]);

        (,,, address controller,,,) = appRegistry.apps(expectedAppId);
        assertEq(controller, users[1]);

        vm.stopPrank();
    }

    function test_cannot_changeAppController_NotAutonomi() public {
        vm.prank(dev);
        appRegistry.registerApp(dev, "TestApp", "This is a test app", "https://example.com");

        bytes32 expectedAppId =
            keccak256(abi.encode(dev, address(appRegistry), dev, "TestApp", "This is a test app", block.timestamp, 1));

        vm.prank(users[2]);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users[2]));
        appRegistry.changeAppController(expectedAppId, users[1]);
    }

    function test_cannot_changeAppController_AppNotRegistered() public {
        vm.prank(dev);
        bytes32 expectedAppId =
            keccak256(abi.encode(dev, address(appRegistry), dev, "TestApp", "This is a test app", block.timestamp, 1));

        vm.expectRevert(IAppRegistry.AppNotRegistered.selector);
        appRegistry.changeAppController(expectedAppId, users[1]);
    }

    function test_cannot_changeAppController_ZeroAddress() public {
        vm.startPrank(dev);
        appRegistry.registerApp(dev, "TestApp", "This is a test app", "https://example.com");

        bytes32 expectedAppId =
            keccak256(abi.encode(dev, address(appRegistry), dev, "TestApp", "This is a test app", block.timestamp, 1));

        vm.expectRevert(IAppRegistry.ZeroAddress.selector);
        appRegistry.changeAppController(expectedAppId, address(0));

        vm.stopPrank();
    }

    /* 
       ====================================== 
       ========== changeAppInfoURI ==========
       ======================================
    */
    function test_changeAppInfoURI() public {
        vm.startPrank(dev);
        appRegistry.registerApp(dev, "TestApp", "This is a test app", "https://example.com");

        bytes32 expectedAppId =
            keccak256(abi.encode(dev, address(appRegistry), dev, "TestApp", "This is a test app", block.timestamp, 1));

        vm.expectEmit(true, true, false, false);
        emit IAppRegistry.ChangedAppInfoURI(expectedAppId, "https://test.com");

        appRegistry.changeAppInfoURI(expectedAppId, "https://test.com");

        vm.stopPrank();
    }

    function test_cannot_changeAppInfoURI_NotAutonomi() public {
        vm.prank(dev);
        appRegistry.registerApp(dev, "TestApp", "This is a test app", "https://example.com");

        bytes32 expectedAppId =
            keccak256(abi.encode(dev, address(appRegistry), dev, "TestApp", "This is a test app", block.timestamp, 1));

        vm.prank(users[2]);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users[2]));
        appRegistry.changeAppInfoURI(expectedAppId, "https://test.com");
    }

    function test_cannot_changeAppInfoURI_AppNotRegistered() public {
        vm.prank(dev);
        bytes32 expectedAppId =
            keccak256(abi.encode(dev, address(appRegistry), dev, "TestApp", "This is a test app", block.timestamp, 1));

        vm.expectRevert(IAppRegistry.AppNotRegistered.selector);
        appRegistry.changeAppInfoURI(expectedAppId, "https://test.com");
    }

    function test_cannot_changeAppInfoURI_EmptyString() public {
        vm.startPrank(dev);
        appRegistry.registerApp(dev, "TestApp", "This is a test app", "https://example.com");

        bytes32 expectedAppId =
            keccak256(abi.encode(dev, address(appRegistry), dev, "TestApp", "This is a test app", block.timestamp, 1));

        vm.expectRevert(IAppRegistry.EmptyString.selector);
        appRegistry.changeAppInfoURI(expectedAppId, "");

        vm.stopPrank();
    }

    /* 
       ====================================== 
       ========== setAppIsInPhase2 ==========
       ======================================
    */
    function test_setAppIsInPhase2() public {
        vm.startPrank(dev);
        appRegistry.registerApp(dev, "TestApp", "This is a test app", "https://example.com");

        bytes32 expectedAppId =
            keccak256(abi.encode(dev, address(appRegistry), dev, "TestApp", "This is a test app", block.timestamp, 1));

        vm.expectEmit(true, true, false, false);
        emit IAppRegistry.SetAppIsInPhase2(expectedAppId, true);
        appRegistry.setAppIsInPhase2(expectedAppId, true);

        (, bool isInPhase2,,,,,) = appRegistry.apps(expectedAppId);
        assertTrue(isInPhase2);

        vm.stopPrank();
    }

    function test_cannot_setAppIsInPhase2_NotAutonomi() public {
        vm.prank(dev);
        appRegistry.registerApp(dev, "TestApp", "This is a test app", "https://example.com");

        bytes32 expectedAppId =
            keccak256(abi.encode(dev, address(appRegistry), dev, "TestApp", "This is a test app", block.timestamp, 1));

        vm.prank(users[2]);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users[2]));
        appRegistry.setAppIsInPhase2(expectedAppId, true);
    }

    function test_cannot_setAppIsInPhase2_AppNotRegistered() public {
        bytes32 expectedAppId =
            keccak256(abi.encode(dev, address(appRegistry), dev, "TestApp", "This is a test app", block.timestamp, 1));

        vm.prank(dev);
        vm.expectRevert(IAppRegistry.AppNotRegistered.selector);
        appRegistry.setAppIsInPhase2(expectedAppId, true);
    }

    /* 
       ====================================== 
       ============= setAppLive =============
       ======================================
    */
    function test_setAppLive() public {
        vm.startPrank(dev);
        appRegistry.registerApp(dev, "TestApp", "This is a test app", "https://example.com");

        bytes32 expectedAppId =
            keccak256(abi.encode(dev, address(appRegistry), dev, "TestApp", "This is a test app", block.timestamp, 1));

        vm.expectEmit(true, true, false, false);
        emit IAppRegistry.SetAppIsLive(expectedAppId, true);
        appRegistry.setAppLive(expectedAppId, true);

        (,, bool isLive,,,,) = appRegistry.apps(expectedAppId);
        assertTrue(isLive);

        vm.stopPrank();
    }

    function test_cannot_setAppLive_NotAutonomi() public {
        vm.prank(dev);
        appRegistry.registerApp(dev, "TestApp", "This is a test app", "https://example.com");

        bytes32 expectedAppId =
            keccak256(abi.encode(dev, address(appRegistry), dev, "TestApp", "This is a test app", block.timestamp, 1));

        vm.prank(users[2]);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, users[2]));
        appRegistry.setAppLive(expectedAppId, true);
    }

    function test_cannot_setAppLive_AppNotRegistered() public {
        bytes32 expectedAppId =
            keccak256(abi.encode(dev, address(appRegistry), dev, "TestApp", "This is a test app", block.timestamp, 1));

        vm.prank(dev);
        vm.expectRevert(IAppRegistry.AppNotRegistered.selector);
        appRegistry.setAppLive(expectedAppId, true);
    }

    /* 
       ====================================== 
       ========== isRegisteredApp ===========
       ======================================
    */
    function test_isRegisteredApp() public {
        vm.prank(dev);
        appRegistry.registerApp(dev, "TestApp", "This is a test app", "https://example.com");

        bytes32 expectedAppId =
            keccak256(abi.encode(dev, address(appRegistry), dev, "TestApp", "This is a test app", block.timestamp, 1));

        assertTrue(appRegistry.isRegisteredApp(expectedAppId));
    }

    /* 
       ====================================== 
       ============= getAppIds ==============
       ======================================
    */
    function test_getAppIds() public {
        vm.prank(dev);
        appRegistry.registerApp(dev, "TestApp", "This is a test app", "https://example.com");

        bytes32 expectedAppId =
            keccak256(abi.encode(dev, address(appRegistry), dev, "TestApp", "This is a test app", block.timestamp, 1));

        bytes32[] memory appsList = appRegistry.getAppIds();
        assertEq(appsList.length, 1);
        assertEq(appsList[0], expectedAppId);
    }

    /* 
       ====================================== 
       =========== getAppsLength ============
       ======================================
    */
    function test_getAppsLength() public {
        vm.prank(dev);
        appRegistry.registerApp(dev, "TestApp", "This is a test app", "https://example.com");

        uint256 appsLength = appRegistry.getAppsLength();
        assertEq(appsLength, 1);
    }
}
