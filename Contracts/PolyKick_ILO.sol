// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

interface polyNFT {
    function balanceOf(address) external view returns (uint256);

    function tokensOfOwner(address) external view returns (uint256[] memory);

    function tokenDetails(address, uint256)
        external
        view
        returns (
            uint256,
            string memory,
            uint256,
            string memory
        );

    function useNFT(address, uint256) external;
}

interface polyFactory {
    function polyKickDAO() external view returns (address);

    function owner() external view returns (address);

    function allowedCurrencies(IERC20 _token)
        external
        view
        returns (string memory, uint8);
}

contract PolyKick_ILO {
    using SafeMath for uint256;

    polyNFT public nftContract;
    polyFactory public factoryContract;

    address public constant burn = 0x000000000000000000000000000000000000dEaD;

    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    uint256 earlySale;

    IERC20 public token;
    uint8 public tokenDecimals;
    uint256 public tokenAmount;
    IERC20 public currency;
    uint8 public currencyDecimals;
    uint256 public basePrice;
    uint256 public preSoftCapPrice;
    uint256 public softCap;
    uint256 public duration;
    uint256 public preMaxAmount;
    uint256 public preMinAmount;
    uint256 public preMaxC;
    uint256 public preMinC;
    uint256 public maxAmount;
    uint256 public minAmount;
    uint256 public maxC;
    uint256 public minC;
    uint256 public salesCount;
    uint256 public buyersCount;

    address public seller;
    address public polyWallet;
    address public polyKickDAO;

    uint256 public sellerVault;
    uint256 public soldAmounts;
    uint256 public notSold;
    uint256 public tokensBurned;
    uint256 public raisedAmount;

    uint256 private pkPercentage;
    uint256 private toPolykick;
    uint256 private toExchange;

    bool public success = false;
    bool public fundsReturn = false;
    bool public isInitiated = false;

    address[] public buyersList;

    struct buyerVault {
        uint256 tokenAmount;
        uint256 currencyPaid;
        uint256 txCount;
        bool isClaimed;
        uint256 nftId;
        bool activeNFT;
    }

    struct NFTData {
        uint256 tokenId;
        string link;
        uint256 vouchers;
    }

    mapping(address => bool) public isWhitelisted;
    mapping(address => buyerVault) public buyer;
    mapping(address => bool) public isBuyer;
    mapping(address => bool) public isAdmin;

    event iloInitiated(bool status);
    event approveILO(string Result);
    event successfulILO(
        string Results,
        uint256 TokensSold,
        uint256 TokensRemaining,
        uint256 TokensBurned,
        uint256 RaisedAmount
    );
    event tokenSale(uint256 CurrencyAmount, uint256 TokenAmount);
    event tokenWithdraw(address indexed buyer, uint256 amount);
    event CurrencyReturned(address Buyer, uint256 Amount);
    event discountSet(uint256 Discount, bool Status);
    event whiteList(address Buyer, bool Status);

    /* @dev: Check if Admin */
    modifier onlyAdmin() {
        require(isAdmin[msg.sender] == true, "Not Admin!");
        _;
    }
    /* @dev: Check if contract owner */
    modifier onlyOwner() {
        require(msg.sender == polyWallet, "Not Owner!");
        _;
    }

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
        uint256 _softCap,
        uint256 _pkPercentage,
        uint256 _toPolykick,
        uint256 _toExchange
    ) {
        factoryContract = polyFactory(msg.sender);
        seller = _seller;
        polyWallet = _polyKick;
        token = _token;
        tokenDecimals = _tokenDecimals;
        tokenAmount = _tokenAmount;
        currency = _currency;
        basePrice = _price;
        softCap = _softCap;
        pkPercentage = _pkPercentage;
        toPolykick = _toPolykick;
        toExchange = _toExchange;
        _status = _NOT_ENTERED;
        notSold = _tokenAmount;
        isAdmin[polyWallet] = true;
    }

    function initiateILO(
        uint256 _earlySale,
        uint256 _preSoftCapPrice,
        uint256 _preMin,
        uint256 _preMax,
        uint256 _min,
        uint256 _max,
        uint256 _days
    ) external onlyAdmin {
        require(!isInitiated, "ILO initiated");
        polyKickDAO = factoryContract.polyKickDAO();
        setCurrencyDecimals();
        earlySale = _earlySale.mul(1 hours).add(block.timestamp);
        preSoftCapPrice = _preSoftCapPrice;
        preMinBuyMax(_preMin, _preMax, preSoftCapPrice, currencyDecimals);
        minBuyMax(_min, _max, basePrice, currencyDecimals);
        isInitiated = true;
        duration = (_days * 1 days) + block.timestamp;
        emit iloInitiated(isInitiated);
    }

    function addAdmin(address _newAdmin) external onlyOwner {
        require(_newAdmin != address(0), "Adrs 0!");
        require(!isAdmin[_newAdmin], "Admin exist");
        isAdmin[_newAdmin] = true;
    }

    function removeAdmin(address _admin) external onlyAdmin {
        require(isAdmin[_admin], "No admin");
        isAdmin[_admin] = false;
    }

    function setPolyDAO(address _DAO) external onlyAdmin {
        require(_DAO != address(0), "Adrs 0");
        polyKickDAO = _DAO;
    }

    function setPolyNFT(address _polyNFT) external onlyAdmin {
        require(_polyNFT != address(0), "Adrs 0");
        nftContract = polyNFT(_polyNFT);
    }

    function isActive() public view returns (bool) {
        if (duration < block.timestamp) {
            return false;
        } else {
            return true;
        }
    }

    function minBuyMax(
        uint256 minAmt,
        uint256 maxAmt,
        uint256 _price,
        uint8 _dcml
    ) internal {
        uint256 min = minAmt * 10**_dcml;
        uint256 max = maxAmt * 10**_dcml;
        minAmount = (min.div(_price)) * 10**tokenDecimals;
        maxAmount = (max.div(_price)) * 10**tokenDecimals;
        minC = minAmt;
        maxC = maxAmt;
    }

    function preMinBuyMax(
        uint256 minAmt,
        uint256 maxAmt,
        uint256 _price,
        uint8 _dcml
    ) internal {
        uint256 min = minAmt * 10**_dcml;
        uint256 max = maxAmt * 10**_dcml;
        preMinAmount = (min.div(_price)) * 10**tokenDecimals;
        preMaxAmount = (max.div(_price)) * 10**tokenDecimals;
        preMinC = minAmt;
        preMaxC = maxAmt;
    }

    function setCurrencyDecimals() internal {
        (, uint8 returnedDecimals) = factoryContract.allowedCurrencies(
            currency
        );
        currencyDecimals = returnedDecimals;
    }

    function getRaised() public view returns (uint256 _raised) {
        if (sellerVault != 0) {
            _raised = sellerVault.div(10**currencyDecimals);
        } else {
            _raised = raisedAmount.div(10**currencyDecimals);
        }
        return _raised;
    }

    function iloInfo()
        public
        view
        returns (
            uint256 tokensSold,
            uint256 tokensRemaining,
            uint256 burned,
            uint256 sales,
            uint256 participants,
            uint256 raised
        )
    {
        if (tokensBurned != 0) {
            burned = tokensBurned.div(10**tokenDecimals);
        } else {
            burned = 0;
        }
        raised = getRaised();
        if (raised == 0) {
            raised = raisedAmount.div(10**currencyDecimals);
        }
        return (
            soldAmounts.div(10**tokenDecimals),
            notSold.div(10**tokenDecimals),
            burned,
            // Price,
            salesCount,
            buyersCount,
            raised
        );
    }

    function addToWhiteList(address[] memory _allowed) external onlyAdmin {
        for (uint256 i = 0; i < _allowed.length; i++) {
            require(_allowed[i] != address(0x0), "Adrs 0");
            isWhitelisted[_allowed[i]] = true;
        }
    }

    function extendILO(uint256 _duration) external onlyAdmin {
        require(duration != 0, "ILO ended");
        fundsReturn = true;
        duration = _duration.add(block.timestamp);
    }

    function isSoftCap() public view returns (bool) {
        if (soldAmounts < softCap) {
            return true;
        } else {
            return false;
        }
    }

    function isEarlySale() public view returns (bool) {
        if (block.timestamp < earlySale) {
            return true;
        } else {
            return false;
        }
    }

    function getBuyerNFTs(address _buyer)
        public
        view
        returns (NFTData[] memory)
    {
        // Get the list of NFTs owned by the buyer
        uint256[] memory tokens = nftContract.tokensOfOwner(_buyer);

        // Create an array of NFTData
        NFTData[] memory buyerNFTs = new NFTData[](tokens.length);

        // Loop through all the NFTs
        for (uint256 i = 0; i < tokens.length; i++) {
            // Get the details of the NFT
            (uint256 _vouchers, , , string memory _link) = nftContract
                .tokenDetails(_buyer, tokens[i]);

            // Store the NFT data
            buyerNFTs[i] = NFTData({
                tokenId: tokens[i],
                link: _link,
                vouchers: _vouchers
            });
        }

        // Return the array of buyer's NFT data
        return buyerNFTs;
    }

    function activateNFT(uint256 _tokenId) external {
        (uint256 ILOs, , , ) = nftContract.tokenDetails(msg.sender, _tokenId);
        require(ILOs > 0, "No NFT");
        buyer[msg.sender].nftId = _tokenId;
        buyer[msg.sender].activeNFT = true;
    }

    function deactivateNFT() external {
        require(buyer[msg.sender].activeNFT == true, "No active NFT");
        buyer[msg.sender].activeNFT = false;
        buyer[msg.sender].nftId = 0;
    }

    function returnActiveNFT(address _buyer) public view returns (uint256) {
        return buyer[_buyer].nftId;
    }

    function allowedToBuy(address _buyer) public view returns (bool) {
        uint256 _tokenId = buyer[_buyer].nftId;
        (uint256 ILOs, , , ) = nftContract.tokenDetails(_buyer, _tokenId);
        if (ILOs > 0 || buyer[_buyer].txCount > 0) {
            return true;
        } else {
            return false;
        }
    }

    function useActiveNFT(address _buyer) internal {
        uint256 _tokenId = buyer[_buyer].nftId;
        nftContract.useNFT(_buyer, _tokenId);
    }

    function buyTokens(uint256 _amountToPay) external nonReentrant {
        require(isWhitelisted[msg.sender] == true, "Not whitelisted");
        require(isActive(), "ILO not active!");
        if (isEarlySale()) {
            require(allowedToBuy(msg.sender) == true, "Not allowed");
        }
        uint256 amount = _amountToPay * 10**tokenDecimals;
        uint256 finalAmount;

        if (isSoftCap() && allowedToBuy(msg.sender)) {
            finalAmount = amount.div(preSoftCapPrice); //pricePerToken;
            require(
                buyer[msg.sender].tokenAmount.add(finalAmount) <= preMaxAmount,
                "Limit reached"
            );
            if (buyer[msg.sender].txCount == 0) {
                require(finalAmount >= minAmount, "under minimum");
                useActiveNFT(msg.sender); // remove 1 ILO participation from NFT holder
            }
            require(finalAmount <= maxAmount, "over maximum");
        } else if (isSoftCap()) {
            finalAmount = amount.div(preSoftCapPrice); //pricePerToken;
            require(
                buyer[msg.sender].tokenAmount.add(finalAmount) <= preMaxAmount,
                "Limit reached"
            );
            if (buyer[msg.sender].txCount == 0) {
                require(finalAmount >= preMinAmount, "under pre-minimum");
            }
            require(finalAmount <= preMaxAmount, "Above pre-maximum!");
        } else {
            finalAmount = amount.div(basePrice); //pricePerToken;
            require(
                buyer[msg.sender].tokenAmount.add(finalAmount) <= maxAmount,
                "Limit reached"
            );
            if (buyer[msg.sender].txCount == 0) {
                require(finalAmount >= minAmount, "under minimum");
            }
            require(finalAmount <= maxAmount, "over maximum");
        }

        emit tokenSale(_amountToPay, finalAmount);
        require(
            currency.allowance(msg.sender, address(this)) >= _amountToPay,
            "currency allowance"
        );
        require(
            currency.transferFrom(msg.sender, address(this), _amountToPay),
            "currency balance"
        );
        sellerVault += _amountToPay;
        buyer[msg.sender].tokenAmount += finalAmount;
        buyer[msg.sender].currencyPaid += _amountToPay;
        soldAmounts += finalAmount;
        notSold -= finalAmount;
        if (isBuyer[msg.sender] != true) {
            isBuyer[msg.sender] = true;
            buyersList.push(msg.sender);
            buyersCount++;
        }
        salesCount++;
        buyer[msg.sender].txCount++;
    }

    function iloApproval() external onlyAdmin {
        require(!isActive(), "ILO not ended!");
        if (soldAmounts >= softCap) {
            duration = 0;
            success = true;
            tokensBurned = notSold;
            token.transfer(burn, notSold);
            emit successfulILO(
                "ILO Succeed",
                soldAmounts,
                notSold,
                tokensBurned,
                sellerVault
            );
        } else {
            duration = 0;
            success = false;
            fundsReturn = true;
            sellerVault = 0;
            emit approveILO("ILO Failed");
        }
    }

    function succeedILO() external onlyAdmin {
        uint256 tenPercent = softCap.mul(10).div(100);
        require(soldAmounts >= softCap.sub(tenPercent), "softCap not reached");
        duration = 0;
        success = true;
        tokensBurned = notSold;
        token.transfer(burn, notSold);
        emit successfulILO(
            "ILO Succeed",
            soldAmounts,
            notSold,
            tokensBurned,
            sellerVault
        );
    }

    function setMinMax(uint256 _minAmount, uint256 _maxAmount)
        external
        onlyAdmin
    {
        minBuyMax(_minAmount, _maxAmount, basePrice, currencyDecimals);
    }

    function withdrawTokens(address _buyer) public nonReentrant {
        require(isBuyer[_buyer] == true, "Not a Buyer");
        require(success == true, "ILO Failed");
        uint256 buyerAmount = buyer[_buyer].tokenAmount;
        emit tokenWithdraw(_buyer, buyerAmount);
        token.transfer(_buyer, buyerAmount);
        buyer[_buyer].tokenAmount -= buyerAmount;
        isBuyer[_buyer] = false;
        buyer[_buyer].isClaimed = true;
    }

    function returnFunds(address _buyer) public nonReentrant {
        require(isBuyer[_buyer] == true, "Not Buyer");
        require(success == false && fundsReturn == true, "ILO Succeed!");
        uint256 buyerAmount = buyer[_buyer].currencyPaid;
        emit CurrencyReturned(_buyer, buyerAmount);
        currency.transfer(_buyer, buyerAmount);
        buyer[_buyer].currencyPaid -= buyerAmount;
        buyer[_buyer].tokenAmount = 0;
        isBuyer[_buyer] = false;
        buyer[_buyer].isClaimed = true;
    }

    function distributeTokens(uint256 start, uint256 end) external onlyAdmin {
        require(end <= buyersList.length, "Beyond range");
        require(start <= end, "Invalid range");

        if (success == true) {
            for (uint256 i = start; i < end; i++) {
                address _buyer = buyersList[i];
                if (
                    isBuyer[_buyer] == true && buyer[_buyer].isClaimed == false
                ) {
                    withdrawTokens(_buyer);
                }
            }
        } else if (fundsReturn == true) {
            for (uint256 i = start; i < end; i++) {
                address _buyer = buyersList[i];
                if (
                    isBuyer[_buyer] == true && buyer[_buyer].isClaimed == false
                ) {
                    returnFunds(_buyer);
                }
            }
        }
    }

    function sellerWithdraw() external nonReentrant {
        require(msg.sender == seller, "Not seller");
        require(!isActive(), "ILO active!");
        if (success == true) {
            require(sellerVault != 0, "claimed!");
            raisedAmount = sellerVault;
            uint256 polyKickAmount = sellerVault.mul(pkPercentage).div(100);
            uint256 totalPolykick = polyKickAmount.add(toPolykick);
            uint256 sellerAmount = sellerVault.sub(totalPolykick).sub(
                toExchange
            );
            if (toExchange > 0) {
                currency.transfer(polyWallet, toExchange);
            }
            currency.transfer(polyKickDAO, polyKickAmount);
            currency.transfer(polyKickDAO, toPolykick);
            currency.transfer(seller, sellerAmount);
        } else if (success == false) {
            token.transfer(seller, token.balanceOf(address(this)));
        }
        sellerVault = 0;
    }

    function emergencyRefund(uint256 _confirm) external onlyAdmin {
        require(success != true, "ILO successful");
        require(isActive(), "ILO ended");
        require(_confirm == 369, "Wrong!");
        success = false;
        fundsReturn = true;
        sellerVault = 0;
        duration = 0;
        emit approveILO("ILO Failed");
    }

    function getBuyerTokenAmounts()
        external
        view
        returns (address[] memory, uint256[] memory)
    {
        uint256[] memory tokenAmounts = new uint256[](buyersList.length);
        address[] memory buyerAddresses = new address[](buyersList.length);

        for (uint256 i = 0; i < buyersList.length; i++) {
            uint256 _tokenAmount = buyer[buyersList[i]].tokenAmount;
            tokenAmounts[i] = _tokenAmount / (10**tokenDecimals); // Remove 18 decimals
            buyerAddresses[i] = buyersList[i];
        }

        return (buyerAddresses, tokenAmounts);
    }

    function getUnclaimedBalances()
        external
        view
        returns (address[] memory, uint256[] memory)
    {
        uint256[] memory tokenAmounts = new uint256[](buyersList.length);
        address[] memory buyerAddresses = new address[](buyersList.length);

        for (uint256 i = 0; i < buyersList.length; i++) {
            uint256 _tokenAmount = buyer[buyersList[i]].tokenAmount;
            if (_tokenAmount > 0) {
                tokenAmounts[i] = _tokenAmount / (10**tokenDecimals); // Remove 18 decimals
                buyerAddresses[i] = buyersList[i];
            }
        }

        return (buyerAddresses, tokenAmounts);
    }

    function getBuyerCurrencyAmounts()
        external
        view
        returns (address[] memory, uint256[] memory)
    {
        uint256[] memory currencyAmounts = new uint256[](buyersList.length);
        address[] memory buyerAddresses = new address[](buyersList.length);

        for (uint256 i = 0; i < buyersList.length; i++) {
            uint256 _currencyAmount = buyer[buyersList[i]].currencyPaid;
            currencyAmounts[i] = _currencyAmount / (10**currencyDecimals); // Remove 6 decimals
            buyerAddresses[i] = buyersList[i];
        }

        return (buyerAddresses, currencyAmounts);
    }

    /*
   @dev: Withdraw any ERC20 token sent by mistake or extra currency amounts
*/
    function erc20Withdraw(IERC20 _token) external onlyOwner {
        uint256 amountAvailable;
        if (_token == currency) {
            amountAvailable = _token.balanceOf(address(this)).sub(sellerVault);
            require(amountAvailable > 0, "No extra!");
            _token.transfer(polyWallet, amountAvailable);
        } else if (_token == token) {
            amountAvailable = _token.balanceOf(address(this)).sub(tokenAmount);
            require(amountAvailable > 0, "No extra!");
            _token.transfer(polyWallet, amountAvailable);
        } else {
            amountAvailable = _token.balanceOf(address(this));
            _token.transfer(polyWallet, amountAvailable);
        }
    }

    /*
   @dev: people who send Matic by mistake to the contract can withdraw them
*/
    mapping(address => uint256) public balanceReceived;

    function wrongSend() public payable {
        assert(
            balanceReceived[msg.sender] + msg.value >=
                balanceReceived[msg.sender]
        );
        balanceReceived[msg.sender] += msg.value;
    }

    function withdrawWrongTransaction(address payable _to, uint256 _amount)
        public
    {
        require(_amount <= balanceReceived[msg.sender], "funds!.");
        assert(
            balanceReceived[msg.sender] >= balanceReceived[msg.sender] - _amount
        );
        balanceReceived[msg.sender] -= _amount;
        _to.transfer(_amount);
    }

    receive() external payable {
        wrongSend();
    }
}

                /*********************************************************
                    Proudly Developed by MetaIdentity ltd. Copyright 2023
                **********************************************************/
