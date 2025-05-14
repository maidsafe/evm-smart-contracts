// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IAppRegistry {
    error ZeroAddress();
    error EmptyString();
    error AppNotRegistered();

    event RegisteredApp(bytes32 indexed appId);

    event ChangedAppController(bytes32 indexed appId, address indexed controller);
    event ChangedAppInfoURI(bytes32 indexed appId, string indexed appInfoURI);
    event SetAppIsLive(bytes32 indexed appId, bool indexed isLive);
    event SetAppIsInPhase2(bytes32 indexed appId, bool indexed isInPhase2);

    /**
     * @dev Represents an App that is registered in the system
     *
     * @param id The app ID uniquely identifying this app
     * @param isPhase2 Whether the app proceeded to phase 2
     * @param isLive Whether the app is live on mainnet
     * @param controller The EVM address associated with this app. Will be used to distribute rewards to.
     * @param name The name of the app
     * @param description The description of the app
     * @param appInfoURI A link to a web page that contains more information about the app
     */
    struct App {
        bytes32 id;
        bool isInPhase2;
        bool isLive;
        address controller;
        string name;
        string description;
        string appInfoURI;
    }

    /**
     * @dev Registers an app to the AppRegistry. Only allowed by autonomi.
     *
     * @param _controller The controller for the app
     * @param _name The name of the app
     * @param _description The description of the app
     * @param _appInfoURI Link to a web page with more info about the app
     */
    function registerApp(
        address _controller,
        string calldata _name,
        string calldata _description,
        string calldata _appInfoURI
    ) external returns (bytes32 appId);

    /**
     * @dev Changes the app controller registered for this app. Only allowed by autonomi.
     *
     * @param _appId The ID of the app.
     * @param _controller The new app controller.
     */
    function changeAppController(bytes32 _appId, address _controller) external;

    /**
     * @dev Changes the app info URI for the registered app. Only allowed by autonomi.
     *
     * @param _appId The ID of the app.
     * @param _appInfoURI The new app info URI.
     */
    function changeAppInfoURI(bytes32 _appId, string calldata _appInfoURI) external;

    /**
     * @dev Sets the app to proceeded to phase 2 state. Only allowed by autonomi.
     *
     * @param _appId The ID of the app.
     * @param _isInPhase2 The new value for isInPhase2.
     */
    function setAppIsInPhase2(bytes32 _appId, bool _isInPhase2) external;

    /**
     * @dev Sets the app to live state. Only allowed by autonomi.
     *
     * @param _appId The ID of the app.
     * @param _isLive The new value for isLive.
     */
    function setAppLive(bytes32 _appId, bool _isLive) external;

    /**
     * @dev Returns all the registered app IDs
     */
    function getAppIds() external view returns (bytes32[] memory);

    /**
     * @dev Returns the number of apps registered
     */
    function getAppsLength() external view returns (uint256);

    /**
     * @dev Returns a bool determining whether an app is registered or not
     */
    function isRegisteredApp(bytes32 appId) external view returns (bool);

    /**
     * @dev Returns a bool determining whether an app is in phase 2 or not
     */
    function isInPhase2(bytes32 appId) external view returns (bool);

    /**
     * @dev Returns a bool determining whether an app is live or not
     */
    function isLive(bytes32 appId) external view returns (bool);
}
