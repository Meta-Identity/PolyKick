// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract PolyKick_ILO{

    address public factory;
    address public constant burn = 0x000000000000000000000000000000000000dEaD;

    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    ERC20 public token;
    uint8 public tokenDecimals;
    uint256 public tokenAmount;
    ERC20 public currency;
    uint256 public price;
    uint256 public target;
    uint256 public duration;
    uint256 maxAmount;
    uint256 minAmount;
    uint256 public salesCount;

    struct buyerVault{
        uint256 tokenAmount;
        uint256 currencyPaid;
    }
    
    mapping(address => bool) public isWhitelisted;
    mapping(address => buyerVault) public buyer;
    mapping(address => bool) public isInvestor;

    address public seller;
    address public polyKick;

    uint256 public sellerVault;
    uint256 public soldAmounts;
    uint256 public notSold;
    uint256 polyKickPercentage;
    
    bool success;
    
    event approveLaunchpad(bool);
    event tokenSale(uint256 CurrencyAmount, uint256 TokenAmount);
    event tokenWithdraw(address Investor, uint256 Amount);
    event InvestmentReturned(address Investor, uint256 Amount);
/*
    @dev: prevent reentrancy when function is executed
*/
    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
    constructor(
           address _seller,
           address _polyKick,
           ERC20 _token,
           uint8 _tokenDecimals,
           uint256 _tokenAmount,
           ERC20 _currency, 
           uint256 _price,
           uint256 _target, 
           uint256 _duration
           ){
        seller = _seller;
        polyKick = _polyKick;
        token = _token;
        tokenDecimals = _tokenDecimals;
        tokenAmount = _tokenAmount;
        currency = _currency;
        price = _price;
        target = _target;
        duration = _duration;
        _status = _NOT_ENTERED;
        notSold = _tokenAmount;
    }

    function addToWhiteList(address[] memory _allowed) external{
        require(msg.sender == seller || msg.sender == polyKick,"not authorized");
        for(uint i=0; i<_allowed.length; i++){
            isWhitelisted[_allowed[i]] = true;
        }
    }
    function buyTokens(uint256 _amountToPay) external nonReentrant{
        require(isWhitelisted[msg.sender] == true, "You need to be White Listed for this ILO");
        require(block.timestamp < duration,"Launchpad Ended!");
        uint256 amount = _amountToPay / price; //pricePerToken;
        uint256 finalAmount = amount * 10 ** tokenDecimals;
        emit tokenSale(_amountToPay, amount);
        //The transfer requires approval from currency smart contract
        currency.transferFrom(msg.sender, address(this), _amountToPay);
        sellerVault += _amountToPay;
        buyer[msg.sender].tokenAmount = finalAmount;
        buyer[msg.sender].currencyPaid = _amountToPay;
        soldAmounts += finalAmount;
        notSold -= finalAmount;
        isInvestor[msg.sender] = true;
        salesCount++;
    }

    function launchpadApproval() external returns(bool){
        require(block.timestamp > duration, "Launchpad has not ended yet!");
        if(soldAmounts >= target){
            success = true;
            token.transfer(burn, notSold);
        }
        else{
            success = false;
            sellerVault = 0;
        }
        emit approveLaunchpad(success);
        return(success);
    }

    function withdrawTokens() external nonReentrant{
        require(block.timestamp > duration, "Launchpad has not ended yet!");
        require(isInvestor[msg.sender] == true,"Not an Investor");
        require(success == true, "Launchpad Failed");
        uint256 investorAmount = buyer[msg.sender].tokenAmount;
        emit tokenWithdraw(msg.sender, investorAmount);
        token.transfer(msg.sender, investorAmount);
        soldAmounts -= investorAmount;
        buyer[msg.sender].tokenAmount = 0;
        isInvestor[msg.sender] = false;
    }

    function returnInvestment() external nonReentrant{
        require(block.timestamp > duration, "Launchpad has not ended yet!");
        require(isInvestor[msg.sender] == true,"Not an Investor");
        require(success == false, "Launchpad Succeed try withdrawTokens");
        uint256 investorAmount = buyer[msg.sender].currencyPaid;
        emit InvestmentReturned(msg.sender, investorAmount);
        currency.transfer(msg.sender, investorAmount);
        buyer[msg.sender].currencyPaid = 0;
        isInvestor[msg.sender] = false;
    }

    function sellerWithdraw() external nonReentrant{
        require(msg.sender == seller,"Not official seller");
        require(block.timestamp > duration, "Launchpad has not ended yet!");
        uint256 polyKickAmount = sellerVault*5/100;
        uint256 sellerAmount = sellerVault - polyKickAmount;
        if(success == true){
            currency.transfer(polyKick, polyKickAmount);
            currency.transfer(seller, sellerAmount);
        }
        else{
            token.transfer(seller, token.balanceOf(address(this)));
        }
    }


/*
   @dev: people who send Matic by mistake to the contract can withdraw them
*/
    mapping(address => uint) public balanceReceived;

    function receiveMoney() public payable {
        assert(balanceReceived[msg.sender] + msg.value >= balanceReceived[msg.sender]);
        balanceReceived[msg.sender] += msg.value;
    }

    function withdrawWrongTrasaction(address payable _to, uint256 _amount) public {
        require(_amount <= balanceReceived[msg.sender], "not enough funds.");
        assert(balanceReceived[msg.sender] >= balanceReceived[msg.sender] - _amount);
        balanceReceived[msg.sender] -= _amount;
        _to.transfer(_amount);
    } 

    receive() external payable {
        receiveMoney();
    }
}


               /*********************************************************
                  Proudly Developed by MetaIdentity ltd. Copyright 2022
               **********************************************************/
    


