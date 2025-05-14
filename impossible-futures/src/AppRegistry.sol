// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./interfaces/IAppRegistry.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract AppRegistry is IAppRegistry, Ownable {
    uint256 public appsCount;

    mapping(bytes32 => App) public apps;
    bytes32[] public appIds;

    constructor(address _autonomi) Ownable(_autonomi) {}

    /**
     * @dev See IAppRegistry - registerApp
     */
    function registerApp(
        address _controller,
        string calldata _name,
        string calldata _description,
        string calldata _appInfoURI
    ) external onlyOwner returns (bytes32 appId) {
        if (_controller == address(0)) {
            revert ZeroAddress();
        }

        if (_isStringEmpty(_name) || _isStringEmpty(_description) || _isStringEmpty(_appInfoURI)) {
            revert EmptyString();
        }

        appId = _appID(_controller, _name, _description);
        apps[appId] = App({
            id: appId,
            isInPhase2: false,
            isLive: false,
            controller: _controller,
            name: _name,
            description: _description,
            appInfoURI: _appInfoURI
        });
        appIds.push(appId);

        emit RegisteredApp(appId);
    }

    /**
     * @dev See IAppRegistry - changeAppController
     */
    function changeAppController(bytes32 _appId, address _controller) external onlyOwner {
        if (!_isRegisteredApp(_appId)) {
            revert AppNotRegistered();
        }

        if (_controller == address(0)) {
            revert ZeroAddress();
        }

        apps[_appId].controller = _controller;

        emit ChangedAppController(_appId, _controller);
    }

    /**
     * @dev See IAppRegistry - changeAppInfoURI
     */
    function changeAppInfoURI(bytes32 _appId, string calldata _appInfoURI) external onlyOwner {
        if (!_isRegisteredApp(_appId)) {
            revert AppNotRegistered();
        }

        if (_isStringEmpty(_appInfoURI)) {
            revert EmptyString();
        }

        apps[_appId].appInfoURI = _appInfoURI;

        emit ChangedAppInfoURI(_appId, _appInfoURI);
    }

    /**
     * @dev See IAppRegistry - isRegisteredApp
     */
    function isRegisteredApp(bytes32 appId) external view returns (bool) {
        return _isRegisteredApp(appId);
    }

    /**
     * @dev See IAppRegistry - isInPhase2
     */
    function isInPhase2(bytes32 appId) external view returns (bool) {
        return apps[appId].isInPhase2;
    }

    /**
     * @dev See IAppRegistry - isLive
     */
    function isLive(bytes32 appId) external view returns (bool) {
        return apps[appId].isLive;
    }

    /**
     * @dev See IAppRegistry - setAppIsInPhase2
     */
    function setAppIsInPhase2(bytes32 _appId, bool _isInPhase2) external onlyOwner {
        if (!_isRegisteredApp(_appId)) {
            revert AppNotRegistered();
        }

        apps[_appId].isInPhase2 = _isInPhase2;

        emit SetAppIsInPhase2(_appId, _isInPhase2);
    }

    /**
     * @dev See IAppRegistry - setAppLive
     */
    function setAppLive(bytes32 _appId, bool _isLive) external onlyOwner {
        if (!_isRegisteredApp(_appId)) {
            revert AppNotRegistered();
        }

        apps[_appId].isLive = _isLive;

        emit SetAppIsLive(_appId, _isLive);
    }

    /**
     * @dev See IAppRegistry - getAppIds
     */
    function getAppIds() external view returns (bytes32[] memory) {
        return appIds;
    }

    /**
     * @dev See IAppRegistry - getAppsLength
     */
    function getAppsLength() external view returns (uint256) {
        return appIds.length;
    }

    function _appID(address _controller, string calldata _name, string calldata _description)
        internal
        returns (bytes32)
    {
        return keccak256(
            abi.encode(msg.sender, address(this), _controller, _name, _description, block.timestamp, ++appsCount)
        );
    }

    function _isRegisteredApp(bytes32 _appId) internal view returns (bool) {
        return apps[_appId].id != bytes32(0);
    }

    function _isStringEmpty(string memory _input) internal pure returns (bool) {
        return bytes(_input).length == 0;
    }
}
