// SPDX-License-Identifier: MIT
//Kovan Testnet:0xb29F82BB2C7a04127f6D7023BcBE0002d77e51Bb
pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/IERC721.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/AccessControlEnumerable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/utils/SafeERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/math/SafeMath.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Address.sol";

interface MonkeyNFT{
   function getMonkeyData(uint256 tokenId) external view  returns (uint256 generation,uint256 mininggift,uint256 growthValue,uint256 createtime,uint256 appearance);
   function updateMonkeyData(uint256 tokenId,uint256 dataId,uint256 dataValue) external;
   function totalSupply() external view returns (uint256);
   function ownerOf(uint256 tokenId) external view returns (address owner);
   function getGeneration(uint256 tokenId) external view  returns (uint256);
   function isApprovedForAll(address owner, address operator) external view returns (bool);
   function transferFrom(address from, address to, uint256 tokenId) external;

}

contract Market is AccessControlEnumerable{
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant WITHDRAW_ROLE = keccak256("WITHDRAW_ROLE");  
    IERC20 public tokenToPay;
    MonkeyNFT public monkeyNFT;
    bool public pause = false;  
    address public _tokenToPay;
    address public _monkeyNFT;
    uint256 public orderID=0;
    uint256 fee =5;
    
    constructor() {

        _tokenToPay = 0x5E8A819CCF47E3a83864c6c8cb6328cbe223093C;
        _monkeyNFT = 0x72f9912E656f235543869521ed66dca7749aC0D8;

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(PAUSER_ROLE, _msgSender());    
        _setupRole(WITHDRAW_ROLE, _msgSender());  
        tokenToPay=IERC20(_tokenToPay);
        monkeyNFT=MonkeyNFT(_monkeyNFT);
    }   
   
    struct orderInfo{
        address seller;
        uint256 tokenId;
        uint256 price;
        bool haveBroughtOrCancel;
    }

    mapping(uint256 => orderInfo) orderInfoMapping;
    
    function placeOrder(uint256 tokenId,uint256 price) public{
        require(!pause,"Paused!");
        address nftOwner=monkeyNFT.ownerOf(tokenId);
        require(nftOwner==msg.sender,"not NFTOwner");
        bool approveStatus = monkeyNFT.isApprovedForAll(nftOwner,address(this));
        require(approveStatus==true,"ApprovedForAll First");
        orderInfo storage oi = orderInfoMapping[orderID++];
        oi.seller = msg.sender;
        oi.tokenId=tokenId;
        oi.price=price;
    }
    
    function placeOrders(uint256[] memory tokenIds,uint256[] memory prices) public {
        for (uint256 i = 0; i < tokenIds.length; ++i) {
            placeOrder(tokenIds[i],prices[i]);
        }        
    }
    
    function buy(uint256 orderId) public {
        require(!pause,"Paused!");
        orderInfo storage oi = orderInfoMapping[orderId];
        require(!oi.haveBroughtOrCancel,"have brought or cancel");
        uint256 tokenId=oi.tokenId;
        address nftOwner=monkeyNFT.ownerOf(tokenId);
        require(nftOwner==oi.seller,"seller not NFTOwner");
        bool approveStatus = monkeyNFT.isApprovedForAll(nftOwner,address(this));
        require(approveStatus==true,"seller not ApprovedForAll");
        uint256 price=oi.price;
        oi.haveBroughtOrCancel=true;
        tokenToPay.safeTransferFrom(msg.sender,address(this),price);
        tokenToPay.safeTransfer(oi.seller,price.mul(100-fee).div(100));    //交易手续费！！！   
        monkeyNFT.transferFrom(oi.seller,msg.sender,tokenId);
    }

    function buys(uint256[] memory  orderIDs) public {
         for (uint256 i = 0; i < orderIDs.length; ++i) {
            buy(orderIDs[i]); 
        }               
    }
   
    function cancel(uint256 orderId) public {
        require(!pause,"Paused!");
        orderInfo storage oi = orderInfoMapping[orderId];
        require(!oi.haveBroughtOrCancel,"have brought or cancel");
        uint256 tokenId=oi.tokenId;
        address nftOwner=monkeyNFT.ownerOf(tokenId);
        require(nftOwner==oi.seller,"seller not NFTOwner");
        oi.haveBroughtOrCancel=true;
    }
     
    function cancels(uint256[] memory  orderIDs) public {
         for (uint256 i = 0; i < orderIDs.length; ++i) {
            cancel(orderIDs[i]); 
        }               
    }   
    
    function marketDetail() view public returns(uint256[] memory){
        require(!pause,"Paused!");
        uint256 ii=0;
        uint256[] memory availableOrderIDs=new uint256[](orderID);
        for (uint256 i = 0; i < orderID; ++i){//orderID=实际订单数量，因为orderID++了
            orderInfo storage oi = orderInfoMapping[i];
            address nftOwner =monkeyNFT.ownerOf(oi.tokenId);
            if((!oi.haveBroughtOrCancel&&nftOwner==oi.seller&& monkeyNFT.isApprovedForAll(nftOwner,address(this)))){
                availableOrderIDs[ii++]=i;
            }
        }
        uint256[] memory availableOrderIDsForReturn=new uint256[](ii);
        for (uint256 i = 0; i < ii; ++i){        
            availableOrderIDsForReturn[i]=availableOrderIDs[i];
        }
        return availableOrderIDsForReturn;
    }
    
    function orderDetail(uint256 orderId) view public returns(address seller,uint256 tokenId,uint256 price ,bool haveBroughtOrCancel){
        require(!pause,"Paused!");
        orderInfo storage oi = orderInfoMapping[orderId];
        seller=oi.seller;
        tokenId=oi.tokenId;
        price=oi.price;
        haveBroughtOrCancel=oi.haveBroughtOrCancel;
        
    }
       
    function setfees(uint256 fees) public {
        require(hasRole(WITHDRAW_ROLE, _msgSender()), "BoxesV1: must have withdraw role to withdraw");     
        fee =fees;
    }
    
    function withdraw(address tokenaddress,address to) public {
        require(hasRole(WITHDRAW_ROLE, _msgSender()), "BoxesV1: must have withdraw role to withdraw");        
        IERC20(tokenaddress).transfer(to,IERC20(tokenaddress).balanceOf(address(this)));
    }
    
    function withdrawETH(address to) public {
        require(hasRole(WITHDRAW_ROLE, _msgSender()), "BoxesV1: must have withdraw role to withdraw");        
        (bool success, ) = to.call{value: address(this).balance}("");
    }
 
}

