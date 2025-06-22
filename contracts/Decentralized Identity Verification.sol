// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Decentralized Identity Verification System
 * @dev A blockchain-based identity verification system with reputation scoring
 * @author Identity Solutions Developer
 */

contract Project {
    
    // Structure to represent a digital identity
    struct Identity {
        address owner;
        string name;
        string email;
        bytes32 documentHash; // Hash of identity documents
        uint256 creationTime;
        uint256 reputationScore;
        bool isVerified;
        bool isActive;
        uint256 endorsementCount;
    }
    
    // Structure to represent an endorsement
    struct Endorsement {
        address endorser;
        address endorsed;
        string endorsementType; // "professional", "personal", "academic", etc.
        string message;
        uint256 timestamp;
        uint256 weight; // Weight based on endorser's reputation
        bool isActive;
    }
    
    // Structure to represent a credential
    struct Credential {
        uint256 identityId;
        string credentialType; // "education", "certification", "license", etc.
        string issuer;
        bytes32 credentialHash;
        uint256 issueDate;
        uint256 expiryDate;
        bool isVerified;
        bool isActive;
    }
    
    // State variables
    address public owner;
    uint256 public totalIdentities;
    uint256 public totalEndorsements;
    uint256 public totalCredentials;
    uint256 public constant MIN_REPUTATION_FOR_ENDORSEMENT = 50;
    uint256 public constant MAX_REPUTATION_SCORE = 1000;
    
    // Mappings
    mapping(uint256 => Identity) public identities;
    mapping(address => uint256) public addressToIdentityId;
    mapping(uint256 => Endorsement) public endorsements;
    mapping(uint256 => Credential) public credentials;
    mapping(address => bool) public trustedVerifiers;
    mapping(uint256 => uint256[]) public identityEndorsements;
    mapping(uint256 => uint256[]) public identityCredentials;
    
    // Events
    event IdentityCreated(uint256 indexed identityId, address indexed owner, string name);
    event IdentityVerified(uint256 indexed identityId, address indexed verifier);
    event EndorsementGiven(uint256 indexed endorsementId, address indexed endorser, address indexed endorsed);
    event CredentialAdded(uint256 indexed credentialId, uint256 indexed identityId, string credentialType);
    event ReputationUpdated(uint256 indexed identityId, uint256 newScore);
    event TrustedVerifierAdded(address indexed verifier);
    
    // Modifiers
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
    
    // Constructor
    constructor() {
        owner = msg.sender;
        trustedVerifiers[msg.sender] = true;
        totalIdentities = 0;
        totalEndorsements = 0;
        totalCredentials = 0;
    }
    
    /**
     * @dev Core Function 1: Create a new digital identity
     * @param _name Full name of the identity holder
     * @param _email Email address of the identity holder
     * @param _documentHash Hash of identity verification documents
     */
    function createIdentity(
        string memory _name,
        string memory _email,
        bytes32 _documentHash
    ) external {
        require(bytes(_name).length > 0, "Name cannot be empty");
        require(bytes(_email).length > 0, "Email cannot be empty");
        require(_documentHash != bytes32(0), "Document hash cannot be empty");
        require(addressToIdentityId[msg.sender] == 0, "Identity already exists for this address");
        
        // Create new identity
        identities[totalIdentities] = Identity({
            owner: msg.sender,
            name: _name,
            email: _email,
            documentHash: _documentHash,
            creationTime: block.timestamp,
            reputationScore: 100, // Starting reputation score
            isVerified: false,
            isActive: true,
            endorsementCount: 0
        });
        
        // Map address to identity ID (add 1 to avoid 0 default value)
        addressToIdentityId[msg.sender] = totalIdentities + 1;
        
        emit IdentityCreated(totalIdentities, msg.sender, _name);
        totalIdentities++;
    }
    
    /**
     * @dev Core Function 2: Give endorsement to another identity
     * @param _endorsedAddress Address of the identity to endorse
     * @param _endorsementType Type of endorsement (professional, personal, etc.)
     * @param _message Endorsement message
     */
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
        
        // Adjust for 0-based indexing
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
        
        // Calculate endorsement weight based on endorser's reputation
        uint256 weight = endorserIdentity.reputationScore / 10;
        
        // Create endorsement
        endorsements[totalEndorsements] = Endorsement({
            endorser: msg.sender,
            endorsed: _endorsedAddress,
            endorsementType: _endorsementType,
            message: _message,
            timestamp: block.timestamp,
            weight: weight,
            isActive: true
        });
        
        // Update endorsed identity's reputation and endorsement count
        endorsedIdentity.endorsementCount++;
        identityEndorsements[endorsedIdentityId].push(totalEndorsements);
        
        // Update reputation score
        _updateReputation(endorsedIdentityId, weight);
        
        emit EndorsementGiven(totalEndorsements, msg.sender, _endorsedAddress);
        totalEndorsements++;
    }
    
    /**
     * @dev Core Function 3: Add a credential to an identity
     * @param _identityId ID of the identity to add credential to
     * @param _credentialType Type of credential
     * @param _issuer Issuer of the credential
     * @param _credentialHash Hash of the credential document
     * @param _expiryDate Expiry date of the credential (0 for no expiry)
     */
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
        
        // Create credential
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
        
        // Link credential to identity
        identityCredentials[_identityId].push(totalCredentials);
        
        // Boost reputation for verified credentials
        _updateReputation(_identityId, 20);
        
        emit CredentialAdded(totalCredentials, _identityId, _credentialType);
        totalCredentials++;
    }
    
    /**
     * @dev Verify an identity (Trusted verifiers only)
     * @param _identityId ID of the identity to verify
     */
    function verifyIdentity(uint256 _identityId) external onlyTrustedVerifier identityExists(_identityId) {
        Identity storage identity = identities[_identityId];
        require(!identity.isVerified, "Identity is already verified");
        
        identity.isVerified = true;
        
        // Boost reputation for verified identity
        _updateReputation(_identityId, 50);
        
        emit IdentityVerified(_identityId, msg.sender);
    }
    
    /**
     * @dev Add a trusted verifier (Owner only)
     * @param _verifier Address of the verifier to add
     */
    function addTrustedVerifier(address _verifier) external onlyOwner {
        require(_verifier != address(0), "Invalid verifier address");
        require(!trustedVerifiers[_verifier], "Verifier already trusted");
        
        trustedVerifiers[_verifier] = true;
        emit TrustedVerifierAdded(_verifier);
    }
    
    /**
     * @dev Remove a trusted verifier (Owner only)
     * @param _verifier Address of the verifier to remove
     */
    function removeTrustedVerifier(address _verifier) external onlyOwner {
        require(_verifier != owner, "Cannot remove owner as verifier");
        trustedVerifiers[_verifier] = false;
    }
    
    /**
     * @dev Update reputation score internally
     * @param _identityId ID of the identity
     * @param _points Points to add to reputation
     */
    function _updateReputation(uint256 _identityId, uint256 _points) internal {
        Identity storage identity = identities[_identityId];
        
        if (identity.reputationScore + _points <= MAX_REPUTATION_SCORE) {
            identity.reputationScore += _points;
        } else {
            identity.reputationScore = MAX_REPUTATION_SCORE;
        }
        
        emit ReputationUpdated(_identityId, identity.reputationScore);
    }
    
    /**
     * @dev Get identity information
     * @param _identityId ID of the identity
     * @return owner Address of the identity owner
     * @return name Name of the identity holder
     * @return reputationScore Current reputation score
     * @return isVerified Verification status
     * @return endorsementCount Number of endorsements received
     */
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
    
    /**
     * @dev Get endorsements for an identity
     * @param _identityId ID of the identity
     * @return Array of endorsement IDs
     */
    function getIdentityEndorsements(uint256 _identityId) 
        external 
        view 
        identityExists(_identityId)
        returns (uint256[] memory) 
    {
        return identityEndorsements[_identityId];
    }
    
    /**
     * @dev Get credentials for an identity
     * @param _identityId ID of the identity
     * @return Array of credential IDs
     */
    function getIdentityCredentials(uint256 _identityId) 
        external 
        view 
        identityExists(_identityId)
        returns (uint256[] memory) 
    {
        return identityCredentials[_identityId];
    }
    
    /**
     * @dev Get endorsement details
     * @param _endorsementId ID of the endorsement
     * @return endorser Address of the endorser
     * @return endorsed Address of the endorsed
     * @return endorsementType Type of endorsement
     * @return message Endorsement message
     * @return weight Weight of the endorsement
     */
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
    
    /**
     * @dev Get credential details
     * @param _credentialId ID of the credential
     * @return identityId ID of the identity holder
     * @return credentialType Type of credential
     * @return issuer Issuer of the credential
     * @return issueDate Issue date
     * @return expiryDate Expiry date
     * @return isVerified Verification status
     */
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
    
    /**
     * @dev Check if an address has a verified identity
     * @param _address Address to check
     * @return hasIdentity Whether the address has an identity
     * @return isVerified Whether the identity is verified
     * @return reputationScore Reputation score of the identity
     */
    function checkIdentityStatus(address _address) 
        external 
        view 
        returns (bool hasIdentity, bool isVerified, uint256 reputationScore) 
    {
        uint256 identityId = addressToIdentityId[_address];
        
        if (identityId == 0) {
            return (false, false, 0);
        }
        
        identityId--; // Adjust for 0-based indexing
        Identity storage identity = identities[identityId];
        
        return (
            identity.isActive,
            identity.isVerified,
            identity.reputationScore
        );
    }
    
    /**
     * @dev Deactivate an identity (Owner or identity holder only)
     * @param _identityId ID of the identity to deactivate
     */
    function deactivateIdentity(uint256 _identityId) external identityExists(_identityId) {
        require(
            msg.sender == owner || msg.sender == identities[_identityId].owner,
            "Only owner or identity holder can deactivate"
        );
        
        identities[_identityId].isActive = false;
    }
}
