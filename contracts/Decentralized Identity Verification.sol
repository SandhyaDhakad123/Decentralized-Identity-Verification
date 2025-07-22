// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Decentralized Identity Verification System
 * @dev A blockchain-based identity verification system with reputation scoring
 * @author Identity Solutions Developer
 */

contract Project {
    
    struct Identity {
        address owner;
        string name;
        string email;
        bytes32 documentHash;
        uint256 creationTime;
        uint256 reputationScore;
        bool isVerified;
        bool isActive;
        uint256 endorsementCount;
    }
    
    struct Endorsement {
        address endorser;
        address endorsed;
        string endorsementType;
        string message;
        uint256 timestamp;
        uint256 weight;
        bool isActive;
    }
    
    struct Credential {
        uint256 identityId;
        string credentialType;
        string issuer;
        bytes32 credentialHash;
        uint256 issueDate;
        uint256 expiryDate;
        bool isVerified;
        bool isActive;
    }
    
    address public owner;
    uint256 public totalIdentities;
    uint256 public totalEndorsements;
    uint256 public totalCredentials;
    uint256 public constant MIN_REPUTATION_FOR_ENDORSEMENT = 50;
    uint256 public constant MAX_REPUTATION_SCORE = 1000;
    
    mapping(uint256 => Identity) public identities;
    mapping(address => uint256) public addressToIdentityId;
    mapping(uint256 => Endorsement) public endorsements;
    mapping(uint256 => Credential) public credentials;
    mapping(address => bool) public trustedVerifiers;
    mapping(uint256 => uint256[]) public identityEndorsements;
    mapping(uint256 => uint256[]) public identityCredentials;
    
    event IdentityCreated(uint256 indexed identityId, address indexed owner, string name);
    event IdentityVerified(uint256 indexed identityId, address indexed verifier);
    event EndorsementGiven(uint256 indexed endorsementId, address indexed endorser, address indexed endorsed);
    event CredentialAdded(uint256 indexed credentialId, uint256 indexed identityId, string credentialType);
    event ReputationUpdated(uint256 indexed identityId, uint256 newScore);
    event TrustedVerifierAdded(address indexed verifier);
    event IdentityOwnershipTransferred(uint256 indexed identityId, address indexed oldOwner, address indexed newOwner);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this action");
        _;
    }
    
    modifier onlyTrustedVerifier() {
        require(trustedVerifiers[msg.sender] || msg.sender == owner, "Only trusted verifiers can perform this action");
        _;
    }
    
    modifier identityExists(uint256 _identityId) {
        require(_identityId < totalIdentities, "Identity does not exist");
        require(identities[_identityId].isActive, "Identity is not active");
        _;
    }
    
    modifier onlyIdentityOwner(uint256 _identityId) {
        require(identities[_identityId].owner == msg.sender, "Only identity owner can perform this action");
        _;
    }

    constructor() {
        owner = msg.sender;
        trustedVerifiers[msg.sender] = true;
        totalIdentities = 0;
        totalEndorsements = 0;
        totalCredentials = 0;
    }

    function createIdentity(
        string memory _name,
        string memory _email,
        bytes32 _documentHash
    ) external {
        require(bytes(_name).length > 0, "Name cannot be empty");
        require(bytes(_email).length > 0, "Email cannot be empty");
        require(_documentHash != bytes32(0), "Document hash cannot be empty");
        require(addressToIdentityId[msg.sender] == 0, "Identity already exists for this address");

        identities[totalIdentities] = Identity({
            owner: msg.sender,
            name: _name,
            email: _email,
            documentHash: _documentHash,
            creationTime: block.timestamp,
            reputationScore: 100,
            isVerified: false,
            isActive: true,
            endorsementCount: 0
        });

        addressToIdentityId[msg.sender] = totalIdentities + 1;

        emit IdentityCreated(totalIdentities, msg.sender, _name);
        totalIdentities++;
    }

    function giveEndorsement(
        address _endorsedAddress,
        string memory _endorsementType,
        string memory _message
    ) external {
        require(_endorsedAddress != address(0), "Invalid endorsed address");
        require(_endorsedAddress != msg.sender, "Cannot endorse yourself");
        require(bytes(_endorsementType).length > 0, "Endorsement type cannot be empty");
        require(bytes(_message).length > 0, "Message cannot be empty");

        uint256 endorserIdentityId = addressToIdentityId[msg.sender];
        uint256 endorsedIdentityId = addressToIdentityId[_endorsedAddress];

        require(endorserIdentityId > 0, "Endorser must have an identity");
        require(endorsedIdentityId > 0, "Endorsed user must have an identity");

        endorserIdentityId--;
        endorsedIdentityId--;

        Identity storage endorserIdentity = identities[endorserIdentityId];
        Identity storage endorsedIdentity = identities[endorsedIdentityId];

        require(endorserIdentity.isActive, "Endorser identity is not active");
        require(endorsedIdentity.isActive, "Endorsed identity is not active");
        require(
            endorserIdentity.reputationScore >= MIN_REPUTATION_FOR_ENDORSEMENT,
            "Insufficient reputation to give endorsements"
        );

        uint256 weight = endorserIdentity.reputationScore / 10;

        endorsements[totalEndorsements] = Endorsement({
            endorser: msg.sender,
            endorsed: _endorsedAddress,
            endorsementType: _endorsementType,
            message: _message,
            timestamp: block.timestamp,
            weight: weight,
            isActive: true
        });

        endorsedIdentity.endorsementCount++;
        identityEndorsements[endorsedIdentityId].push(totalEndorsements);

        _updateReputation(endorsedIdentityId, weight);

        emit EndorsementGiven(totalEndorsements, msg.sender, _endorsedAddress);
        totalEndorsements++;
    }

    function addCredential(
        uint256 _identityId,
        string memory _credentialType,
        string memory _issuer,
        bytes32 _credentialHash,
        uint256 _expiryDate
    ) external onlyTrustedVerifier identityExists(_identityId) {
        require(bytes(_credentialType).length > 0, "Credential type cannot be empty");
        require(bytes(_issuer).length > 0, "Issuer cannot be empty");
        require(_credentialHash != bytes32(0), "Credential hash cannot be empty");
        require(_expiryDate == 0 || _expiryDate > block.timestamp, "Invalid expiry date");

        credentials[totalCredentials] = Credential({
            identityId: _identityId,
            credentialType: _credentialType,
            issuer: _issuer,
            credentialHash: _credentialHash,
            issueDate: block.timestamp,
            expiryDate: _expiryDate,
            isVerified: true,
            isActive: true
        });

        identityCredentials[_identityId].push(totalCredentials);
        _updateReputation(_identityId, 20);

        emit CredentialAdded(totalCredentials, _identityId, _credentialType);
        totalCredentials++;
    }

    function verifyIdentity(uint256 _identityId) external onlyTrustedVerifier identityExists(_identityId) {
        Identity storage identity = identities[_identityId];
        require(!identity.isVerified, "Identity is already verified");

        identity.isVerified = true;
        _updateReputation(_identityId, 50);

        emit IdentityVerified(_identityId, msg.sender);
    }

    function addTrustedVerifier(address _verifier) external onlyOwner {
        require(_verifier != address(0), "Invalid verifier address");
        require(!trustedVerifiers[_verifier], "Verifier already trusted");

        trustedVerifiers[_verifier] = true;
        emit TrustedVerifierAdded(_verifier);
    }

    function removeTrustedVerifier(address _verifier) external onlyOwner {
        require(_verifier != owner, "Cannot remove owner as verifier");
        trustedVerifiers[_verifier] = false;
    }

    function _updateReputation(uint256 _identityId, uint256 _points) internal {
        Identity storage identity = identities[_identityId];

        if (identity.reputationScore + _points <= MAX_REPUTATION_SCORE) {
            identity.reputationScore += _points;
        } else {
            identity.reputationScore = MAX_REPUTATION_SCORE;
        }

        emit ReputationUpdated(_identityId, identity.reputationScore);
    }

    function getIdentity(uint256 _identityId) 
        external 
        view 
        identityExists(_identityId)
        returns (
            address owner,
            string memory name,
            uint256 reputationScore,
            bool isVerified,
            uint256 endorsementCount
        ) 
    {
        Identity storage identity = identities[_identityId];
        return (
            identity.owner,
            identity.name,
            identity.reputationScore,
            identity.isVerified,
            identity.endorsementCount
        );
    }

    function getIdentityEndorsements(uint256 _identityId) 
        external 
        view 
        identityExists(_identityId)
        returns (uint256[] memory) 
    {
        return identityEndorsements[_identityId];
    }

    function getIdentityCredentials(uint256 _identityId) 
        external 
        view 
        identityExists(_identityId)
        returns (uint256[] memory) 
    {
        return identityCredentials[_identityId];
    }

    function getEndorsement(uint256 _endorsementId) 
        external 
        view 
        returns (
            address endorser,
            address endorsed,
            string memory endorsementType,
            string memory message,
            uint256 weight
        ) 
    {
        require(_endorsementId < totalEndorsements, "Endorsement does not exist");
        Endorsement storage endorsement = endorsements[_endorsementId];

        return (
            endorsement.endorser,
            endorsement.endorsed,
            endorsement.endorsementType,
            endorsement.message,
            endorsement.weight
        );
    }

    function getCredential(uint256 _credentialId) 
        external 
        view 
        returns (
            uint256 identityId,
            string memory credentialType,
            string memory issuer,
            uint256 issueDate,
            uint256 expiryDate,
            bool isVerified
        ) 
    {
        require(_credentialId < totalCredentials, "Credential does not exist");
        Credential storage credential = credentials[_credentialId];

        return (
            credential.identityId,
            credential.credentialType,
            credential.issuer,
            credential.issueDate,
            credential.expiryDate,
            credential.isVerified
        );
    }

    function checkIdentityStatus(address _address) 
        external 
        view 
        returns (bool hasIdentity, bool isVerified, uint256 reputationScore) 
    {
        uint256 identityId = addressToIdentityId[_address];

        if (identityId == 0) {
            return (false, false, 0);
        }

        identityId--;
        Identity storage identity = identities[identityId];

        return (
            identity.isActive,
            identity.isVerified,
            identity.reputationScore
        );
    }

    function deactivateIdentity(uint256 _identityId) external identityExists(_identityId) {
        require(
            msg.sender == owner || msg.sender == identities[_identityId].owner,
            "Only owner or identity holder can deactivate"
        );

        identities[_identityId].isActive = false;
    }

    /**
     * @dev Transfer ownership of an identity to a new address
     * @param _identityId ID of the identity
     * @param _newOwner Address of the new owner
     */
    function transferIdentityOwnership(uint256 _identityId, address _newOwner)
        external
        onlyIdentityOwner(_identityId)
        identityExists(_identityId)
    {
        require(_newOwner != address(0), "New owner cannot be zero address");
        require(addressToIdentityId[_newOwner] == 0, "New owner already has an identity");

        addressToIdentityId[_newOwner] = addressToIdentityId[msg.sender];
        addressToIdentityId[msg.sender] = 0;

        identities[_identityId].owner = _newOwner;

        emit IdentityOwnershipTransferred(_identityId, msg.sender, _newOwner);
    }
}
