// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./PolyKick_ILO.sol";


contract PolyKick_Factory{

    PolyKick_ILO private pkILO;

    uint256 constant months = 30 days;
    uint256 constant MAX_UINT = 2**256 - 1;
    uint256 public projectsAllowed;
    uint256 public projectsCount;
    address public owner;
    uint256 private pID;

    event projectAdded(uint256 ProjectID, string ProjectName, IERC20 ProjectToken, address ProjectOwner);
    event ILOCreated(address pkILO);
    event ChangeOwner(address NewOwner);

    struct allowedProjects{
        uint256 projectID;
        string projectName;
        address projectOwner;
        IERC20 projectToken;
        uint8 tokenDecimals;
        address ILO;
        uint256 rounds;
        uint256 totalAmounts;
        uint256 polyKickPercentage;
        bool projectStatus;
    }

    struct Currencies{
        string name;
        uint8 decimals;
    }
    mapping(IERC20 => Currencies) public allowedCurrencies;
    mapping(IERC20 => bool) public isCurrency;
    mapping(IERC20 => bool) public isProject;
    mapping(uint256 => allowedProjects) public projectsByID;
    mapping(IERC20 => uint256) private pT;

/* @dev: Check if contract owner */
    modifier onlyOwner (){
        require(msg.sender == owner, "Not Owner!");
        _;
    }

    constructor(){
        owner = msg.sender;
        pID = 0;
    }
/*
    @dev: Change the contract owner
*/
    function transferOwnership(address _newOwner)external onlyOwner{
        require(_newOwner != address(0x0),"Zero Address");
        emit ChangeOwner(_newOwner);
        owner = _newOwner;
    }
    function addCurrency(string memory _name, IERC20 _currency, uint8 _decimal) external onlyOwner{
        //can also fix incase of wrong data
        allowedCurrencies[_currency].name = _name;
        allowedCurrencies[_currency].decimals = _decimal;
        isCurrency[_currency] = true; 
    }
    function addProject(string memory _name, IERC20 _token, uint8 _tokenDecimals, address _projectOwner, uint256 _polyKickPercentage) external onlyOwner returns(uint256) {
        require(isProject[_token] != true, "Project already exist!");
        pID++;
        projectsByID[pID].projectID = pID;
        projectsByID[pID].projectName = _name;
        projectsByID[pID].projectOwner = _projectOwner;
        projectsByID[pID].projectToken = _token;
        projectsByID[pID].tokenDecimals = _tokenDecimals;
        projectsByID[pID].projectStatus = true;
        isProject[_token] = true;
        pT[_token] = pID;
        projectsByID[pID].polyKickPercentage = _polyKickPercentage;
        projectsAllowed++;
        emit projectAdded(pID, _name, _token, _projectOwner);
        return(pID);
    }
    function projectNewRound(IERC20 _token) external onlyOwner{
        projectsByID[pT[_token]].projectStatus = true;
    }
    function startILO(
        IERC20 _token, 
        uint256 _tokenAmount, 
        IERC20 _currency, 
        uint256 _price, 
        uint8 _priceDecimals, 
        uint256 _target,
        uint256 _months
        ) external{
        require(isProject[_token] == true, "Project is not allowed!");
        require(projectsByID[pT[_token]].projectStatus == true, "ILO was initiated");
        require(_token.balanceOf(msg.sender) >= _tokenAmount,"Not enough tokens");
        require(isCurrency[_currency] ==true, "Currency is not allowed!");
        require(_priceDecimals <= allowedCurrencies[_currency].decimals, "Decimals error!");
        projectsByID[pT[_token]].projectStatus = false;
        address _polyKick = owner;
        _months = _months * months;
        uint8 priceDecimals = allowedCurrencies[_currency].decimals - _priceDecimals;
        uint256 price = _price*10**priceDecimals;
        uint8 _tokenDecimals = projectsByID[pT[_token]].tokenDecimals;
        uint256 _duration = _months + block.timestamp;

        pkILO = new PolyKick_ILO(
            msg.sender, 
            _polyKick, 
            _token,
            _tokenDecimals, 
            _tokenAmount,
            _currency, 
            price,
            _target, 
            _duration,
            projectsByID[pID].polyKickPercentage
            );
        emit ILOCreated(address(pkILO));
        _token.transferFrom(msg.sender, address(pkILO), _tokenAmount);
        projectsCount++;
        registerILO(_token, _tokenAmount);
    }
    function registerILO(IERC20 _token, uint256 _tokenAmount) internal{
        projectsByID[pT[_token]].rounds++;
        projectsByID[pT[_token]].totalAmounts += _tokenAmount;
        projectsByID[pT[_token]].ILO = address(pkILO);
    }
}

               /*********************************************************
                  Proudly Developed by MetaIdentity ltd. Copyright 2022
               **********************************************************/
