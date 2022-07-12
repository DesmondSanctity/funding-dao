// SPDX-License-Identifier: MIT
// /contracts/FundingDao.sol
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract FundingDAO is ReentrancyGuard, AccessControl {
    bytes32 public constant MEMBER = keccak256("MEMBER");
    bytes32 public constant STAKEHOLDER = keccak256("STAKEHOLDER");

    uint32 constant votingPeriod = 3 days;

    uint256 public proposalsCount = 0;

    struct Proposal {
        uint256 id;
        uint256 amount;
        uint256 livePeriod;
        uint256 voteInFavor;
        uint256 voteAgainst;
        string title;
        string desc;
        bool isCompleted;
        bool paid;
        bool isPaid;
        address payable receiverAddress;
        address proposer;
        uint256 totalFundRaised;
        Funding[] funders;
        string imageId;
    }

    struct Funding {
        address payer;
        uint256 amount;
        uint256 timestamp;
    }

    mapping(uint256 => Proposal) private proposals;
    mapping(address => uint256) private stakeholders;
    mapping(address => uint256) private members;
    mapping(address => uint256[]) private votes;

    event NewMember(address indexed fromAddress, uint256 amount);
    event NewProposal(address indexed proposer, uint256 amount);
    event Payment(
        address indexed stakeholder,
        address indexed projectAddress,
        uint256 amount
    );

    modifier onlyMember(string memory message) {
        require(hasRole(MEMBER, msg.sender), message);
        _;
    }

    modifier onlyStakeholder(string memory message) {
        require(hasRole(STAKEHOLDER, msg.sender), message);
        _;
    }

    function createProposal(
        string calldata title,
        string calldata desc,
        address receiverAddress,
        uint256 amount,
        string calldata imageId
    ) public payable onlyMember("Only members can create new proposal.") {
        require(
            msg.value == 5 * 10**18,
            "You need to add 5 MATIC to create a proposal"
        );
        uint256 proposalId = proposalsCount;
        Proposal storage proposal = proposals[proposalId];
        proposal.id = proposalId;
        proposal.desc = desc;
        proposal.title = title;
        proposal.receiverAddress = payable(receiverAddress);
        proposal.proposer = payable(msg.sender);
        proposal.amount = amount;
        proposal.livePeriod = block.timestamp + votingPeriod;
        proposal.isPaid = false;
        proposal.isCompleted = false;
        proposal.imageId = imageId;
        proposalsCount++;
        emit NewProposal(msg.sender, amount);
    }

    function getAllProposals() public view returns (Proposal[] memory) {
        Proposal[] memory tempProposals = new Proposal[](proposalsCount);
        for (uint256 index = 0; index < proposalsCount; index++) {
            tempProposals[index] = proposals[index];
        }
        return tempProposals;
    }

    function getProposal(uint256 proposalId)
        public
        view
        returns (Proposal memory)
    {
        return proposals[proposalId];
    }

    function getVotes()
        public
        view
        onlyStakeholder("Only Stakeholder can call this function.")
        returns (uint256[] memory)
    {
        return votes[msg.sender];
    }

    function getStakeholderBal()
        public
        view
        onlyStakeholder("Only Stakeholder can call this function.")
        returns (uint256)
    {
        return stakeholders[msg.sender];
    }

    function getMemberBal()
        public
        view
        onlyMember("Only Members can call this function.")
        returns (uint256)
    {
        return members[msg.sender];
    }

    function isStakeholder() public view returns (bool) {
        return stakeholders[msg.sender] > 0;
    }

    function isMember() public view returns (bool) {
        return members[msg.sender] > 0;
    }

    function vote(uint256 proposalId, bool inFavour)
        public
        onlyStakeholder("Only Stakeholders can vote on a proposal.")
    {
        Proposal storage proposal = proposals[proposalId];

        if (proposal.isCompleted || proposal.livePeriod <= block.timestamp) {
            proposal.isCompleted = true;
            revert("Time period of this proposal is ended.");
        }
        for (uint256 i = 0; i < votes[msg.sender].length; i++) {
            if (proposal.id == votes[msg.sender][i])
                revert("You can only vote once.");
        }

        if (inFavour) proposal.voteInFavor++;
        else proposal.voteAgainst++;

        votes[msg.sender].push(proposalId);
    }

    function provideFunds(uint256 proposalId, uint256 fundAmount)
        public
        payable
        onlyStakeholder("Only Stakeholders can make payments")
    {
        Proposal storage proposal = proposals[proposalId];

        if (proposal.isPaid) revert("Required funds are provided.");
        if (proposal.voteInFavor <= proposal.voteAgainst)
            revert("This proposal is not selected for funding.");
        if (proposal.totalFundRaised >= proposal.amount)
            revert("Required funds are provided.");
        proposal.totalFundRaised += fundAmount;
        proposal.funders.push(Funding(msg.sender, fundAmount, block.timestamp));
        if (proposal.totalFundRaised >= proposal.amount) {
            proposal.isCompleted = true;
        }
    }

    function releaseFunding(uint256 proposalId)
        public
        payable
        onlyStakeholder("Only Stakeholders are allowed to release funds")
    {
        Proposal storage proposal = proposals[proposalId];

        if (proposal.totalFundRaised <= proposal.amount) {
            revert("Required funds are not met. Please provider funds.");
        }
        proposal.receiverAddress.transfer(proposal.totalFundRaised);
        proposal.isPaid = true;
        proposal.isCompleted = true;
    }

    function createStakeholder() public payable {
        uint256 amount = msg.value;
        if (!hasRole(STAKEHOLDER, msg.sender)) {
            uint256 total = members[msg.sender] + amount;
            if (total >= 2 ether) {
                _setupRole(STAKEHOLDER, msg.sender);
                _setupRole(MEMBER, msg.sender);
                stakeholders[msg.sender] = total;
                members[msg.sender] += amount;
            } else {
                _setupRole(MEMBER, msg.sender);
                members[msg.sender] += amount;
            }
        } else {
            members[msg.sender] += amount;
            stakeholders[msg.sender] += amount;
        }
    }
}