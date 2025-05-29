// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title Carbon Credit Marketplace with IoT Integration
 * @dev A decentralized marketplace for carbon credits verified through IoT sensors
 */
contract Project is ERC721, Ownable, ReentrancyGuard {
    
    // Struct to represent a carbon credit NFT
    struct CarbonCredit {
        uint256 id;
        address producer;
        uint256 carbonReduced; // in kg CO2
        string projectType; // "solar", "forest", "wind", etc.
        uint256 timestamp;
        string iotDeviceId;
        bool isVerified;
        uint256 price; // in wei
        bool forSale;
    }
    
    // Struct for IoT device registration
    struct IoTDevice {
        string deviceId;
        address owner;
        string deviceType;
        bool isActive;
        uint256 lastDataTimestamp;
    }
    
    // State variables
    uint256 private _tokenIdCounter;
    mapping(uint256 => CarbonCredit) public carbonCredits;
    mapping(string => IoTDevice) public iotDevices;
    mapping(address => bool) public verifiedProducers;
    
    // Events
    event CarbonCreditMinted(uint256 indexed tokenId, address indexed producer, uint256 carbonReduced);
    event CarbonCreditListed(uint256 indexed tokenId, uint256 price);
    event CarbonCreditSold(uint256 indexed tokenId, address indexed buyer, uint256 price);
    event IoTDeviceRegistered(string deviceId, address indexed owner);
    event DataVerified(string deviceId, uint256 carbonReduced);
    
    constructor() ERC721("CarbonCredit", "CCR") Ownable(msg.sender) {}
    
    /**
     * @dev Core Function 1: Register IoT Device
     * @param _deviceId Unique identifier for the IoT device
     * @param _deviceType Type of device (solar_meter, forest_sensor, etc.)
     */
    function registerIoTDevice(
        string memory _deviceId,
        string memory _deviceType
    ) external {
        require(bytes(_deviceId).length > 0, "Device ID cannot be empty");
        require(iotDevices[_deviceId].owner == address(0), "Device already registered");
        
        iotDevices[_deviceId] = IoTDevice({
            deviceId: _deviceId,
            owner: msg.sender,
            deviceType: _deviceType,
            isActive: true,
            lastDataTimestamp: block.timestamp
        });
        
        // Automatically verify producer when they register first device
        if (!verifiedProducers[msg.sender]) {
            verifiedProducers[msg.sender] = true;
        }
        
        emit IoTDeviceRegistered(_deviceId, msg.sender);
    }
    
    /**
     * @dev Core Function 2: Mint Carbon Credit based on IoT Data
     * @param _carbonReduced Amount of CO2 reduced in kg
     * @param _projectType Type of carbon reduction project
     * @param _iotDeviceId IoT device that verified the data
     */
    function mintCarbonCredit(
        uint256 _carbonReduced,
        string memory _projectType,
        string memory _iotDeviceId
    ) external nonReentrant {
        require(verifiedProducers[msg.sender], "Producer not verified");
        require(_carbonReduced > 0, "Carbon reduced must be greater than 0");
        require(iotDevices[_iotDeviceId].owner == msg.sender, "Not authorized for this device");
        require(iotDevices[_iotDeviceId].isActive, "IoT device not active");
        
        uint256 tokenId = _tokenIdCounter;
        _tokenIdCounter++;
        
        // Create carbon credit
        carbonCredits[tokenId] = CarbonCredit({
            id: tokenId,
            producer: msg.sender,
            carbonReduced: _carbonReduced,
            projectType: _projectType,
            timestamp: block.timestamp,
            iotDeviceId: _iotDeviceId,
            isVerified: true, // Auto-verified if from registered IoT device
            price: 0,
            forSale: false
        });
        
        // Mint NFT
        _safeMint(msg.sender, tokenId);
        
        // Update device timestamp
        iotDevices[_iotDeviceId].lastDataTimestamp = block.timestamp;
        
        emit CarbonCreditMinted(tokenId, msg.sender, _carbonReduced);
        emit DataVerified(_iotDeviceId, _carbonReduced);
    }
    
    /**
     * @dev Core Function 3: List and Purchase Carbon Credits
     * @param _tokenId ID of the carbon credit to list/purchase
     * @param _price Price in wei (0 for purchasing)
     */
    function tradeCarbonCredit(uint256 _tokenId, uint256 _price) external payable nonReentrant {
        require(_ownerOf(_tokenId) != address(0), "Carbon credit does not exist");
        
        if (_price > 0) {
            // Listing for sale
            require(ownerOf(_tokenId) == msg.sender, "Not the owner");
            require(!carbonCredits[_tokenId].forSale, "Already listed for sale");
            
            carbonCredits[_tokenId].price = _price;
            carbonCredits[_tokenId].forSale = true;
            
            emit CarbonCreditListed(_tokenId, _price);
            
        } else {
            // Purchasing
            require(carbonCredits[_tokenId].forSale, "Not for sale");
            require(msg.value == carbonCredits[_tokenId].price, "Incorrect payment amount");
            require(ownerOf(_tokenId) != msg.sender, "Cannot buy your own credit");
            
            address seller = ownerOf(_tokenId);
            uint256 salePrice = carbonCredits[_tokenId].price;
            
            // Reset sale status
            carbonCredits[_tokenId].forSale = false;
            carbonCredits[_tokenId].price = 0;
            
            // Transfer NFT
            _transfer(seller, msg.sender, _tokenId);
            
            // Transfer payment to seller
            payable(seller).transfer(salePrice);
            
            emit CarbonCreditSold(_tokenId, msg.sender, salePrice);
        }
    }
    
    // View functions
    function getCarbonCredit(uint256 _tokenId) external view returns (CarbonCredit memory) {
        require(_ownerOf(_tokenId) != address(0), "Carbon credit does not exist");
        return carbonCredits[_tokenId];
    }
    
    function getIoTDevice(string memory _deviceId) external view returns (IoTDevice memory) {
        return iotDevices[_deviceId];
    }
    
    function isProducerVerified(address _producer) external view returns (bool) {
        return verifiedProducers[_producer];
    }
    
    function getTotalSupply() external view returns (uint256) {
        return _tokenIdCounter;
    }
    
    // Admin functions
    function deactivateDevice(string memory _deviceId) external onlyOwner {
        iotDevices[_deviceId].isActive = false;
    }
    
    function verifyProducer(address _producer) external onlyOwner {
        verifiedProducers[_producer] = true;
    }
}
