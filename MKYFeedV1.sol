// SPDX-License-Identifier: MIT
//Kovan Testnet:0xd0DBd7a41986A5615cD9f319dCcde7E8d170a058
pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/AccessControlEnumerable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/utils/SafeERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/math/SafeMath.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Address.sol";

interface MonkeyNFT{
   function getMonkeyData(uint256 tokenId) external view  returns (uint256 generation,uint256 mininggift,uint256 growthValue,uint256 createtime,uint256 appearance);
   function totalSupply() external view returns (uint256);
   function ownerOf(uint256 tokenId) external view returns (address owner);

}

interface Strategy{
    function MKTFeedGetScore(uint256 value,uint256 generation,uint256 mininggift ,uint256 growthValue) pure external returns (uint256 score);
   
}



contract MKYFeedV1 is AccessControlEnumerable{
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    Strategy public strategy;    
    IERC20 public monkeyToken;
    MonkeyNFT public monkeyNFT;
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant WITHDRAW_ROLE = keccak256("WITHDRAW_ROLE");
    bool public pause ;  
    bool public feedPause ;  
    bool public rewardPause;  
    address public _strategy;
    address public _monkeyNFT;
    address public _monkeyToken;
    uint256 public dailyMKYRewardLimit;
    uint256 public price;



    event MKYFEED(uint256 tokenId,uint256 value,uint256 userScoreAdd,address msgSender,address nftOwner);
    struct userScoreStruct {
        uint256 timestamp;
        uint256 totalScore;
        mapping (address => uint256) userScore;//瓜分MKY
        mapping (uint256 => uint256) feedtimes;   
        mapping (address => bool) userClaimStatus;
    }
    
    mapping (uint256 => userScoreStruct) userScoreMapping;
    
    constructor() {
        price = 100000000000000;
        dailyMKYRewardLimit = 1500000000000000000;
        _monkeyNFT = 0x72f9912E656f235543869521ed66dca7749aC0D8;
        _monkeyToken = 0x5243a416BF3EccAFA1A560F0C8A5E748EE4ED730;
        _strategy = 0xe15eb4256895D903893c2FA448c7A0E05A07c005;
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(PAUSER_ROLE, _msgSender());    
        _setupRole(WITHDRAW_ROLE, _msgSender());  
        monkeyNFT=MonkeyNFT(_monkeyNFT);
        monkeyToken=IERC20(_monkeyToken);
        strategy=Strategy(_strategy);
    }
     
    function updatedailyMKYRewardLimit(uint256 _toUpdatedailyMKYRewardLimit) external {
        require(hasRole(PAUSER_ROLE, _msgSender()), "MKYFeedV1: must have pauser role to pause");
        dailyMKYRewardLimit=_toUpdatedailyMKYRewardLimit;       
    }
    

    function updateStrategy(address _toUpdateSrategy) external {
        require(hasRole(PAUSER_ROLE, _msgSender()), "MKYFeedV1: must have pauser role to updateStrategy");
        _strategy=_toUpdateSrategy;       
    }
    
    function updatePause() external {
        require(hasRole(PAUSER_ROLE, _msgSender()), "MKYFeedV1: must have pauser role to pause");
        pause=!pause;       
    }
    
    function updateFeedPause() external {
        require(hasRole(PAUSER_ROLE, _msgSender()), "MKYFeedV1: must have pauser role to pause");
        feedPause=!feedPause;       
    }

    function updateRewardPause() external {
        require(hasRole(PAUSER_ROLE, _msgSender()), "MKYFeedV1: must have pauser role to pause");
        rewardPause=!rewardPause;       
    }




    function feed(uint256 tokenId,uint256 value) public{
        require(!pause,"Paused!");
        require(!feedPause,"Paused!");
        require(!Address.isContract(msg.sender),"no allow call from contract!");
        require(monkeyNFT.totalSupply()>tokenId, "no this tokenId");
        require(getFeedtimes(tokenId)+value<=1,"exceed daily max feedtimes");
        uint256 amountToPay=price.mul(value);
        monkeyToken.safeTransferFrom(msg.sender,address(this),amountToPay);
        _feed(tokenId,value);
        
    }

    function feeds(uint256[] memory ids,uint256 value) external{
        for (uint256 i = 0; i < ids.length; ++i) {
            feed(ids[i],value);
        }
        
    }
    
    function _feed(uint256 tokenId,uint256 value) internal {
        require(!pause,"Paused!");
        require(!Address.isContract(msg.sender),"no allow call from contract!");
        userScoreStruct storage s = userScoreMapping[today()];
        require(monkeyNFT.totalSupply()>tokenId, "no this tokenId");
        
        require(getFeedtimes(tokenId)+value<=1);
        s.feedtimes[tokenId]=s.feedtimes[tokenId]+value;
        
        (uint256 generation,uint256 mininggift,uint256 growthValue,,)=monkeyNFT.getMonkeyData(tokenId);
        address nftOwner=monkeyNFT.ownerOf(tokenId);

        //userScore瓜分MKY
        uint256 userScoreAdd ;
        userScoreAdd=strategy.MKTFeedGetScore(value.mul(price), generation, mininggift ,growthValue);
        
        s.totalScore=s.totalScore.add(userScoreAdd);
        s.userScore[nftOwner]=s.userScore[nftOwner].add(userScoreAdd);

        MKYFEED(tokenId,value,userScoreAdd,msg.sender,nftOwner);         
        //Event!!!

    }
    
    //1 Score = 1 MonkeyToken
    function getUserScore(address userAddress,uint256 day) external view returns (uint256 userScore,bool userClaimStatus){
        userScoreStruct storage s = userScoreMapping[day];
        userScore=s.userScore[userAddress];
        userClaimStatus=s.userClaimStatus[userAddress];
    }
    
    function getTotalScore(uint256 day) external view returns(uint256 totalScore){
        userScoreStruct storage s = userScoreMapping[day];
        totalScore=s.totalScore;
    }    
    

   //1 Score = 1 MonkeyToken
    function claimable(address userAddress) view external returns (uint256 MKYReward){

        userScoreStruct storage s = userScoreMapping[today()-1];
        if(s.userClaimStatus[userAddress]){
            return (0);
        }
        return (s.userScore[userAddress]);
    }        

    
  
    function claimReward() public{

        require(!pause,"Paused!");
        require(!rewardPause,"Paused!");
        userScoreStruct storage s = userScoreMapping[today()-1];

        require(!s.userClaimStatus[msg.sender],"User have claim yesterday reward");
        s.userClaimStatus[msg.sender]=true;
        monkeyToken.safeTransfer(msg.sender,s.userScore[msg.sender]);
    } 
    
    function claimOldReward(uint256 day) public{

        require(!pause,"Paused!");
        require(!rewardPause,"Paused!");
        require(day<today());
        require(day>0);        
        userScoreStruct storage s = userScoreMapping[day];

        require(!s.userClaimStatus[msg.sender],"User have claim that day reward");
        s.userClaimStatus[msg.sender]=true;
        monkeyToken.safeTransfer(msg.sender,s.userScore[msg.sender]);
    } 

      
    
    function getFeedtimes(uint256 tokenId) public view returns(uint256){
        require(monkeyNFT.totalSupply()>tokenId, "no this tokenId");
        userScoreStruct storage s = userScoreMapping[today()];
        return s.feedtimes[tokenId];
    }



    
 //only used emergency   
    function withdraw(address tokenaddress,address to) public {
        require(hasRole(WITHDRAW_ROLE, _msgSender()), "BoxesV1: must have withdraw role to withdraw");        
        IERC20(tokenaddress).transfer(to,IERC20(tokenaddress).balanceOf(address(this)));
    }
  //only used emergency      
    function withdrawETH(address to) public {
        require(hasRole(WITHDRAW_ROLE, _msgSender()), "BoxesV1: must have withdraw role to withdraw");        
        (bool success, ) = to.call{value: address(this).balance}("");
    }


   //only used for test!!        
    uint256 public forTestT3;
    function today() public view returns(uint256){
           uint256 t1=block.timestamp.sub(1616169600);
           uint256 t2=uint256(t1.div(86400))+forTestT3;
           return(t2);
    }
    
  //only used for test!!  
    function addTodayForTest() public {
        require(hasRole(WITHDRAW_ROLE, _msgSender()), "BoxesV1: must have withdraw role to Test!");       
        forTestT3=forTestT3+1;
    }

   //Used in formal runtime,and replace abpve 2 test function!
    // function today() public view returns(uint256){
    //       uint256 t1=block.timestamp.sub(1616169600);
    //       uint256 t2=uint256(t1.div(86400));
    //       return(t2);
    // }
    
    
}