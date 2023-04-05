// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PolyKickDAO is Ownable {
    address public financeWallet;

    struct Partner {
        uint256 id;
        address account;
        string name;
        uint256 sharePercentage;
    }

    enum ApprovalType {
        ADD,
        UPDATE,
        REMOVE
    }

    struct ApprovalRequest {
        ApprovalType approvalType;
        uint256 partnerId;
        string name;
        address account;
        uint256 sharePercentage;
        uint256 approvals;
        mapping(address => bool) approvedBy;
    }

    struct ProfitDistributionRequest {
        address token;
        uint256 toFinance;
        uint256 approvals;
        mapping(address => bool) approvedBy;
    }

    mapping(uint256 => ApprovalRequest) public approvalRequests;
    mapping(uint256 => Partner) public partners;
    mapping(uint256 => address) public emergencyAddressChangeApprovals;
    mapping(uint256 => bool) public ownerEmergencyAddressChangeApproval;
    mapping(uint256 => ProfitDistributionRequest)
        public profitDistributionRequests;

    uint256 public partnerCount;
    uint256 public reservedShares;

    event PartnerAdded(
        uint256 indexed partnerId,
        string name,
        address account,
        uint256 sharePercentage
    );
    event PartnerRemoved(uint256 indexed partnerId);
    event PartnerShareUpdated(
        uint256 indexed partnerId,
        uint256 newSharePercentage
    );
    event PartnerApproval(
        uint256 indexed partnerId,
        address indexed approver,
        ApprovalType indexed approvalType
    );
    event ApprovalReceived(address indexed approver, uint256 indexed partnerId);
    event EmergencyAddressChangeApproval(
        uint256 indexed partnerId,
        address indexed approver
    );
    event PartnerAddressUpdated(
        uint256 indexed partnerId,
        address indexed oldAddress,
        address indexed newAddress
    );
    event OwnerEmergencyAddressChangeApproval(
        uint256 indexed partnerId,
        address indexed owner
    );

    modifier onlyPartner() {
        require(
            partners[getPartnerIdByAddress(msg.sender)].sharePercentage >= 35,
            "Caller must be a partner with >= 35% shares"
        );
        _;
    }

    constructor() //address _owner,
    // address partner1,
    // address partner2,
    // address partner3,
    //address _financeWallet
    {
        financeWallet = 0x4177720ecC9741D247bd10b20902fE73Ea127C5f;
        transferOwnership(msg.sender);
        addPrePartner(
            "CryptoHalal",
            0x3e6275f3AbC45b508d7f70De11d3950a4A04e26F,
            47
        );
        addPrePartner(
            "TokenBench",
            0xb6B8EcE610c1543E112F8cEc5f2404d785b803d9,
            43
        );
        addPrePartner(
            "MetaIdentity",
            0xc9362C3b93706B3E4ee6d32a2b2310129E5B3C9e,
            10
        );
    }

    function initiateProfitDistributionRequest(
        address _token,
        uint256 toFinance
    ) external {
        ProfitDistributionRequest storage request = profitDistributionRequests[
            1
        ];
        require(
            request.approvals == 0,
            "Existing profit distribution request in progress"
        );

        request.token = _token;
        request.toFinance = toFinance;

        _approveProfitDistributionRequest();
    }

    function approveProfitDistributionRequest() external onlyPartner {
        _approveProfitDistributionRequest();
    }

    function _approveProfitDistributionRequest() internal {
        ProfitDistributionRequest storage request = profitDistributionRequests[
            1
        ];

        if (request.approvedBy[msg.sender] == false) {
            request.approvals++;
            request.approvedBy[msg.sender] = true;
        }

        // Check if the change has been approved by the admin and a partner with at least 35% shares
        if (request.approvedBy[owner()] && request.approvals >= 2) {
            distributeProfits(request.token, request.toFinance);

            // Reset the approval request
            delete profitDistributionRequests[1];
        }
    }

    function claimExpenses(address _token, uint256 _amount) internal {
        require(
            IERC20(_token).transfer(financeWallet, _amount),
            "Expenses transfer failed"
        );
    }

    function distributeProfits(address _token, uint256 toFinance) internal {
        require(_token != address(0x0), "zero address");
        require(toFinance != 0, "Finance can not be zero");
        claimExpenses(_token, toFinance);

        uint256 totalBalance = IERC20(_token).balanceOf(address(this)) -
            toFinance;
        uint256 distributedAmount = 0;

        for (uint256 i = 1; i <= partnerCount; i++) {
            Partner storage partner = partners[i];
            uint256 partnerShare = (totalBalance * partner.sharePercentage) /
                100;
            distributedAmount += partnerShare;
            require(
                IERC20(_token).transfer(partner.account, partnerShare),
                "Partner transfer failed"
            );
        }

        // Any remaining amount should be transferred back to the finance wallet
        uint256 remainingAmount = totalBalance - distributedAmount;
        if (remainingAmount > 0) {
            require(
                IERC20(_token).transfer(financeWallet, remainingAmount),
                "Remaining transfer failed"
            );
        }
    }

    function addPrePartner(
        string memory name,
        address account,
        uint256 sharePercentage
    ) internal {
        partnerCount++;
        Partner storage newPartner = partners[partnerCount];
        newPartner.id = partnerCount;
        newPartner.account = account;
        newPartner.name = name;
        newPartner.sharePercentage = sharePercentage;

        emit PartnerAdded(partnerCount, name, account, sharePercentage);
    }

    function addPartner(
        string memory name,
        address account,
        uint256 sharePercentage,
        uint256[] memory updatedPartnerIds,
        uint256[] memory updatedSharePercentages
    ) internal {
        // Redistribute shares among existing partners
        for (uint256 i = 0; i < updatedPartnerIds.length; i++) {
            uint256 partnerId = updatedPartnerIds[i];
            require(partnerId <= partnerCount, "Invalid partner ID");
            partners[partnerId].sharePercentage = updatedSharePercentages[i];
        }

        // Use reserved shares from the vault if available
        if (reservedShares > 0) {
            require(
                reservedShares >= sharePercentage,
                "Not enough reserved shares"
            );
            reservedShares -= sharePercentage;
        }

        partnerCount++;
        Partner storage newPartner = partners[partnerCount];
        newPartner.id = partnerCount;
        newPartner.account = account;
        newPartner.name = name;
        newPartner.sharePercentage = sharePercentage;

        emit PartnerAdded(partnerCount, name, account, sharePercentage);
    }

    function removePartner(uint256 partnerId) internal {
        require(partnerId <= partnerCount, "Invalid partner ID");

        // Move removed partner's shares to the vault
        reservedShares += partners[partnerId].sharePercentage;
        delete partners[partnerId];

        emit PartnerRemoved(partnerId);
    }

    function updatePartnerShare(uint256 partnerId, uint256 newSharePercentage)
        internal
    {
        require(partnerId <= partnerCount, "Invalid partner ID");

        uint256 oldSharePercentage = partners[partnerId].sharePercentage;
        uint256 totalShares = getTotalShares();

        // Check if the updated share percentage keeps total shares at 100
        require(
            totalShares - oldSharePercentage + newSharePercentage <= 100,
            "Total shares must not exceed 100"
        );

        // Use reserved shares from the vault if needed
        if (newSharePercentage > oldSharePercentage) {
            uint256 extraSharesNeeded = newSharePercentage - oldSharePercentage;
            require(
                reservedShares >= extraSharesNeeded,
                "Not enough reserved shares"
            );
            reservedShares -= extraSharesNeeded;
        } else {
            reservedShares += oldSharePercentage - newSharePercentage;
        }

        partners[partnerId].sharePercentage = newSharePercentage;
        emit PartnerShareUpdated(partnerId, newSharePercentage);
    }

    function getPartner(uint256 partnerId)
        external
        view
        returns (Partner memory)
    {
        require(partnerId <= partnerCount, "Invalid partner ID");
        return partners[partnerId];
    }

    function getTotalShares() public view returns (uint256) {
        uint256 totalShares = 0;
        for (uint256 i = 1; i <= partnerCount; i++) {
            totalShares += partners[i].sharePercentage;
        }
        return totalShares;
    }

    function initiateApprovalRequest(
        ApprovalType approvalType,
        uint256 partnerId,
        string memory name,
        address account,
        uint256 sharePercentage,
        uint256[] memory updatedPartnerIds,
        uint256[] memory updatedSharePercentages
    ) external {
        ApprovalRequest storage request = approvalRequests[partnerId];
        require(
            request.approvals == 0,
            "Existing approval request in progress"
        );

        request.approvalType = approvalType;
        request.partnerId = partnerId;
        request.name = name;
        request.account = account;
        request.sharePercentage = sharePercentage;

        _approveRequest(partnerId, updatedPartnerIds, updatedSharePercentages);
    }

    function approveRequest(
        uint256 partnerId,
        uint256[] memory updatedPartnerIds,
        uint256[] memory updatedSharePercentages
    ) external {
        _approveRequest(partnerId, updatedPartnerIds, updatedSharePercentages);
    }

    function _approveRequest(
        uint256 partnerId,
        uint256[] memory updatedPartnerIds,
        uint256[] memory updatedSharePercentages
    ) internal {
        ApprovalRequest storage request = approvalRequests[partnerId];
        require(request.approvals < 3, "No approval request to approve");

        if (request.approvedBy[msg.sender] == false) {
            request.approvals++;
            request.approvedBy[msg.sender] = true;
        }

        emit PartnerApproval(partnerId, msg.sender, request.approvalType);

        // Check if the change has been approved by at least two partners and the owner
        if (request.approvals >= 3) {
            if (request.approvalType == ApprovalType.ADD) {
                addPartner(
                    request.name,
                    request.account,
                    request.sharePercentage,
                    updatedPartnerIds,
                    updatedSharePercentages
                );
            } else if (request.approvalType == ApprovalType.UPDATE) {
                updatePartnerShare(partnerId, request.sharePercentage);
            } else if (request.approvalType == ApprovalType.REMOVE) {
                removePartner(partnerId);
            }

            // Reset the approval request
            delete approvalRequests[partnerId];
        }
    }

    function emergencyUpdatePartnerAddress(
        uint256 partnerId,
        address newAddress
    ) external {
        require(partnerId <= partnerCount, "Invalid partner ID");
        require(newAddress != address(0), "Invalid new address");

        Partner storage partner = partners[partnerId];
        require(partner.account != newAddress, "Same address provided");

        if (msg.sender == owner()) {
            ownerEmergencyAddressChangeApproval[partnerId] = true;
            emit OwnerEmergencyAddressChangeApproval(partnerId, msg.sender);
            return;
        }

        Partner storage approver = partners[getPartnerIdByAddress(msg.sender)];
        require(
            approver.sharePercentage >= 35,
            "Insufficient share percentage to approve"
        );

        require(
            ownerEmergencyAddressChangeApproval[partnerId],
            "Owner approval required"
        );

        address oldAddress = partner.account;
        partner.account = newAddress;

        delete emergencyAddressChangeApprovals[partnerId];
        delete ownerEmergencyAddressChangeApproval[partnerId];

        emit PartnerAddressUpdated(partnerId, oldAddress, newAddress);
    }

    function getPartnerIdByAddress(address partnerAddress)
        internal
        view
        returns (uint256)
    {
        for (uint256 i = 1; i <= partnerCount; i++) {
            if (partners[i].account == partnerAddress) {
                return i;
            }
        }
        return 0;
    }

    function getAllPartners()
        external
        view
        returns (Partner[] memory partnerList)
    {
        partnerList = new Partner[](partnerCount);

        for (uint256 i = 1; i <= partnerCount; i++) {
            partnerList[i - 1] = partners[i];
        }
    }
}


                /*********************************************************
                  Proudly Developed by MetaIdentity ltd. Copyright 2023
                **********************************************************/
