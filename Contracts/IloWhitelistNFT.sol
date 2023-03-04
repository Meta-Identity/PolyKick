// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

interface PolyKick {
    function addToWhiteListBulk(address[] calldata _addresses) external;
}

contract IloWhitelistNFT is ERC721 {

    PolyKick public iloContract;
    address public owner;
    
    uint256 public constant NUM_SPECIAL_NFTS = 300;
    uint256 public constant rareNFT = 30;

    uint256 public rareNftsMinted = 0;
    uint256 public specialNftsMinted = 0;
    uint256 public totalNftsMinted = 0;
    uint256 public batchSize = 1000;

    mapping(address => uint256) public userWhitelistedIlos;
    mapping(address => bool) public isAdmin;

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
    function mint(address _to) external onlyAdmin {
        require(userWhitelistedIlos[_to] == 0, "already minted for user");
        uint256 tokenId;
        if (
            specialNftsMinted < NUM_SPECIAL_NFTS && 
            uint256(keccak256(abi.encodePacked(_to, totalNftsMinted))) % 
            (NUM_SPECIAL_NFTS + totalNftsMinted) < NUM_SPECIAL_NFTS - specialNftsMinted) 
            {
              tokenId = totalNftsMinted + NUM_SPECIAL_NFTS + specialNftsMinted;
              specialNftsMinted++;
              userWhitelistedIlos[_to] = 10;
        } else {
            tokenId = totalNftsMinted;
            totalNftsMinted++;
            userWhitelistedIlos[_to] = 3;
        }
        _safeMint(_to, tokenId);
    }
    function mintRare(address _to, uint256 _numWhitelistedIlos) external onlyOwner {
        require(rareNftsMinted < rareNFT, "Maximum number of rare NFTs has been reached");
        uint256 tokenId = totalNftsMinted + NUM_SPECIAL_NFTS + specialNftsMinted + rareNftsMinted + rareNFT + 300000;
        _safeMint(_to, tokenId);
        userWhitelistedIlos[_to] = _numWhitelistedIlos;
        rareNftsMinted++;
    }
    function transfer(address _to, uint256 _tokenId) external {
        require(_isApprovedOrOwner(_msgSender(), _tokenId), "ERC721: transfer caller is not owner nor approved");
        _transfer(_msgSender(), _to, _tokenId);
        userWhitelistedIlos[_to] = userWhitelistedIlos[msg.sender];
        delete userWhitelistedIlos[msg.sender];
    }

    function canParticipate(address _user, uint256 _numWhitelistedIlos) external view returns (bool) {
        return userWhitelistedIlos[_user] >= _numWhitelistedIlos;
    }

    function addToWhiteListBulkFromNFT() external onlyAdmin{
        require(totalNftsMinted > 0, "No NFTs have been minted");
        address[] memory usersToAddToWhiteList;
        uint256 numUsersToAddToWhiteList = 0;
        for (uint256 i = 0; i < totalNftsMinted; i++) {
            address user = ownerOf(i);
            if (userWhitelistedIlos[user] > 0) {
                usersToAddToWhiteList[numUsersToAddToWhiteList] = user;
                numUsersToAddToWhiteList++;
                userWhitelistedIlos[user] -= 1;
            }
        }

        uint256 numBatches = (numUsersToAddToWhiteList + batchSize - 1) / batchSize;
        for (uint256 i = 0; i < numBatches; i++) {
            uint256 startIndex = i * batchSize;
            uint256 endIndex = startIndex + batchSize;
            if (endIndex > numUsersToAddToWhiteList) {
               endIndex = numUsersToAddToWhiteList;
            }
            address[] memory batch = new address[](endIndex - startIndex);
            for (uint256 j = startIndex; j < endIndex; j++) {
                batch[j - startIndex] = usersToAddToWhiteList[j];
            }
            iloContract.addToWhiteListBulk(batch);
        }
    }

}

               /*********************************************************
                  Proudly Developed by MetaIdentity ltd. Copyright 2023
               **********************************************************/
