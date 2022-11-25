// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./PolyKick_ILO.sol";


contract PolyKick_Factory{

    PolyKick_ILO private pkILO;

    uint256 constant months = 30 days;
    uint256 projectsCount;
    address public owner;
    uint256 pID;

    event projectAdded(uint256 ProjectID, string ProjectName, ERC20 ProjectToken, address ProjectOwner);
    event ILOCreated(address pkILO);
    event ChangeOwner(address NewOwner);

    struct allowedProjects{
        uint256 projectID;
        string projectName;
        address projectOwner;
        ERC20 projectToken;
        uint8 tokenDecimals;
        bool projectStatus;
    }

    struct Currencies{
        string name;
        uint8 decimals;
    }
    mapping(ERC20 => Currencies) public allowedCurrencies;
    mapping(ERC20 => bool) public isCurrency;
    mapping(ERC20 => bool) public isProject;
    mapping(uint256 => allowedProjects) public projectsByID;
    mapping(ERC20 => uint256) private pT;

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
    function addCurrency(string memory _name, ERC20 _currency, uint8 _decimal) external onlyOwner{
        //can also fix incase of wrong data
        allowedCurrencies[_currency].name = _name;
        allowedCurrencies[_currency].decimals = _decimal;
        isCurrency[_currency] = true; 
    }
    function addProject(string memory _name, ERC20 _token, uint8 _tokenDecimals, address _projectOwner) external onlyOwner returns(uint256) {
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
        projectsCount++;
        emit projectAdded(pID, _name, _token, _projectOwner);
        return(pID);
    }


    function startLaunchpad(
        ERC20 _token, 
        uint256 _tokenAmount, 
        ERC20 _currency, 
        uint256 _price, 
        uint8 _priceDecimals, 
        uint256 _target,
        uint256 _months
        ) external returns(address){
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
        uint8 _tokenDecimals = projectsByID[pID].tokenDecimals;
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
            _duration
            );
        emit ILOCreated(address(pkILO));   
        _token.transferFrom(msg.sender, address(pkILO), _tokenAmount);
        projectsCount++;
        return(address(pkILO));
    }
}

               /*********************************************************
                  Proudly Developed by MetaIdentity ltd. Copyright 2022
               **********************************************************/
