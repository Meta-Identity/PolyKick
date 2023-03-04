// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";


interface PolyKick {
    function addToWhiteListBulk(address[] memory _allowed) external;
    function addToWhiteList(address _allowed) external;
}

contract IloWhitelistNFT is ERC721 {

    PolyKick public iloContract;
    address public owner;
    
    uint256 public constant NUM_SPECIAL_NFTS = 300;
    uint256 public constant rareNFT = 9;

    uint256 public rareNftsMinted = 0;
    uint256 public specialNftsMinted = 0;
    uint256 public normalNftsMinted = 0;
    uint256 public totalNftsMinted = 0; //total supply
    uint256 public batchSize = 1000;

    struct polyNFT{
        uint256 tokenId;
        uint256 userWhitelistedIlos;
        string typeNFT;
    }

    mapping(address => polyNFT) public details;
    mapping(address => bool) public isAdmin;

    event polyMinted(address To, uint256 TokenID, string typeNFT);
    event whiteListed(address[] Addresses);

/* @dev: Check if Admin */
    modifier onlyAdmin (){
        require(isAdmin[msg.sender] == true, "Not Admin!");
        _;
    }

/* @dev: Check if contract owner */
    modifier onlyOwner (){
        require(msg.sender == owner, "Not Owner!");
        _;
    } 

    constructor(string memory _name, string memory _symbol) ERC721(_name, _symbol) {
        owner = msg.sender;
        isAdmin[owner] = true;
        isAdmin[address(this)] = true;
    }
     
    function setPolyKick(address _polyKick) external onlyAdmin{
        require(_polyKick != address(0x0),"address zero");
        iloContract = PolyKick(_polyKick);
    }
    function addAdmin(address _newAdmin) external onlyOwner{
        isAdmin[_newAdmin] = true;
    }
    function setBatchSize(uint256 _batchSize) external onlyAdmin {
        batchSize = _batchSize;
    }
    function uint2str(uint256 _i) internal pure returns (string memory) {
    if (_i == 0) {
        return "0";
    }
    uint256 j = _i;
    uint256 length;
    while (j != 0) {
        length++;
        j /= 10;
    }
    bytes memory bstr = new bytes(length);
    uint256 k = length;
    while (_i != 0) {
        k = k-1;
        uint8 temp = (48 + uint8(_i - _i / 10 * 10));
        bytes1 b1 = bytes1(temp);
        bstr[k] = b1;
        _i /= 10;
    }
    return string(bstr);
}

    function mintBatch(address[] memory _to) external onlyOwner {
    for (uint256 i = 0; i < _to.length; i++) {
        mint(_to[i]);
        }
    }
    function mint(address _to) public onlyAdmin {
    require(details[_to].userWhitelistedIlos == 0, "already minted for user");

    uint256 tokenId;
    string memory typeNFT;
    tokenId = totalNftsMinted;

    if (specialNftsMinted < NUM_SPECIAL_NFTS &&
        uint256(keccak256(abi.encodePacked(_to, totalNftsMinted))) % (NUM_SPECIAL_NFTS + totalNftsMinted) < NUM_SPECIAL_NFTS - specialNftsMinted) {
        details[_to].tokenId = tokenId;
        details[_to].userWhitelistedIlos = 10;
        specialNftsMinted++;
        typeNFT = string(abi.encodePacked("Special Polykick NFT ", uint2str(specialNftsMinted)));
    } else {
        tokenId = totalNftsMinted;
        details[_to].userWhitelistedIlos = 3;
        normalNftsMinted++;
        typeNFT = string(abi.encodePacked("Normal Polykick NFT", uint2str(normalNftsMinted)));
    }

    totalNftsMinted++;
    details[_to].typeNFT = typeNFT;

    emit polyMinted(_to, tokenId, typeNFT);
    _safeMint(_to, tokenId);
}

    function mintRare(address _to, uint256 _numWhitelistedIlos) external onlyOwner {
        require(rareNftsMinted < rareNFT, "Maximum number of rare NFTs has been reached");
        string memory typeNFT;
        uint256 tokenId = totalNftsMinted;
        typeNFT = string(abi.encodePacked("Rare Polykick NFT", uint2str(tokenId)));
        details[_to].userWhitelistedIlos = _numWhitelistedIlos;
        details[_to].typeNFT = typeNFT;
        rareNftsMinted++;
        totalNftsMinted++;
        emit polyMinted(_to, tokenId, typeNFT);
        _safeMint(_to, tokenId);
    }
    function transfer(address _to, uint256 _tokenId) external {
        require(_isApprovedOrOwner(_msgSender(), _tokenId), "ERC721: transfer caller is not owner nor approved");
        _transfer(_msgSender(), _to, _tokenId);
        details[_to].userWhitelistedIlos = details[msg.sender].userWhitelistedIlos;
        details[_to].typeNFT = details[msg.sender].typeNFT;
        details[_to].tokenId = _tokenId;

        delete details[msg.sender];
    }

    function canParticipate(address _user, uint256 _numWhitelistedIlos) external view returns (bool) {
        return details[_user].userWhitelistedIlos >= _numWhitelistedIlos;
    }
    
    function addToWhiteListBulkFromNFT() external {
    require(totalNftsMinted > 0, "No NFTs have been minted");

    uint256 numBatches = (totalNftsMinted + batchSize - 1) / batchSize;

    for (uint256 batchIndex = 0; batchIndex < numBatches; batchIndex++) {
        uint256 startIndex = batchIndex * batchSize;
        uint256 endIndex = startIndex + batchSize;

        if (endIndex > totalNftsMinted) {
            endIndex = totalNftsMinted;
        }

        address[] memory usersToAddToWhiteList = new address[](endIndex - startIndex);
        uint256 numUsersToAddToWhiteList = 0;

        for (uint256 i = startIndex; i < endIndex; i++) {
            address user = ownerOf(i);
            if (details[user].userWhitelistedIlos > 0) {
                usersToAddToWhiteList[numUsersToAddToWhiteList++] = user;
                details[user].userWhitelistedIlos--;
            }
        }
        emit whiteListed(usersToAddToWhiteList);
        iloContract.addToWhiteListBulk(usersToAddToWhiteList);
    }
}

}

               /*********************************************************
                  Proudly Developed by MetaIdentity ltd. Copyright 2023
               **********************************************************/
