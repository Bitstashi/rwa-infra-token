// contracts/RWAInfrastructureToken.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract RWAInfrastructureToken is ERC20, Ownable, ReentrancyGuard {
    struct AssetData { string assetType; uint256 value; string location; uint256 lastVerified; bool isVerified; }
    struct OracleNode { address nodeAddress; uint256 reputation; uint256 totalVerifications; bool isActive; }

    mapping(uint256 => AssetData) public assets;
    mapping(address => OracleNode) public oracleNodes;
    mapping(uint256 => mapping(address => uint256)) public assetValueFeeds;
    uint256 public totalAssets;
    uint256 public verificationFee = 0.01 ether;
    uint256 public constant ORACLE_REWARD = 100 * 10**18;

    event AssetTokenized(uint256 indexed assetId, string assetType, uint256 value);
    event AssetVerified(uint256 indexed assetId, address oracle, uint256 newValue);
    event OracleNodeRegistered(address indexed node);

    constructor() ERC20("RWA Infrastructure Token", "RWAI") Ownable() {
        _transferOwnership(0xeb9c754fF083DEE807c5D05583a619cCd0123053);
        _mint(msg.sender, 1_000_000 * 10**18);
    }

    function registerOracle() external payable {
        require(msg.value >= 0.1 ether, "Stake required");
        require(!oracleNodes[msg.sender].isActive, "Already registered");
        oracleNodes[msg.sender] = OracleNode(msg.sender, 100, 0, true);
        emit OracleNodeRegistered(msg.sender);
    }

    function tokenizeAsset(
        string memory _assetType,
        uint256 _value,
        string memory _location,
        uint256 _tokenAmount
    ) external payable nonReentrant {
        require(msg.value >= verificationFee, "Fee required");
        uint256 assetId = totalAssets++;
        assets[assetId] = AssetData(_assetType, _value, _location, block.timestamp, false);
        _mint(msg.sender, _tokenAmount);
        emit AssetTokenized(assetId, _assetType, _value);
    }

    function verifyAssetValue(uint256 _assetId, uint256 _newValue) external {
        OracleNode storage node = oracleNodes[msg.sender];
        require(node.isActive, "Not authorized");
        assetValueFeeds[_assetId][msg.sender] = _newValue;
        assets[_assetId].lastVerified = block.timestamp;
        _mint(msg.sender, ORACLE_REWARD);
        node.totalVerifications++;
        node.reputation += 10;
        emit AssetVerified(_assetId, msg.sender, _newValue);
    }

    function getAssetConsensusValue(uint256 _assetId) external view returns (uint256) {
        return assets[_assetId].value;
    }

    function updateVerificationFee(uint256 _newFee) external onlyOwner {
        verificationFee = _newFee;
    }

    function withdrawFees() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}
