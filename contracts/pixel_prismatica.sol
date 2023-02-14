// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.18;

// import "@openzeppelin/contracts/utils/Base64.sol"
library Base64 {
    string internal constant _TABLE = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    function encode(bytes memory data) internal pure returns (string memory) {
        if(data.length == 0) return "";
        string memory table = _TABLE;
        string memory result = new string(4 * ((data.length + 2) / 3));
        assembly {
            let tablePtr := add(table, 1)
            let resultPtr := add(result, 32)
            for {
                let dataPtr := data
                let endPtr := add(data, mload(data))
            } lt(dataPtr, endPtr) {
            } {
                // Advance 3 bytes
                dataPtr := add(dataPtr, 3)
                let input := mload(dataPtr)
                mstore8(resultPtr, mload(add(tablePtr, and(shr(18, input), 0x3F))))
                resultPtr := add(resultPtr, 1) // Advance
                mstore8(resultPtr, mload(add(tablePtr, and(shr(12, input), 0x3F))))
                resultPtr := add(resultPtr, 1) // Advance
                mstore8(resultPtr, mload(add(tablePtr, and(shr(6, input), 0x3F))))
                resultPtr := add(resultPtr, 1) // Advance
                mstore8(resultPtr, mload(add(tablePtr, and(input, 0x3F))))
                resultPtr := add(resultPtr, 1) // Advance
            }
            switch mod(mload(data), 3)
            case 1 {
                mstore8(sub(resultPtr, 1), 0x3d)
                mstore8(sub(resultPtr, 2), 0x3d)
            }
            case 2 {
                mstore8(sub(resultPtr, 1), 0x3d)
            }
        }
        return result;
    }
}

// import "@openzeppelin/contracts/token/ERC20/IERC20.sol"
interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

// import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
interface IERC165 {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

// import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
interface IERC721 is IERC165 {
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
    function balanceOf(address owner) external view returns (uint256 balance);
    function ownerOf(uint256 tokenId) external view returns (address owner);
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function transferFrom(address from, address to, uint256 tokenId) external;
    function approve(address to, uint256 tokenId) external;
    function setApprovalForAll(address operator, bool approved) external;
    function getApproved(uint256 tokenId) external view returns (address operator);
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}

// import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
interface IERC721Receiver {
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) external returns (bytes4);
}

// import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
interface IERC1155 is IERC165 {
    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);
    event TransferBatch(address indexed operator, address indexed from, address indexed to, uint256[] ids, uint256[] values);
    event ApprovalForAll(address indexed account, address indexed operator, bool approved);
    event URI(string value, uint256 indexed id);
    function balanceOf(address account, uint256 id) external view returns (uint256);
    function balanceOfBatch(address[] calldata accounts, uint256[] calldata ids) external view returns (uint256[] memory);
    function setApprovalForAll(address operator, bool approved) external;
    function isApprovedForAll(address account, address operator) external view returns (bool);
    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes calldata data) external;
    function safeBatchTransferFrom(address from, address to, uint256[] calldata ids, uint256[] calldata amounts, bytes calldata data) external;
}

// import "@openzeppelin/contracts/token/ERC1155/extensions/IERC1155MetadataURI.sol";
interface IERC1155MetadataURI is IERC1155 {
    function uri(uint256 id) external view returns (string memory);
}

// import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
interface IERC1155Receiver is IERC165 {
    function onERC1155Received(address operator, address from, uint256 id, uint256 value, bytes calldata data) external returns (bytes4);
    function onERC1155BatchReceived(address operator, address from, uint256[] calldata ids, uint256[] calldata values, bytes calldata data) external returns (bytes4);
}

// import "@openzeppelin/contracts/interfaces/IERC2981.sol";
interface IERC2981 is IERC165 {
    function royaltyInfo(uint256 tokenId, uint256 salePrice) external view returns (address receiver, uint256 royaltyAmount);
}

