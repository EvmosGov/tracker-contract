// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

// Imports
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

error BetterBounty__NotAdmin();
error BetterBounty__CannotPayoutZeroAddress();
error BetterBounty__InvalidPercentage();
error BetterBounty__NotFunds();
error BetterBounty__NoBountyWithId();
error BetterBounty__AlreadyWorking();

contract BetterBounty is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    struct Bounty {
        string id;
        uint256 pool;
        address[] funders;
        address[] workers;
        string deadline;
    }

    mapping(string => Bounty) bounties;

    mapping(address => bool) adminAuth;


    function initialize() public initializer {
        //Adding contract creator to admins array
        adminAuth[msg.sender] = true;
        __Ownable_init();
        __UUPSUpgradeable_init();
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyOwner
    {}

    /*
     * If the bounty is open, add the attached deposit to the pool and add the attached account to the
     * funders array
     * @param {string} _id - The ID of the issue that the bounty is attached to.
     * @param {string} _deadline - The deadline for the bounty , set by the first funder
     */
    function fundBounty(string memory _id, string memory _deadline)
        public
        payable
    {
        //Validating sent funds
        if (msg.value == 0) revert BetterBounty__NotFunds();

        Bounty memory bounty = bounties[_id];

        //If bounty with that id does not exist, create a new bounty
        if (keccak256(bytes(bounty.id)) == keccak256(bytes(""))) {
            Bounty memory newBounty = Bounty({
                id: _id,
                pool: msg.value,
                funders: new address[](0),
                workers: new address[](0),
                deadline: _deadline
            });
            bounties[_id] = newBounty;
            bounties[_id].funders.push(msg.sender);
        }
        //If bounty is open, attach the funds and add funder to funders list
        else {
            bounty.pool += msg.value;

            bool isNewFunder = true;

            //Checking if funder already exists on the array
            for (uint256 i; i < bounty.funders.length; ++i) {
                if (bounty.funders[i] == msg.sender) {
                    isNewFunder = false;
                    break;
                }
            }

            bounties[_id] = bounty;

            //Pushing new funder to the funders array
            if (isNewFunder) {
                bounties[_id].funders.push(msg.sender);
            }
        }
    }

    /*
     * If the bounty is open, add the sender to the list of workers.
     * @param {string} _id - The ID of the issue that you want to start working on.
     */
    function startWork(string memory _id) public {
        Bounty memory bounty = bounties[_id];
        if (keccak256(bytes(bounty.id)) == keccak256(bytes("")))
            revert BetterBounty__NoBountyWithId();

        address[] memory workersFromMemory = bounty.workers;
        uint256 length = workersFromMemory.length;
        if (length != 0) {
            // Preventing the same account from starting multiple work on the same bounty
            for (uint256 i; i < length; ++i) {
                if (workersFromMemory[i] == msg.sender) {
                    revert BetterBounty__AlreadyWorking();
                }
            }
        }
        bounties[_id].workers.push(msg.sender);
    }

    /*
     * It takes in an issue ID, a worker wallet, and a percentage, and then it pays out the bounty to the
     * worker wallet
     * @param {string} _id - The ID of the issue that you want to payout
     * @param {address} workerWallet - The wallet address of the worker who will receive the payout
     * @param {uint256} percentage - The percentage of the bounty pool that the worker should be paid,
     */
    function payoutBounty(
        string memory _id,
        address workerWallet,
        uint256 percentage
    ) public payable onlyAdmin {
        if (workerWallet == address(0x0))
            revert BetterBounty__CannotPayoutZeroAddress();

        if (percentage < 0 || percentage > 100)
            revert BetterBounty__InvalidPercentage();

        Bounty memory bounty = bounties[_id];
        if (keccak256(bytes(bounty.id)) == keccak256(bytes("")))
            revert BetterBounty__NoBountyWithId();

        uint256 amountToPayout = 0;

        amountToPayout = calculatePercentage(percentage, bounty.pool);
        bounties[_id].pool -= amountToPayout;

        payable(workerWallet).transfer(amountToPayout);
    }

    /*
     * Get the bounty associated with the given issue ID, or null if there is no such bounty.
     * @param {string} _id - The id of the issue you want to get the bounty for.
     * @returns A bounty object
     */
    function getBountyById(string memory _id)
        public
        view
        returns (Bounty memory)
    {
        return bounties[_id];
    }

    /*
     *This function is used to calculate the payout for a bounty based on percetage
     * worker wallet
     * @param {uint256} percentage - Between 0 to 100
     * @param {uint256} pool - The amount of money stored in the bounty
     * @returns the amount of money to payout
     */
    function calculatePercentage(uint256 percentage, uint256 pool)
        internal
        pure
        returns (uint256)
    {
        uint256 newPercentage = percentage * 100;
        uint256 payout = (pool / 10000) * newPercentage;
        return payout;
    }

    function addAdmin(address _adminWallet) public onlyAdmin {
        adminAuth[_adminWallet] = true;
    }

    function isAdmin(address _adminWallet) public view returns (bool) {
        return adminAuth[_adminWallet];
    }

    function removeAdmin(address _adminWallet) public onlyAdmin {
        adminAuth[_adminWallet] = false;
    }

    //Making sure only admins can call a certain function
    modifier onlyAdmin() {
        if (!adminAuth[msg.sender]) revert BetterBounty__NotAdmin();
        _;
    }
}