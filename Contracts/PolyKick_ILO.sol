// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract PolyKick_ILO{
using SafeMath for uint256;

    error InvalidAmount(uint256 min, uint256 max);
    address public factory;
    address public constant burn = 0x000000000000000000000000000000000000dEaD;

    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    IERC20 public token;
    uint8 public tokenDecimals;
    uint256 public tokenAmount;
    IERC20 public currency;
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
    mapping(address => bool) public isBuyer;

    address public seller;
    address public polyKick;

    uint256 public sellerVault;
    uint256 public soldAmounts;
    uint256 public notSold;
    uint256 private polyKickPercentage;
    
    bool success;
    
    event approveILO(bool);
    event tokenSale(uint256 CurrencyAmount, uint256 TokenAmount);
    event tokenWithdraw(address Buyer, uint256 Amount);
    event CurrencyReturned(address Buyer, uint256 Amount);
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
           IERC20 _token,
           uint8 _tokenDecimals,
           uint256 _tokenAmount,
           IERC20 _currency, 
           uint256 _price,
           uint256 _target, 
           uint256 _duration,
           uint256 _polyKickPercentage
           ){
        factory = msg.sender;
        seller = _seller;
        polyKick = _polyKick;
        token = _token;
        tokenDecimals = _tokenDecimals;
        tokenAmount = _tokenAmount;
        currency = _currency;
        price = _price;
        target = _target;
        duration = _duration;
        polyKickPercentage = _polyKickPercentage;
        minAmount = tokenAmount.mul(1).div(1000);
        maxAmount = tokenAmount.mul(1).div(100);
        _status = _NOT_ENTERED;
        notSold = _tokenAmount;
    }

    function addToWhiteListBulk(address[] memory _allowed) external{
        require(msg.sender == seller || msg.sender == polyKick,"not authorized");
        for(uint i=0; i<_allowed.length; i++){
            isWhitelisted[_allowed[i]] = true;
        }
    }
    function addToWhiteList(address _allowed) external{
        require(msg.sender == seller || msg.sender == polyKick,"not authorized");
        isWhitelisted[_allowed] = true;
    }
    function removeWhiteList(address _usr) external{
        require(msg.sender == seller || msg.sender == polyKick,"not authorized");
        isWhitelisted[_usr] = false;
    }
    function buyTokens(uint256 _amountToPay) external nonReentrant{
        require(isWhitelisted[msg.sender] == true, "You need to be White Listed for this ILO");
        require(block.timestamp < duration,"ILO Ended!");
        uint256 amount = _amountToPay.div(price); //pricePerToken;
        uint256 finalAmount = amount * 10 ** tokenDecimals;
        if(finalAmount < minAmount && finalAmount > maxAmount){
            revert InvalidAmount(minAmount, maxAmount);
        }
        emit tokenSale(_amountToPay, finalAmount);
        //The transfer requires approval from currency smart contract
        currency.transferFrom(msg.sender, address(this), _amountToPay);
        sellerVault += _amountToPay;
        buyer[msg.sender].tokenAmount = finalAmount;
        buyer[msg.sender].currencyPaid = _amountToPay;
        soldAmounts += finalAmount;
        notSold -= finalAmount;
        isBuyer[msg.sender] = true;
        salesCount++;
    }

    function iloApproval() external returns(bool){
        require(block.timestamp > duration, "ILO has not ended yet!");
        if(soldAmounts >= target){
            success = true;
            token.transfer(burn, notSold);
        }
        else{
            success = false;
            sellerVault = 0;
        }
        emit approveILO(success);
        return(success);
    }
    function changeMinMax(uint256 _min, uint256 _minM, uint256 _max, uint256 _maxM) external{
        require(msg.sender == seller, "Not authorized!");
        minAmount = tokenAmount.mul(_min).div(_minM);
        maxAmount = tokenAmount.mul(_max).div(_maxM);
    }
    function withdrawTokens() external nonReentrant{
        require(block.timestamp > duration, "ILO has not ended yet!");
        require(isBuyer[msg.sender] == true,"Not an Buyer");
        require(success == true, "ILO Failed");
        uint256 buyerAmount = buyer[msg.sender].tokenAmount;
        emit tokenWithdraw(msg.sender, buyerAmount);
        token.transfer(msg.sender, buyerAmount);
        soldAmounts -= buyerAmount;
        buyer[msg.sender].tokenAmount = 0;
        isBuyer[msg.sender] = false;
    }

    function returnFunds() external nonReentrant{
        require(block.timestamp > duration, "ILO has not ended yet!");
        require(isBuyer[msg.sender] == true,"Not an Buyer");
        require(success == false, "ILO Succeed try withdrawTokens");
        uint256 buyerAmount = buyer[msg.sender].currencyPaid;
        emit CurrencyReturned(msg.sender, buyerAmount);
        currency.transfer(msg.sender, buyerAmount);
        buyer[msg.sender].currencyPaid = 0;
        isBuyer[msg.sender] = false;
    }

    function sellerWithdraw() external nonReentrant{
        require(msg.sender == seller,"Not official seller");
        require(block.timestamp > duration, "ILO has not ended yet!");
        uint256 polyKickAmount = sellerVault.mul(polyKickPercentage).div(100);
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
    