contract PixelPrismatica is IERC721Receiver, IERC1155MetadataURI, IERC1155Receiver, IERC2981 {
    /*
    *
    *
        Errors
    *
    *
    */

    /// @notice The coin withdraw is not allowed.
    error CoinWithdrawError(uint256 requestedValue, uint256 coinBalance);

    /// @notice The ERC20 token contract could not be found.
    error ERC20TokenContractError(address tokenAddress);

    /// @notice The ERC20 token transfer failed.
    error ERC20TokenTransferError(address tokenAddress, address _address, uint256 requestedValue);

    /// @notice The ERC20 token withdraw is not allowed.
    error ERC20TokenWithdrawError(address tokenAddress, uint256 requestedValue, uint256 tokenBalance);

    /// @notice The ERC721 token contract could not be found.
    error ERC721TokenContractError(address tokenAddress, uint256 id);

    /// @notice The ERC721 token transfer failed.
    error ERC721TokenTransferError(address tokenAddress, uint256 id, address _address);

    /// @notice The ERC721 token withdraw is not allowed.
    error ERC721TokenWithdrawError(address tokenAddress, uint256 id, uint256 requestedValue, uint256 tokenBalance);

    /// @notice The ERC1155 token contract could not be found.
    error ERC1155TokenContractError(address tokenAddress, uint256 id);

    /// @notice The ERC1155 token transfer failed.
    error ERC1155TokenTransferError(address tokenAddress, uint256 id, address _address, uint256 requestedValue);

    /// @notice The ERC1155 token withdraw is not allowed.
    error ERC1155TokenWithdrawError(address tokenAddress, uint256 id, uint256 requestedValue, uint256 tokenBalance);

    /// @notice The required minting fee has not been paid.
    error MintFeeError(uint256 value, uint256 mintFee);

    /// @notice There are no remaining NFT mints available.
    error NoRemainingMintsError();

    /// @notice The calling address is not the operator.
    error NotOperatorError(address _address, address operatorAddress);

    /// @notice The calling address is not the operator successor.
    error NotOperatorSuccessorError(address _address, address operatorSuccessorAddress);

    /// @notice The calling address is not the owner.
    error NotOwnerError(address _address, address ownerAddress);

    /// @notice The calling address is not the owner successor.
    error NotOwnerSuccessorError(address _address, address ownerSuccessorAddress);

    /// @notice This contract is paused.
    error PausedContractError();

    /*
    *
    *
        Events
    *
    *
    */

    /// @notice A record of an NFT being minted.
    event Mint(uint256 indexed id, address indexed mintAddress);

    /// @notice A record of the operator address changing.
    event OperatorChanged(address indexed oldOperatorAddress, address indexed newOperatorAddress);

    /// @notice A record of the owner address changing.
    event OwnerChanged(address indexed oldOwnerAddress, address indexed newOwnerAddress);

    /*
    *
    *
        Constants
    *
    *
    */

    // The identifier of the chain that this contract is meant to be deployed on.
    uint256 private constant CHAIN_ID = 56; 

    // The max number of NFT mints available.
    uint256 private constant MAX_MINTS = 100;

    /*
    *
    *
        Private Variables
    *
    *
    */

    /*
        Contract Variables
    */

    address private operatorAddress;
    address private operatorSuccessorAddress;
    address private ownerAddress;
    address private ownerSuccessorAddress;

    bool private lockFlag;
    bool private pauseFlag;

    /*
        NFT Variables
    */
    uint256 private currentID;

    uint256 private mintFee;
    address private royaltyAddress;
    uint256 private royaltyBasisPoints;
    
    string private storeDescription;
    string private storeExternalLinkURI;
    string private storeImageURI;
    string private storeName;

    //mapping(uint256 => uint256) private map_id2Config???;
    mapping(address => mapping(address => bool)) private map_address2OperatorAddress2IsApproved;
    mapping(uint256 => mapping(address => uint256)) private map_id2address2balance;

    /*
    *
    *
        Contract Functions
    *
    *
    */

    /*
        Built-In Functions
    */

    constructor() payable {
        assert(block.chainid == CHAIN_ID);

        setOwnerAddress(msg.sender);
        setOwnerSuccessorAddress(msg.sender);
        setOperatorAddress(msg.sender);
        setOperatorSuccessorAddress(msg.sender);

        // The contract starts paused to allow NFT information to be set.
        setPause(true);

        // Set the initial mint fee. This will increase automatically as more NFTs are minted.
        setMintFee(0.1 ether);

        // The royalty is fixed at 3%
        setRoyaltyBasisPoints(300);

        // Defaults are set here, but these can be changed manually after the contract is deployed.
        setRoyaltyAddress(address(this));
        setStoreName("Pixel Prismatica NFT Collection");
        setStoreDescription("A collection of configurable NFT tokens featuring colorful pixel art.");
        setStoreImageURI("I");
        setStoreExternalLinkURI("Z");
    }

    fallback() external payable {
        // There is no legitimate reason for this fallback function to be called.
        punish();
    }

    receive() external payable {}

    /*
        Implementation Functions
    */

    // IERC165 Implementation
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165).interfaceId
            || interfaceId == type(IERC721Receiver).interfaceId
            || interfaceId == type(IERC1155).interfaceId
            || interfaceId == type(IERC1155MetadataURI).interfaceId 
            || interfaceId == type(IERC1155Receiver).interfaceId 
            || interfaceId == type(IERC2981).interfaceId;
    }

    // IERC721Receiver Implementation
    function onERC721Received(address, address, uint256, bytes memory) public virtual returns (bytes4) {
        return this.onERC721Received.selector;
    }

    // IERC1155 Implementation
    function balanceOf(address account, uint256 id) public view virtual override returns (uint256) {
        require(account != address(0), "ERC1155: address zero is not a valid owner");
        return map_id2address2balance[id][account];
    }

    function balanceOfBatch(address[] memory accounts, uint256[] memory ids) public view virtual override returns (uint256[] memory) {
        require(accounts.length == ids.length, "ERC1155: accounts and ids length mismatch");

        uint256[] memory batchBalances = new uint256[](accounts.length);

        for(uint256 i = 0; i < accounts.length; ++i) {
            batchBalances[i] = balanceOf(accounts[i], ids[i]);
        }

        return batchBalances;
    }

    function setApprovalForAll(address operator, bool approved) public virtual override {
        require(msg.sender != operator, "ERC1155: setting approval status for self");

        map_address2OperatorAddress2IsApproved[msg.sender][operator] = approved;

        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function isApprovedForAll(address account, address operator) public view virtual override returns (bool) {
        return map_address2OperatorAddress2IsApproved[account][operator];
    }

    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes memory data) public virtual override {
        requireNotPaused();
        require(to != address(0), "ERC1155: transfer to the zero address");
        require(from == msg.sender || isApprovedForAll(from, msg.sender), "ERC1155: caller is not token owner or approved");

        uint256 fromBalance = map_id2address2balance[id][from];
        require(fromBalance >= amount, "ERC1155: insufficient balance for transfer");

        map_id2address2balance[id][from] = fromBalance - amount;
        map_id2address2balance[id][to] += amount;

        emit TransferSingle(msg.sender, from, to, id, amount);

        _doSafeTransferAcceptanceCheck(msg.sender, from, to, id, amount, data);
    }

    function safeBatchTransferFrom(address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) public virtual override {
        requireNotPaused();
        require(to != address(0), "ERC1155: transfer to the zero address");
        require(from == msg.sender || isApprovedForAll(from, msg.sender), "ERC1155: caller is not token owner or approved");
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");

        for(uint256 i = 0; i < ids.length; ++i) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];

            uint256 fromBalance = map_id2address2balance[id][from];
            require(fromBalance >= amount, "ERC1155: insufficient balance for transfer");

            map_id2address2balance[id][from] = fromBalance - amount;
            map_id2address2balance[id][to] += amount;
        }

        emit TransferBatch(msg.sender, from, to, ids, amounts);

        _doSafeBatchTransferAcceptanceCheck(msg.sender, from, to, ids, amounts, data);
    }

    function _doSafeTransferAcceptanceCheck(address operator, address from, address to, uint256 id, uint256 amount, bytes memory data) private {
        if(to.code.length > 0) {
            try IERC1155Receiver(to).onERC1155Received(operator, from, id, amount, data) returns (bytes4 response) {
                if(response != IERC1155Receiver.onERC1155Received.selector) {
                    revert("ERC1155: ERC1155Receiver rejected tokens");
                }
            }
            catch Error(string memory reason) {
                revert(reason);
            }
            catch {
                revert("ERC1155: transfer to non-ERC1155Receiver implementer");
            }
        }
    }

    function _doSafeBatchTransferAcceptanceCheck(address operator, address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) private {
        if(to.code.length > 0) {
            try IERC1155Receiver(to).onERC1155BatchReceived(operator, from, ids, amounts, data) returns (bytes4 response) {
                if(response != IERC1155Receiver.onERC1155BatchReceived.selector) {
                    revert("ERC1155: ERC1155Receiver rejected tokens");
                }
            }
            catch Error(string memory reason) {
                revert(reason);
            }
            catch {
                revert("ERC1155: transfer to non-ERC1155Receiver implementer");
            }
        }
    }

    // IERC1155MetadataURI Implementation
    function uri(uint256 id) external view returns (string memory) {
        // The JSON data is directly encoded here.
        string memory name = string.concat("Pixel Prismatica NFT #", uint256ToString(id));
        string memory description = createDescription();
        string memory imageURI = createImageURI();

        string memory uriString = string.concat('{"name":"', name, '", "description":"', description, '", "image":"', imageURI, '"}');
        return string(abi.encodePacked('data:application/json;base64,', Base64.encode(abi.encodePacked(uriString))));
    }

    // IERC1155Receiver Implementation
    function onERC1155Received(address, address, uint256, uint256, bytes memory) external pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint256[] memory, uint256[] memory, bytes memory) external pure returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

    // IERC2981 Implementation
    function royaltyInfo(uint256, uint256 salePrice) external view returns (address receiver, uint256 royaltyAmount) {
        receiver = royaltyAddress;
        royaltyAmount = (salePrice * royaltyBasisPoints) / 10000;
    }

    // OpenSea Standard
    function contractURI() public view returns (string memory) {
        // The JSON data is directly encoded here.
        string memory uriString = string.concat('{"name":"', storeName, '", "description":"', storeDescription, '", "image":"', storeImageURI, '", "external_link":"', storeExternalLinkURI, '", "seller_fee_basis_points":', uint256ToString(royaltyBasisPoints), ', "fee_recipient":"', addressToString(royaltyAddress), '"}');
        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(abi.encodePacked(uriString))));
    }

    /*
        Action Functions
    */

    function claimOperatorRole(address _address) private {
        setOperatorAddress(_address);
    }

    function claimOwnerRole(address _address) private {
        setOwnerAddress(_address);
    }

    function mint(address _address, bytes memory _data) private {
        // This NFT is always minted one at a time.
        requireNotPaused();
        require(_address != address(0), "ERC1155: mint to the zero address");

        currentID++;

        //setIDConfig ????
        map_id2address2balance[currentID][_address] = 1;

        // Every time an NFT is minted, increase the minting cost for the next one.
        setMintFee((getMintFee() * 105) / 100);
        
        emit Mint(currentID, _address);
        emit TransferSingle(msg.sender, address(0), _address, currentID, 1);

        _doSafeTransferAcceptanceCheck(msg.sender, address(0), _address, currentID, 1, _data);
    }

    function offerOperatorRole(address _address) private {
        setOperatorSuccessorAddress(_address);
    }

    function offerOwnerRole(address _address) private {
        setOwnerSuccessorAddress(_address);
    }

    /*
        Helper Functions
    */

    function createDescription() private view returns (string memory) {
        return "D";
    }

    function createImageURI() private view returns (string memory) {
        return "I";
    }

    /*
        Withdraw Functions
    */

    function withdrawCoins(address _address, uint256 _value) private {
        transferCoinToAddress(_address, _value);
    }

    function withdrawERC20Tokens(address _tokenAddress, address _address, uint256 _value) private {
        transferERC20TokenToAddress(_tokenAddress, _address, _value);
    }

    function withdrawERC721Tokens(address _tokenAddress, uint256 _id, address _address) private {
        transferERC721TokenToAddress(_tokenAddress, _id, _address);
    }

    function withdrawERC1155Tokens(address _tokenAddress, uint256 _id, address _address, uint256 _value, bytes memory _data) private {
        transferERC1155TokenToAddress(_tokenAddress, _id, _address, _value, _data);
    }

    /*
        Query Functions
    */

    function isCoinWithdrawAllowed(uint256 _value) private view returns (bool) {
        return _value <= getCoinBalance();
    }

    function isERC20TokenWithdrawAllowed(address _tokenAddress, uint256 _value) private view returns (bool) {
        // Note that we forbid withdrawing an amount higher than the available balance.
        // Even if the token's contract would allow for such a strange withdraw, we do not permit it here.
        return _value <= getERC20TokenBalance(_tokenAddress);
    }

    function isERC721TokenWithdrawAllowed(address _tokenAddress, uint256 _id) private view returns (bool) {
        // Each ID is a unique NFT, so the balance is either 0 or 1.
        return 1 == getERC721TokenBalance(_tokenAddress, _id);
    }

    function isERC1155TokenWithdrawAllowed(address _tokenAddress, uint256 _id, uint256 _value) private view returns (bool) {
        // Note that we forbid withdrawing an amount higher than the available balance.
        // Even if the token's contract would allow for such a strange withdraw, we do not permit it here.
        return _value <= getERC1155TokenBalance(_tokenAddress, _id);
    }

    function isLocked() private view returns (bool) {
        return lockFlag;
    }

    function isMintFee(uint256 _value) private view returns (bool) {
        return _value == getMintFee();
    }

    function isOperatorAddress(address _address) private view returns (bool) {
        return _address == getOperatorAddress();
    }

    function isOperatorSuccessorAddress(address _address) private view returns (bool) {
        return _address == getOperatorSuccessorAddress();
    }

    function isOwnerAddress(address _address) private view returns (bool) {
        return _address == getOwnerAddress();
    }

    function isOwnerSuccessorAddress(address _address) private view returns (bool) {
        return _address == getOwnerSuccessorAddress();
    }

    function isPaused() private view returns (bool) {
        return pauseFlag;
    }

    function isRemainingMints() private view returns (bool) {
        return getRemainingMints() != 0;
    }

    /*
        Require Functions
    */

    function requireCoinWithdrawAllowed(uint256 _value) private view {
        if(!isCoinWithdrawAllowed(_value)) {
            revert CoinWithdrawError(_value, getCoinBalance());
        }
    }

    function requireERC20TokenWithdrawAllowed(address _tokenAddress, uint256 _value) private view {
        if(!isERC20TokenWithdrawAllowed(_tokenAddress, _value)) {
            revert ERC20TokenWithdrawError(_tokenAddress, _value, getERC20TokenBalance(_tokenAddress));
        }
    }

    function requireERC721TokenWithdrawAllowed(address _tokenAddress, uint256 _id) private view {
        if(!isERC721TokenWithdrawAllowed(_tokenAddress, _id)) {
            revert ERC721TokenWithdrawError(_tokenAddress, _id, 1, getERC721TokenBalance(_tokenAddress, _id));
        }
    }

    function requireERC1155TokenWithdrawAllowed(address _tokenAddress, uint256 _id, uint256 _value) private view {
        if(!isERC1155TokenWithdrawAllowed(_tokenAddress, _id, _value)) {
            revert ERC1155TokenWithdrawError(_tokenAddress, _id, _value, getERC1155TokenBalance(_tokenAddress, _id));
        }
    }

    function requireMintFee(uint256 _value) private view {
        if(!isMintFee(_value)) {
            revert MintFeeError(_value, getMintFee());
        }
    }

    function requireNotPaused() private view {
        if(isPaused()) {
            revert PausedContractError();
        }
    }

    function requireOperatorAddress(address _address) private view {
        if(!isOperatorAddress(_address)) {
            revert NotOperatorError(_address, getOperatorAddress());
        }
    }

    function requireOperatorSuccessorAddress(address _address) private view {
        if(!isOperatorSuccessorAddress(_address)) {
            revert NotOperatorSuccessorError(_address, getOperatorSuccessorAddress());
        }
    }

    function requireOwnerAddress(address _address) private view {
        if(!isOwnerAddress(_address)) {
            revert NotOwnerError(_address, getOwnerAddress());
        }
    }

    function requireOwnerSuccessorAddress(address _address) private view {
        if(!isOwnerSuccessorAddress(_address)) {
            revert NotOwnerSuccessorError(_address, getOwnerSuccessorAddress());
        }
    }

    function requireRemainingMints() private view {
        if(!isRemainingMints()) {
            revert NoRemainingMintsError();
        }
    }

    /*
        Get Functions
    */

    function getCoinBalance() private view returns (uint256) {
        return address(this).balance;
    }

    function getERC20TokenBalance(address _tokenAddress) private view returns (uint256) {
        return IERC20(_tokenAddress).balanceOf(address(this));
    }

    function getERC721TokenBalance(address _tokenAddress, uint256 _id) private view returns (uint256) {
        // Each ID is a unique NFT, so the balance is either 0 or 1.
        return IERC721(_tokenAddress).ownerOf(_id) == address(this) ? 1 : 0;
    }

    function getERC1155TokenBalance(address _tokenAddress, uint256 _id) private view returns (uint256) {
        return IERC1155(_tokenAddress).balanceOf(address(this), _id);
    }

    function getMintFee() private view returns (uint256) {
        return mintFee;
    }

    function getOperatorAddress() private view returns (address) {
        return operatorAddress;
    }

    function getOperatorSuccessorAddress() private view returns (address) {
        return operatorSuccessorAddress;
    }

    function getOwnerAddress() private view returns (address) {
        return ownerAddress;
    }

    function getOwnerSuccessorAddress() private view returns (address) {
        return ownerSuccessorAddress;
    }

    function getRemainingMints() private view returns (uint256) {
        return MAX_MINTS - currentID;
    }

    function getRoyaltyAddress() private view returns (address) {
        return royaltyAddress;
    }

    function getRoyaltyBasisPoints() private view returns (uint256) {
        return royaltyBasisPoints;
    }

    function getStoreDescription() private view returns (string memory) {
        return storeDescription;
    }

    function getStoreExternalLinkURI() private view returns (string memory) {
        return storeExternalLinkURI;
    }

    function getStoreImageURI() private view returns (string memory) {
        return storeImageURI;
    }

    function getStoreName() private view returns (string memory) {
        return storeName;
    }

    function getTotalMints() private view returns (uint256) {
        return currentID;
    }

    /*
        Set Functions
    */

    function setLocked(bool _isLocked) private {
        lockFlag = _isLocked;
    }

    function setMintFee(uint256 _mintFee) private {
        mintFee = _mintFee;
    }

    function setOperatorAddress(address _address) private {
        if(_address != operatorAddress) {
            emit OperatorChanged(operatorAddress, _address);
            operatorAddress = _address;
        }
    }

    function setOperatorSuccessorAddress(address _address) private {
        operatorSuccessorAddress = _address;
    }
    
    function setOwnerAddress(address _address) private {
        if(_address != ownerAddress) {
            emit OwnerChanged(ownerAddress, _address);
            ownerAddress = _address;
        }
    }

    function setOwnerSuccessorAddress(address _address) private {
        ownerSuccessorAddress = _address;
    }

    function setPause(bool _isPaused) private {
        pauseFlag = _isPaused;
    }

    function setRoyaltyAddress(address _royaltyAddress) private {
        royaltyAddress = _royaltyAddress;
    }

    function setRoyaltyBasisPoints(uint256 _royaltyBasisPoints) private {
        royaltyBasisPoints = _royaltyBasisPoints;
    }

    function setStoreDescription(string memory _storeDescription) private {
        storeDescription = _storeDescription;
    }

    function setStoreExternalLinkURI(string memory _storeExternalLinkURI) private {
        storeExternalLinkURI = _storeExternalLinkURI;
    }

    function setStoreImageURI(string memory _storeImageURI) private {
        storeImageURI = _storeImageURI;
    }

    function setStoreName(string memory _storeName) private {
        storeName = _storeName;
    }

    /*
        Reentrancy Functions
    */

    function lock() private {
        // Call this at the start of each external function that can change state to protect against reentrancy.
        if(isLocked()) {
            punish();
        }
        setLocked(true);
    }

    function unlock() private {
        // Call this at the end of each external function.
        setLocked(false);
    }

    /*
        Utility Functions
    */

    function addressToString(address _address) private pure returns(string memory) {
        // Convert the address to a checksum address string.
        return getChecksum(_address);
    }

    function punish() private pure {
        // This operation will cause a revert but also consume all the gas. This will punish those who are trying to attack the contract.
        assembly("memory-safe") { invalid() }
    }

    function transferCoinToAddress(address _address, uint256 _value) private {
        payable(_address).transfer(_value);
    }

    function transferERC20TokenToAddress(address _tokenAddress, address _address, uint256 _value) private {
        // Take extra care to account for tokens that don't revert on failure or that don't return a value.
        // A return value is optional, but if it is present then it must be true.
        if(_tokenAddress.code.length == 0) {
            revert ERC20TokenContractError(_tokenAddress);
        }

        bytes memory callData = abi.encodeWithSelector(IERC20(_tokenAddress).transfer.selector, _address, _value);
        (bool success, bytes memory returnData) = _tokenAddress.call(callData);

        if(!success || (returnData.length != 0 && !abi.decode(returnData, (bool)))) {
            revert ERC20TokenTransferError(_tokenAddress, _address, _value);
        }
    }

    function transferERC721TokenToAddress(address _tokenAddress, uint256 _id, address _address) private {
        // Take extra care to account for tokens that don't revert on failure or that don't return a value.
        // A return value is optional, but if it is present then it must be true.
        if(_tokenAddress.code.length == 0) {
            revert ERC721TokenContractError(_tokenAddress, _id);
        }

        bytes memory callData = abi.encodeWithSelector(IERC721(_tokenAddress).transferFrom.selector, address(this), _address, _id);
        (bool success, bytes memory returnData) = _tokenAddress.call(callData);

        if(!success || (returnData.length != 0 && !abi.decode(returnData, (bool)))) {
            revert ERC721TokenTransferError(_tokenAddress, _id, _address);
        }
    }

    function transferERC1155TokenToAddress(address _tokenAddress, uint256 _id, address _address, uint256 _value, bytes memory _data) private {
        // Take extra care to account for tokens that don't revert on failure or that don't return a value.
        // A return value is optional, but if it is present then it must be true.
        if(_tokenAddress.code.length == 0) {
            revert ERC1155TokenContractError(_tokenAddress, _id);
        }

        bytes memory callData = abi.encodeWithSelector(IERC1155(_tokenAddress).safeTransferFrom.selector, address(this), _address, _id, _value, _data);
        (bool success, bytes memory returnData) = _tokenAddress.call(callData);

        if(!success || (returnData.length != 0 && !abi.decode(returnData, (bool)))) {
            revert ERC1155TokenTransferError(_tokenAddress, _id, _address, _value);
        }
    }

    function uint256ToString(uint256 _i) private pure returns (string memory) {
        if(_i == 0) {
            return "0";
        }
        uint256 j = _i;
        uint256 len;
        while(j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint256 k = len;
        while(_i != 0) {
            k = k-1;
            uint8 temp = (48 + uint8(_i - _i / 10 * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }

    /*
        Address Checksum Functions
    */

    function getChecksum(address account) private pure returns (string memory accountChecksum) {
        return _toChecksumString(account);
    }

    function _toChecksumString(address account) private pure returns (string memory asciiString) {
        // convert the account argument from address to bytes.
        bytes20 data = bytes20(account);

        // create an in-memory fixed-size bytes array.
        bytes memory asciiBytes = new bytes(40);

        // declare variable types.
        uint8 b;
        uint8 leftNibble;
        uint8 rightNibble;
        bool leftCaps;
        bool rightCaps;
        uint8 asciiOffset;

        // get the capitalized characters in the actual checksum.
        bool[40] memory caps = _toChecksumCapsFlags(account);

        // iterate over bytes, processing left and right nibble in each iteration.
        for(uint256 i = 0; i < data.length; i++) {
            // locate the byte and extract each nibble.
            b = uint8(uint160(data) / (2**(8*(19 - i))));
            leftNibble = b / 16;
            rightNibble = b - 16 * leftNibble;

            // locate and extract each capitalization status.
            leftCaps = caps[2*i];
            rightCaps = caps[2*i + 1];

            // get the offset from nibble value to ascii character for left nibble.
            asciiOffset = _getAsciiOffset(leftNibble, leftCaps);

            // add the converted character to the byte array.
            asciiBytes[2 * i] = bytes1(leftNibble + asciiOffset);

            // get the offset from nibble value to ascii character for right nibble.
            asciiOffset = _getAsciiOffset(rightNibble, rightCaps);

            // add the converted character to the byte array.
            asciiBytes[2 * i + 1] = bytes1(rightNibble + asciiOffset);
        }

        return string.concat("0x", string(asciiBytes));
    }

    function _toChecksumCapsFlags(address account) private pure returns (bool[40] memory characterCapitalized) {
        // convert the address to bytes.
        bytes20 a = bytes20(account);

        // hash the address (used to calculate checksum).
        bytes32 b = keccak256(abi.encodePacked(_toAsciiString(a)));

        // declare variable types.
        uint8 leftNibbleAddress;
        uint8 rightNibbleAddress;
        uint8 leftNibbleHash;
        uint8 rightNibbleHash;

        // iterate over bytes, processing left and right nibble in each iteration.
        for(uint256 i; i < a.length; i++) {
            // locate the byte and extract each nibble for the address and the hash.
            rightNibbleAddress = uint8(a[i]) % 16;
            leftNibbleAddress = (uint8(a[i]) - rightNibbleAddress) / 16;
            rightNibbleHash = uint8(b[i]) % 16;
            leftNibbleHash = (uint8(b[i]) - rightNibbleHash) / 16;

            characterCapitalized[2 * i] = (leftNibbleAddress > 9 && leftNibbleHash > 7);
            characterCapitalized[2 * i + 1] = (rightNibbleAddress > 9 && rightNibbleHash > 7);
        }
    }

    function _getAsciiOffset(uint8 nibble, bool caps) private pure returns (uint8 offset) {
        // to convert to ascii characters, add 48 to 0-9, 55 to A-F, & 87 to a-f.
        if(nibble < 10) {
            offset = 48;
        }
        else if(caps) {
            offset = 55;
        }
        else {
            offset = 87;
        }
    }

    // based on https://ethereum.stackexchange.com/a/56499/48410
    function _toAsciiString(bytes20 data) private pure returns (string memory asciiString) {
        // create an in-memory fixed-size bytes array.
        bytes memory asciiBytes = new bytes(40);

        // declare variable types.
        uint8 b;
        uint8 leftNibble;
        uint8 rightNibble;

        // iterate over bytes, processing left and right nibble in each iteration.
        for(uint256 i = 0; i < data.length; i++) {
            // locate the byte and extract each nibble.
            b = uint8(uint160(data) / (2 ** (8 * (19 - i))));
            leftNibble = b / 16;
            rightNibble = b - 16 * leftNibble;

            // to convert to ascii characters, add 48 to 0-9 and 87 to a-f.
            asciiBytes[2 * i] = bytes1(leftNibble + (leftNibble < 10 ? 48 : 87));
            asciiBytes[2 * i + 1] = bytes1(rightNibble + (rightNibble < 10 ? 48 : 87));
        }

        return string(asciiBytes);
    }

    /*
    *
    *
        External Functions
    *
    *
    */

    /*
        Action Functions
    */

    /// @notice The operator successor can claim the operator role.
    function action_claimOperatorRole() external {
        lock();

        requireOperatorSuccessorAddress(msg.sender);

        claimOperatorRole(msg.sender);

        unlock();
    }

    /// @notice The owner successor can claim the owner role.
    function action_claimOwnerRole() external {
        lock();

        requireOwnerSuccessorAddress(msg.sender);

        claimOwnerRole(msg.sender);

        unlock();
    }

    /// @notice A user can mint an NFT for a token address.
    /// @param _data Additional data with no specified format.
    function action_mint(bytes memory _data) external payable {
        lock();

        requireRemainingMints();
        requireMintFee(msg.value);

        mint(msg.sender, _data);

        unlock();
    }

    /// @notice The operator can trigger a mint for someone else.
    /// @param _address The address that the operator is triggering the mint for.
    /// @param _data Additional data with no specified format.
    function action_mintOther(address _address, bytes memory _data) external payable {
        lock();

        requireOperatorAddress(msg.sender);
        requireRemainingMints();
        requireMintFee(msg.value);
        
        mint(_address, _data);

        unlock();
    }

    /// @notice The operator can offer the operator role to a successor address.
    /// @param _address The operator successor address.
    function action_offerOperatorRole(address _address) external {
        lock();

        requireOperatorAddress(msg.sender);

        offerOperatorRole(_address);

        unlock();
    }

    /// @notice The owner can offer the owner role to a successor address.
    /// @param _address The owner successor address.
    function action_offerOwnerRole(address _address) external {
        lock();

        requireOwnerAddress(msg.sender);

        offerOwnerRole(_address);

        unlock();
    }

    /*
        Withdraw Functions
    */

    /// @notice The operator can withdraw any amount of coins.
    /// @param _value The amount of coins to withdraw.
    function withdraw_coins(uint256 _value) external {
        lock();

        requireOperatorAddress(msg.sender);
        requireCoinWithdrawAllowed(_value);

        withdrawCoins(msg.sender, _value);

        unlock();
    }

    /// @notice The operator can withdraw any amount of one kind of ERC20 token.
    /// @param _tokenAddress The address where the ERC20 token's contract lives.
    /// @param _value The amount of ERC20 tokens to withdraw.
    function withdraw_erc20Tokens(address _tokenAddress, uint256 _value) external {
        lock();

        requireOperatorAddress(msg.sender);
        requireERC20TokenWithdrawAllowed(_tokenAddress, _value);

        withdrawERC20Tokens(_tokenAddress, msg.sender, _value);

        unlock();
    }

    /// @notice The operator can withdraw an ERC721 token.
    /// @param _tokenAddress The address where the ERC721 token's contract lives.
    /// @param _id The ID of the ERC721 token.
    function withdraw_erc721Tokens(address _tokenAddress, uint256 _id) external {
        lock();

        requireOperatorAddress(msg.sender);
        requireERC721TokenWithdrawAllowed(_tokenAddress, _id);

        withdrawERC721Tokens(_tokenAddress, _id, msg.sender);

        unlock();
    }

    /// @notice The operator can withdraw any amount of one kind of ERC1155 token.
    /// @param _tokenAddress The address where the ERC1155 token's contract lives.
    /// @param _id The ID of the ERC1155 token.
    /// @param _value The amount of ERC1155 tokens to withdraw.
    /// @param _data Additional data with no specified format.
    function withdraw_erc1155Tokens(address _tokenAddress, uint256 _id, uint256 _value, bytes memory _data) external {
        lock();

        requireOperatorAddress(msg.sender);
        requireERC1155TokenWithdrawAllowed(_tokenAddress, _id, _value);

        withdrawERC1155Tokens(_tokenAddress, _id, msg.sender, _value, _data);

        unlock();
    }

    /*
        Query Functions
    */

    /// @notice Returns whether the contract is currently locked.
    /// @return Whether the contract is currently locked.
    function query_isLocked() external view returns (bool) {
        return isLocked();
    }

    /// @notice Returns whether the address is the operator address.
    /// @param _address The address that we are checking.
    /// @return Whether the address is the operator address.
    function query_isOperatorAddress(address _address) external view returns (bool) {
        return isOperatorAddress(_address);
    }

    /// @notice Returns whether the address is the operator successor address.
    /// @param _address The address that we are checking.
    /// @return Whether the address is the operator successor address.
    function query_isOperatorSuccessorAddress(address _address) external view returns (bool) {
        return isOperatorSuccessorAddress(_address);
    }

    /// @notice Returns whether the address is the owner address.
    /// @param _address The address that we are checking.
    /// @return Whether the address is the owner address.
    function query_isOwnerAddress(address _address) external view returns (bool) {
        return isOwnerAddress(_address);
    }

    /// @notice Returns whether the address is the owner successor address.
    /// @param _address The address that we are checking.
    /// @return Whether the address is the owner successor address.
    function query_isOwnerSuccessorAddress(address _address) external view returns (bool) {
        return isOwnerSuccessorAddress(_address);
    }

    /// @notice Returns whether the contract is currently paused.
    /// @return Whether the contract is currently paused.
    function query_isPaused() external view returns (bool) {
        return isPaused();
    }

    /// @notice Returns whether there are any remaining NFT mints available.
    /// @return Whether there are any remaining NFT mints available.
    function query_isRemainingMints() external view returns (bool) {
        return isRemainingMints();
    }

    /*
        Get Functions
    */

    /// @notice Returns the balance of coins.
    /// @return The balance of coins.
    function get_coinBalance() external view returns (uint256) {
        return getCoinBalance();
    }

    /// @notice Returns the balance of an ERC20 token.
    /// @param _tokenAddress The address where the ERC20 token's contract lives.
    /// @return The balance of an ERC20 token.
    function get_erc20tokenBalance(address _tokenAddress) external view returns (uint256) {
        return getERC20TokenBalance(_tokenAddress);
    }

    /// @notice Returns the balance of an ERC721 token.
    /// @param _tokenAddress The address where the ERC721 token's contract lives.
    /// @param _id The ID of the ERC721 token.
    /// @return The balance of an ERC721 token.
    function get_erc721tokenBalance(address _tokenAddress, uint256 _id) external view returns (uint256) {
        return getERC721TokenBalance(_tokenAddress, _id);
    }

    /// @notice Returns the balance of an ERC1155 token.
    /// @param _tokenAddress The address where the ERC1155 token's contract lives.
    /// @param _id The ID of the ERC1155 token.
    /// @return The balance of an ERC1155 token.
    function get_erc1155tokenBalance(address _tokenAddress, uint256 _id) external view returns (uint256) {
        return getERC1155TokenBalance(_tokenAddress, _id);
    }

    /// @notice Returns the mint fee.
    /// @return The mint fee.
    function get_mintFee() external view returns (uint256) {
        return getMintFee();
    }

    /// @notice Returns the operator address.
    /// @return The operator address.
    function get_operatorAddress() external view returns (address) {
        return getOperatorAddress();
    }

    /// @notice Returns the operator successor address.
    /// @return The operator successor address.
    function get_operatorSuccessorAddress() external view returns (address) {
        return getOperatorSuccessorAddress();
    }

    /// @notice Returns the owner address.
    /// @return The owner address.
    function get_ownerAddress() external view returns (address) {
        return getOwnerAddress();
    }

    /// @notice Returns the owner successor address.
    /// @return The owner successor address.
    function get_ownerSuccessorAddress() external view returns (address) {
        return getOwnerSuccessorAddress();
    }

    /// @notice Returns the number of remaining NFT mints available.
    /// @return The number of remaining NFT mints available.
    function get_remainingMints() external view returns (uint256) {
        return getRemainingMints();
    }

    /// @notice Returns the address that royalties will be paid to.
    /// @return The address that royalties will be paid to.
    function get_royaltyAddress() external view returns (address) {
        return getRoyaltyAddress();
    }

    /// @notice Returns the royalty basis points.
    /// @return The royalty basis points.
    function get_royaltyBasisPoints() external view returns (uint256) {
        return getRoyaltyBasisPoints();
    }

    /// @notice Returns the store description.
    /// @return The store description.
    function get_storeDescription() external view returns (string memory) {
        return getStoreDescription();
    }

    /// @notice Returns the store external link URI.
    /// @return The store external link URI.
    function get_storeExternalLinkURI() external view returns (string memory) {
        return getStoreExternalLinkURI();
    }

    /// @notice Returns the store image URI.
    /// @return The store image URI.
    function get_storeImageURI() external view returns (string memory) {
        return getStoreImageURI();
    }

    /// @notice Returns the store name.
    /// @return The store name.
    function get_storeName() external view returns (string memory) {
        return getStoreName();
    }

    /// @notice Returns the total number of NFTs that have been minted.
    /// @return The total number of NFTs that have been minted.
    function get_totalMints() external view returns (uint256) {
        return getTotalMints();
    }

    /*
        Set Functions
    */

    /// @notice The operator can set the address that royalties will be paid to.
    /// @param _royaltyAddress The new first address that royalties will be paid to.
    function set_royaltyAddress(address _royaltyAddress) external {
        lock();

        requireOperatorAddress(msg.sender);

        setRoyaltyAddress(_royaltyAddress);

        unlock();
    }

    /// @notice The operator can set the store description.
    /// @param _storeDescription The new store description.
    function set_storeDescription(string memory _storeDescription) external {
        lock();

        requireOperatorAddress(msg.sender);

        setStoreDescription(_storeDescription);

        unlock();
    }

    /// @notice The operator can set the store external link URI.
    /// @param _storeExternalLinkURI The new store external link URI.
    function set_storeExternalLinkURI(string memory _storeExternalLinkURI) external {
        lock();

        requireOperatorAddress(msg.sender);

        setStoreExternalLinkURI(_storeExternalLinkURI);

        unlock();
    }

    /// @notice The operator can set the store image URI.
    /// @param _storeImageURI The new store image URI.
    function set_storeImageURI(string memory _storeImageURI) external {
        lock();

        requireOperatorAddress(msg.sender);

        setStoreImageURI(_storeImageURI);

        unlock();
    }

    /// @notice The operator can set the store name.
    /// @param _storeName The new store name.
    function set_storeName(string memory _storeName) external {
        lock();

        requireOperatorAddress(msg.sender);

        setStoreName(_storeName);

        unlock();
    }

    /*
        Fail-Safe Functions
    */

    /// @notice The owner can pause the contract.
    function failsafe_pause() external {
        requireOwnerAddress(msg.sender);

        setPause(true);
    }

    /// @notice The owner can make themselves the operator.
    function failsafe_takeOperatorRole() external {
        requireOwnerAddress(msg.sender);

        setOperatorAddress(msg.sender);
        setOperatorSuccessorAddress(msg.sender);
    }

    /// @notice The owner can unlock the contract.
    function failsafe_unlock() external {
        requireOwnerAddress(msg.sender);

        setLocked(false);
    }

    /// @notice The owner can unpause the contract.
    function failsafe_unpause() external {
        requireOwnerAddress(msg.sender);

        setPause(false);
    }
}