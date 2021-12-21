//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "./interfaces/IERC721.sol";

/// @title A P2P NFT trading contract
/// @author @fbsloXBT
/// @notice Use this contract to swap between 2 NFTs

contract SwapNFTs {
  /// @notice Current trade ID (latest trade id = id - 1)
  uint256 public id;
  /// @notice Trade expiration in blocks
  uint256 public expirationLimit;

  /// @notice Fee in ETH required to use this contract as a buyer
  uint256 public fee;
  /// @notice Address that can withdraw collected authorization fees
  address public admin;

  /// @notice Struct to store details about each trade
  struct Trade {
    address buyer; // address proposing the trade
    address seller; //address accepting the trade
    address collection_1; //buyer's NFT address
    address collection_2; //seller's NFT address
    uint256 id_1; //buyer's NFT id
    uint256 id_2; //seller's NFT id
    bool executed;
    uint256 expiration;
    bool feesReclaimed;
  }
  /// @notice Mapping to connect id to trade details
  mapping (uint256 => Trade) public trades;

  /// @notice Emitted when trade is proposed
  event TradeProposed(uint256 id);
  /// @notice Emitted when trade is executed
  event TradeExecuted(uint256 id);

  /// @notice Mapping to allow function to be called only by admin
  modifier onlyAdmin(){
    require(msg.sender == admin, 'Not admin');
    _;
  }

  /// @notice Construct a new P2P NFT trading contract
  constructor(){
    id = 0;
    expirationLimit = 86400; //14 days @ 14s block time
    authorizationFee = 0.005 ether;
    admin = msg.sender;
  }

  /**
   * @notice Propose new P2P trade, can be called by buyer
   * @param buyer Address proposing the trade
   * @param seller Address to whom trade is proposed
   * @param collection_1 Address of buyer's NFT
   * @param collection_2 Address of sellers's NFT
   * @param id_1 ID of buyer's NFT
   * @param id_1 ID of buyer's NFT
   */
  function proposeTrade(
    address buyer,
    address seller,
    address collection_1,
    address collection_2,
    uint256 id_1,
    uint256 id_2
  ) external payable {
    require(msg.sender == buyer, 'Not a buyer');
    require(msg.value >= fee, "fee not paid");

    trades[id] = Trade(
      buyer,
      seller,
      collection_1,
      collection_2,
      id_1,
      id_2,
      false,
      block.number + expirationLimit,
      false
    );
    emit TradeProposed(id);

    id++;
  }

  /**
   * @notice Execute already proposed P2P trade, can be called by seller
   * @param id_ ID of the proposed trade
   */
  function executeTrade(uint256 id_) external {
    require(msg.sender == trades[id_].seller, 'Not a seller');
    require(trades[id_].expiration >= block.number, 'Expired');
    require(!trades[id_].executed, 'Already executed');

    //send buyer's NFT to seller
    IERC721(trades[id_].collection_1).transferFrom(trades[id_].buyer, trades[id_].seller, trades[id_].id_1);
    //send seller's NFT to buyer
    IERC721(trades[id_].collection_2).transferFrom(trades[id_].seller, trades[id_].buyer, trades[id_].id_2);

    address owner_1_after = IERC721(trades[id_].collection_1).ownerOf(trades[id_].id_1);
    address owner_2_after = IERC721(trades[id_].collection_2).ownerOf(trades[id_].id_2);

    require(owner_1_after == trades[id_].seller, "Transfer failed");
    require(owner_2_after == trades[id_].buyer, "Transfer failed");

    trades[id_].executed = true;
    (bool sent,) = admin.call{value:fee}("");

    //revoke approvals
    IERC721(trades[id_].collection_1).approve(address(0), trades[id_].id_1)
    IERC721(trades[id_].collection_2).approve(address(0), trades[id_].id_2)

    emit TradeExecuted(id_);
  }

  /**
   * @notice Cancel trade by setting expiration in the past
   * @param id_ ID of the proposed trade
   */
  function cancelProposedTrade(uint256 id_) external {
    require(!trades[id_].executed, "Already executed");
    require(msg.sender == trades[id_].buyer, "Only buyer");
    //set expriation in the past
    trades[id_].expiration = block.number - 1;
  }

  /**
   * @notice Reclaim fees from expired trades
   */
  function reclaimFees(uint256[] memory ids) external payable {
    for (uint256 i = 0; i < ids.length; i++){
      if (block.number > trades[ids[i]].expiration && !trades[ids[i]].executed && !trades[ids[i]].feesReclaimed){
        trades[ids[i]].feesReclaimed = true;
        (bool sent,) = trades[ids[i]].buyer.call{value:fee}("");
      }
    }
  }

  /**
   * @notice View function to get trade details
   * @param id_ ID of the trade
   */
  function getProposedTrade(uint256 id_) external view returns(Trade memory _trade) {
    return trades[id_];
  }

  /**
   * @notice Governance function to withdraw collected fees
   */
  function transferOut() external onlyAdmin {
    (bool sent,) = admin.call{value: address(this).balance}("");
    require(sent, "Failed to send ETH");
  }

  /**
   * @notice Change admin address
   * @param newAdmin Address of the new admin
   */
  function setAdmin(address newAdmin) external onlyAdmin {
    admin = newAdmin;
  }
}
