// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract AutonomiNFT is ERC721Enumerable, Ownable {
    using Strings for uint256;

    event SetTokenURI(string indexed newTokenURI);
    event SetAntAllocationForTokenId(uint256 indexed tokenId, uint256 indexed antAllocation);

    error ClaimsAlreadyStarted();

    error ZeroAllocationNotAllowed();

    string private _baseTokenURI;

    mapping(uint256 => uint256) public tokenIdToAntAllocation;

    struct AntAllocation {
        uint256 tokenId;
        uint256 antAllocation;
    }

    modifier onlyBeforeFirstVestingPeriod() {
        uint256 vestingStartTimestamp = 1739282400;
        uint256 vestingPeriod1 = 90 days;
        if (block.timestamp >= vestingStartTimestamp + vestingPeriod1) {
            revert ClaimsAlreadyStarted();
        }
        _;
    }

    constructor(string memory name, string memory symbol, string memory baseTokenURI)
        ERC721(name, symbol)
        Ownable(msg.sender)
    {
        _baseTokenURI = baseTokenURI;
    }

    function mint(address to, AntAllocation calldata allocation) external onlyOwner {
        if (allocation.antAllocation == 0) {
            revert ZeroAllocationNotAllowed();
        }

        _safeMint(to, allocation.tokenId);
        _setAntAllocationForTokenId(allocation.tokenId, allocation.antAllocation);
    }

    function mintMultiple(address[] calldata to, AntAllocation[] calldata allocations) external onlyOwner {
        uint256 allocationsLength = allocations.length;
        require(to.length == allocationsLength, "Invalid array length");
        for (uint256 i = 0; i < allocationsLength; i++) {
            if (allocations[i].antAllocation == 0) {
                revert ZeroAllocationNotAllowed();
            }

            _safeMint(to[i], allocations[i].tokenId);
            _setAntAllocationForTokenId(allocations[i].tokenId, allocations[i].antAllocation);
        }
    }

    function setAntAllocationForTokenId(AntAllocation calldata allocation)
        external
        onlyOwner
        onlyBeforeFirstVestingPeriod
    {
        _setAntAllocationForTokenId(allocation.tokenId, allocation.antAllocation);
    }

    function setAntAllocationsForTokenIds(AntAllocation[] calldata allocations)
        external
        onlyOwner
        onlyBeforeFirstVestingPeriod
    {
        uint256 allocationsLength = allocations.length;
        for (uint256 i = 0; i < allocationsLength; i++) {
            _setAntAllocationForTokenId(allocations[i].tokenId, allocations[i].antAllocation);
        }
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        _requireOwned(tokenId);

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString(), ".json")) : "";
    }

    function setTokenURI(string calldata newTokenURI) external onlyOwner {
        _baseTokenURI = newTokenURI;
        emit SetTokenURI(newTokenURI);
    }

    function _setAntAllocationForTokenId(uint256 tokenId, uint256 antAllocation) internal {
        _requireOwned(tokenId);
        tokenIdToAntAllocation[tokenId] = antAllocation;

        emit SetAntAllocationForTokenId(tokenId, antAllocation);
    }
}
