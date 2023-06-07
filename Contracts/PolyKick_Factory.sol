// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./PolyKick_ILO.sol";

contract PolyKick_Factory {
    PolyKick_ILO private pkILO;

    uint256 public projectsAllowed;
    uint256 public projectsCount;
    address public owner;
    address public polyKickDAO;
    uint256 private pID;
    uint256 private toPolykick;
    uint256 private toExchange;
    uint256 public countILO;

    address[] createdILOs;

    event projectAdded(
        uint256 ProjectID,
        string ProjectName,
        IERC20 ProjectToken,
        address ProjectOwner
    );
    event ILOCreated(address pkILO);
    event ChangeOwner(address NewOwner);

    struct allowedProjects {
        uint256 projectID;
        string projectName;
        address projectOwner;
        IERC20 projectToken;
        uint8 tokenDecimals;
        IERC20 currency;
        address ILO;
        uint256 rounds;
        uint256 totalAmounts;
        uint256 polyKickPercentage;
        bool projectStatus;
        bool isSoftCap;
    }

    struct Currencies {
        string name;
        uint8 decimals;
    }
    mapping(IERC20 => Currencies) public allowedCurrencies;
    mapping(IERC20 => bool) public isCurrency;
    mapping(IERC20 => bool) public isProject;
    mapping(IERC20 => allowedProjects) public projectsByID;

    mapping(address => bool) public isAdmin;

    /* @dev: Check if contract owner */
    modifier onlyOwner() {
        require(msg.sender == owner, "Not Owner!");
        _;
    }

    /* @dev: Check if contract owner */
    modifier onlyAdmin() {
        require(isAdmin[msg.sender] == true, "Not Admin!");
        _;
    }

    constructor() {
        owner = msg.sender;
        isAdmin[msg.sender] = true;
        pID = 0;
    }

    /*
    @dev: Change the contract owner
*/
    function transferOwnership(address _newOwner) external onlyOwner {
        require(_newOwner != address(0x0), "Z A");// zero address
        emit ChangeOwner(_newOwner);
        owner = _newOwner;
    }

    function addAdmin(address _admin) external onlyOwner {
        require(_admin != address(0x0), "Z A");// zero address
        isAdmin[_admin] = true;
    }

    function removeAdmin(address _admin) external onlyOwner {
        require(_admin != address(0x0), "Z A");// zero address
        isAdmin[_admin] = false;
    }

    function addCurrency(
        string memory _name,
        IERC20 _currency,
        uint8 _decimal
    ) external onlyAdmin {
        //can also fix incase of wrong data
        allowedCurrencies[_currency].name = _name;
        allowedCurrencies[_currency].decimals = _decimal;
        isCurrency[_currency] = true;
    }

    function addProject(
        string memory _name,
        IERC20 _token,
        uint8 _tokenDecimals,
        address _projectOwner,
        uint256 _polyKickPercentage,
        IERC20 _currency,
        uint256 _toPolykick,
        uint256 _toExchange
    ) external onlyAdmin returns (uint256) {
        require(isProject[_token] != true, "Project exist!");
        require(isCurrency[_currency] == true, "No currency");
        require(_polyKickPercentage <= 24, "Max is 24 %");
        pID++;
        uint8 dcml = allowedCurrencies[_currency].decimals;
        toPolykick = _toPolykick * 10**dcml;
        toExchange = _toExchange * 10**dcml;
        projectsByID[_token].projectID = pID;
        projectsByID[_token].projectName = _name;
        projectsByID[_token].projectOwner = _projectOwner;
        projectsByID[_token].projectToken = _token;
        projectsByID[_token].tokenDecimals = _tokenDecimals;
        projectsByID[_token].currency = _currency;
        projectsByID[_token].projectStatus = true;
        isProject[_token] = true;
        projectsByID[_token].polyKickPercentage = _polyKickPercentage;
        projectsAllowed++;
        emit projectAdded(pID, _name, _token, _projectOwner);
        return (pID);
    }

    function projectNewRound(IERC20 _token, IERC20 _currency)
        external
        onlyAdmin
    {
        projectsByID[_token].projectStatus = true;
        projectsByID[_token].currency = _currency;
        toPolykick = 0;
        toExchange = 0;
    }

    function softCapTo(
        uint256 _softCap,
        uint256 _price,
        IERC20 _token
    ) internal {
        uint8 tDcml = projectsByID[_token].tokenDecimals;
        uint256 trg = _softCap / 10**tDcml;
        uint256 trPrice = trg * _price;
        uint256 payTo = (toPolykick + toExchange);
        require(trPrice > payTo * 2, "softCap payments");
        projectsByID[_token].isSoftCap = true;
    }

    function startILO(
        IERC20 _token,
        uint256 _tokenAmount,
        uint256 _price,
        uint8 _priceDecimals,
        uint256 _softCap
    ) external onlyAdmin {
        IERC20 _currency = projectsByID[_token].currency;
        require(isProject[_token] == true, "not allowed!");
        require(
            projectsByID[_token].projectStatus == true,
            "ILO initiated"
        );
        require(
            _token.balanceOf(msg.sender) >= _tokenAmount,
            "Not enough tokens"
        );
        require(
            _priceDecimals <= allowedCurrencies[_currency].decimals,
            "Decimal err"
        );
        projectsByID[_token].projectStatus = false;
        uint256 _pkP = projectsByID[_token].polyKickPercentage;
        uint256 price = _price *
            10**(allowedCurrencies[_currency].decimals - _priceDecimals);
        uint8 _tokenDecimals = projectsByID[_token].tokenDecimals;
        softCapTo(_softCap, price, _token);
        require(projectsByID[_token].isSoftCap == true, "is softCap!");
        pkILO = new PolyKick_ILO(
            projectsByID[_token].projectOwner,
            owner,
            _token,
            _tokenDecimals,
            _tokenAmount,
            _currency,
            price,
            _softCap,
            _pkP,
            toPolykick,
            toExchange
        );
        emit ILOCreated(address(pkILO));
        createdILOs.push(address(pkILO));
        _token.transferFrom(msg.sender, address(pkILO), _tokenAmount);
        projectsCount++;
        registerILO(_token, _tokenAmount);
    }

    function registerILO(IERC20 _token, uint256 _tokenAmount) internal {
        projectsByID[_token].rounds++;
        projectsByID[_token].totalAmounts += _tokenAmount;
        projectsByID[_token].ILO = address(pkILO);
    }

    function getCreatedILOs() public view returns (address[] memory) {
        return createdILOs;
    }
}

                /*********************************************************
                  Proudly Developed by MetaIdentity ltd. Copyright 2023
                **********************************************************/
