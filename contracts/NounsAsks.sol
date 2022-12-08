/*
                 _                  _         _          _ 
                | |                | |       (_)        | |
 _ __  _ __ ___ | |_ ___   ___ ___ | |  _ __  ___  _____| |
| '_ \| '__/ _ \| __/ _ \ / __/ _ \| | | '_ \| \ \/ / _ \ |
| |_) | | | (_) | || (_) | (_| (_) | | | |_) | |>  <  __/ |
| .__/|_|  \___/ \__\___/ \___\___/|_| | .__/|_/_/\_\___|_|
| |                                    | |                 
|_|                                    |_|                 

                                                                                                                                         ~~                        ~~
Author: waterdrops. 
Credit: adapted from PartyBid by Anna Carroll
*/

// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract NounsAsks is Context {
    enum AskStatus {
        NONE,
        CREATED,
        APPROVED,
        CANCELED,
        ENDED
    }

    struct Ask {
        address owner;
        uint256 amount;
        uint256 pixelAmount;
        uint256 totalContributedToParty;
        uint256 nounId;
        AskStatus status;
    }

    event AskCreated(
        uint256 askId,
        address owner,
        uint256 nounId,
        uint256 amount,
        uint256 pixelAmount
    );

    event AskCanceled(uint256 askId);

    event NounSwapped(uint32 nounId, address owner, address treasury);

    event Contributed(
        address indexed contributor,
        uint256 askId,
        uint256 amount,
        uint256 remainingUnallocatedEth
    );

    event AskSettled(
        uint256 askId,
        address owner,
        uint256 nounId,
        uint256 amount,
        uint256 pixelAmount
    );

    using Counters for Counters.Counter;
    Counters.Counter private askIds;
    uint256 public lastApprovedAskId;

    mapping(uint256 => Ask) asks;

    // ask id -> address -> total contributed
    mapping(uint256 => mapping(address => uint256)) totalContributed;

    // ask id -> whether user has claimed yet
    mapping(uint256 => mapping(address => bool)) public claimed;

    // example: seller values noun at 597 eth and asks for 1 pixel. so 1 pixel == 0.597 eth, and 596.403 ETH remain unallocated. contributions must be in 0.001 PIXEL equivalent increments, so 0.000597 ETH increments in this case.
    uint256 constant PIXEL_PER_NOUN = 1000 * (10**18); // 1000 PIXEL are distributed for each galaxy sale
    uint256 constant SELLER_PIXEL_INCREMENT = 10**18; // seller can only ask for whole number of PIXEL and value galaxy in whole number of ETH
    uint256 constant SELLER_ETH_PER_PIXEL_INCREMENT = 10**15; // seller can only price 1 PIXEL in 0.001 ETH increments
    uint256 constant CONTRIBUTOR_PIXEL_INCREMENT = 10**15; // contributions must be valued in 0.001 PIXEL increments

    address public nouns;
    address public multisig;
    address public pixelToken;
    address public treasury;

    constructor(
        address _nouns,
        address _multisig,
        address _pixelToken,
        address _treasury
    ) {
        nouns = _nouns;
        multisig = _multisig;
        pixelToken = _pixelToken;
        treasury = _treasury;
        askIds.increment();
    }

    modifier onlyGovernance() {
        require(_msgSender() == treasury || _msgSender() == multisig);
        _;
    }

    function setNouns(address _nouns) public onlyGovernance {
        nouns = _nouns;
    }

    function setMultisig(address _multisig) public onlyGovernance {
        multisig = _multisig;
    }

    function setPixelToken(address _pixelToken) public onlyGovernance {
        pixelToken = _pixelToken;
    }

    function setTreasury(address _treasury) public onlyGovernance {
        treasury = _treasury;
    }

    function swapNoun(uint256 _nounId) public {
        require(
            IERC721(nouns).ownerOf(uint256(_nounId)) == _msgSender(),
            "caller must own the Noun"
        );
        IERC721(nouns).safeTransferFrom(
            _msgSender(),
            address(treasury),
            uint256(_nounId)
        );
        IERC20(pixelToken).transfer(_msgSender(), PIXEL_PER_NOUN);
        emit NounSwapped(_nounId, _msgSender(), address(treasury));
    }

    // noun owner lists noun for sale
    function createAsk(
        uint32 _nounId,
        uint256 _ethPerPixel, // eth value of 1*10**18 PIXEL, must be in 0.001 ETH increments
        uint256 _pixelAmount // PIXEL for seller, must be in 1 PIXEL increments
    ) public {
        require(
            IERC721(nouns).ownerOf(uint256(_nounId)) == _msgSender(),
            "caller must own the noun"
        );
        require(
            _pixelAmount < PIXEL_PER_NOUN,
            "_pixelAmount must be less than PIXEL_PER_NOUN"
        );
        require(
            _pixelAmount % SELLER_PIXEL_INCREMENT == 0,
            "seller can only ask for whole number of PIXEL"
        );
        require(_ethPerPixel > 0, "eth per pixel must be greater than 0");
        require(
            _ethPerPixel % SELLER_ETH_PER_PIXEL_INCREMENT == 0,
            "eth per pixel must be in 0.001 ETH increments"
        );

        uint256 _amount = ((PIXEL_PER_NOUN - _pixelAmount) / 10**18) *
            _ethPerPixel; // amount unallocated ETH
        address owner = _msgSender();
        uint256 askId = askIds.current();
        asks[askId] = Ask(
            owner,
            _amount,
            _pixelAmount,
            0,
            _nounId,
            AskStatus.CREATED
        );

        askIds.increment();
        emit AskCreated(askId, owner, _nounId, _amount, _pixelAmount);
    }

    function cancelAsk(uint256 _askId) public {
        require(
            asks[_askId].status == AskStatus.CREATED ||
                asks[_askId].status == AskStatus.APPROVED,
            "ask must be created or approved"
        );
        require(
            _msgSender() == treasury ||
                _msgSender() == multisig ||
                _msgSender() == asks[_askId].owner ||
                _msgSender() ==
                IERC721(nouns).ownerOf(uint256(asks[_askId].nounId))
        );
        asks[_askId].status = AskStatus.CANCELED;
        emit AskCanceled(_askId);
    }

    function approveAsk(uint256 _askId) public {
        require(
            asks[_askId].status == AskStatus.CREATED,
            "ask must be in created state"
        );
        require(
            asks[lastApprovedAskId].status == AskStatus.NONE ||
                asks[lastApprovedAskId].status == AskStatus.CANCELED ||
                asks[lastApprovedAskId].status == AskStatus.ENDED,
            "there is a previously approved ask that is not canceled/ended."
        );
        require(
            IERC20(pixelToken).balanceOf(address(this)) > PIXEL_PER_NOUN,
            "NounsAsks needs at least 1000 POINT to approve an ask"
        );
        asks[_askId].status = AskStatus.APPROVED;
        lastApprovedAskId = _askId;
    }

    function contribute(uint256 _askId, uint256 _pixelAmount) public payable {
        // if noun owner does not own the noun anymore, cancel ask and refund current contributor
        require(
            asks[_askId].status == AskStatus.APPROVED &&
                lastApprovedAskId == _askId,
            "ask must be in approved state"
        );
        if (
            asks[_askId].owner !=
            IERC721(nouns).ownerOf(uint256(asks[_askId].nounId))
        ) {
            asks[_askId].status = AskStatus.CANCELED;
            (bool success, ) = _msgSender().call{value: msg.value}("");
            require(success, "wallet failed to receive");
            return;
        }
        require(
            _pixelAmount > 0 && _pixelAmount % CONTRIBUTOR_PIXEL_INCREMENT == 0,
            "pixel amount must be greater than 0 and in increments of 0.001"
        );
        uint256 _ethPerPixel = asks[_askId].amount /
            (PIXEL_PER_NOUN - asks[_askId].pixelAmount);
        uint256 _amount = msg.value;
        require(
            _amount == _pixelAmount * _ethPerPixel,
            "msg.value needs to match pixelAmount"
        );
        require(
            _amount <=
                asks[_askId].amount - asks[_askId].totalContributedToParty,
            "cannot exceed asking price"
        );
        address _contributor = _msgSender();
        // add to contributor's total contribution
        totalContributed[_askId][_contributor] =
            totalContributed[_askId][_contributor] +
            _amount;
        // add to party's total contribution & emit event
        asks[_askId].totalContributedToParty =
            asks[_askId].totalContributedToParty +
            _amount;
        emit Contributed(
            _contributor,
            _askId,
            _amount,
            asks[_askId].amount - asks[_askId].totalContributedToParty
        );
        if (asks[_askId].totalContributedToParty == asks[_askId].amount) {
            settleAsk(_askId);
        }
    }

    function settleAsk(uint256 _askId) public {
        require(asks[_askId].status == AskStatus.APPROVED);
        require(asks[_askId].amount == asks[_askId].totalContributedToParty);
        asks[_askId].status = AskStatus.ENDED;
        IERC721(nouns).transferFrom(
            asks[_askId].owner,
            treasury,
            uint256(asks[_askId].nounId)
        );
        (bool success, ) = asks[_askId].owner.call{value: asks[_askId].amount}(
            ""
        );
        require(success, "wallet failed to receive");
        IERC20(pixelToken).transfer(
            asks[_askId].owner,
            asks[_askId].pixelAmount
        );
        emit AskSettled(
            _askId,
            asks[_askId].owner,
            asks[_askId].nounId,
            asks[_askId].amount,
            asks[_askId].pixelAmount
        );
    }

    function claim(uint256 _askId) public {
        require(
            asks[_askId].status == AskStatus.ENDED ||
                asks[_askId].status == AskStatus.CANCELED
        );
        require(totalContributed[_askId][_msgSender()] > 0);
        require(!claimed[_askId][_msgSender()]);
        claimed[_askId][_msgSender()] = true;
        if (asks[_askId].status == AskStatus.ENDED) {
            uint256 _pixelAmount = (totalContributed[_askId][_msgSender()] /
                asks[_askId].amount) *
                (PIXEL_PER_NOUN - asks[_askId].pixelAmount);
            IERC20(pixelToken).transfer(_msgSender(), _pixelAmount);
        } else if (asks[_askId].status == AskStatus.CANCELED) {
            uint256 _ethAmount = totalContributed[_askId][_msgSender()];
            (bool success, ) = _msgSender().call{value: _ethAmount}("");
            require(success, "wallet failed to receive");
        }
    }
}
