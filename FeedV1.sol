// SPDX-License-Identifier: MIT
//Kovan Testnet:0xE2aED1f147a1f9FcF238288cE2D43Fa36719f7D1
pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/AccessControlEnumerable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/utils/SafeERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/math/SafeMath.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Address.sol";

interface MonkeyNFT{
   function mintMonkey(address to,uint256 generation,uint256 mininggift,uint256 growthValue) external;
   function getMonkeyData(uint256 tokenId) external view  returns (uint256 generation,uint256 mininggift,uint256 growthValue,uint256 createtime,uint256 appearance);
   function updateMonkeyData(uint256 tokenId,uint256 dataId,uint256 dataValue) external;
   function totalSupply() external view returns (uint256);
   function ownerOf(uint256 tokenId) external view returns (address owner);

}

interface Strategy{
    function FeedStrategy(uint256 random0) external pure returns(uint256 feedmul,uint256 mininggiftGrowth,uint256 weightGrowth);
    function getScore(uint256 base, uint256 generation, uint256 mininggift ,uint256 growthValue) external pure returns(uint256 feedScore,uint256 miningScore);
    
}



contract FeedV1 is AccessControlEnumerable{
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    Strategy public strategy;    
    IERC20 public tokenToPay;
    IERC20 public monkeyToken;
    MonkeyNFT public monkeyNFT;
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant WITHDRAW_ROLE = keccak256("WITHDRAW_ROLE");
    bool public pause ;  
    bool public feedPause ;  
    bool public rewardPause;  
    address public _tokenToPay;
    address public _strategy;
    address public _monkeyNFT;
    address public _monkeyToken;
    uint256 private randNonce = 0;
    uint256 private salt = 0;
    uint256 public dailyMKYReward;

    uint256 public price;

    uint256 public MKYRewardAmountDaily;


    event FEED(uint256 tokenId,uint256 value,uint256 feedmul,uint256 mininggiftGrowth,uint256 growthValueGrowth,uint256 weightScoreAdd,uint256 miningScoreAdd,address msgsender,address nftOwner);     

    struct userScore {
        uint256 timestamp;
        uint256 totalFeedScore;
        uint256 totalMiningScore;
        uint256 FeedRewardPerScore;
        uint256 MKYRewardPerToken;
        mapping (address => uint256) userFeedScore;//瓜分食物tokenToPay
        mapping (address => uint256) userMiningScore;//瓜分MKY
        mapping (uint256 => uint256) weight;
        mapping (uint256 => uint256) feedtimes;   
        mapping (address => bool) userClaimStatus;
    }
    
    mapping (uint256 => userScore) userScoreMapping;
    
    constructor() {
        price = 100000000000000;
        MKYRewardAmountDaily = 1500000000000000000;
        _tokenToPay = 0x5E8A819CCF47E3a83864c6c8cb6328cbe223093C;
        _monkeyNFT = 0x72f9912E656f235543869521ed66dca7749aC0D8;
        _monkeyToken = 0x5243a416BF3EccAFA1A560F0C8A5E748EE4ED730;
        _strategy = 0x3Fe19453b60fB3aaDDb04bbA3FFC4F0D18387AEA;
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(PAUSER_ROLE, _msgSender());    
        _setupRole(WITHDRAW_ROLE, _msgSender());  
        tokenToPay=IERC20(_tokenToPay);
        monkeyNFT=MonkeyNFT(_monkeyNFT);
        monkeyToken=IERC20(_monkeyToken);
        strategy=Strategy(_strategy);
    }
     
    function updatedailyMKYReward(uint256 _toUpdatedailyMKYReward) external {
        require(hasRole(PAUSER_ROLE, _msgSender()), "BoxesV1: must have pauser role to pause");
        dailyMKYReward=_toUpdatedailyMKYReward;       
    }
    
    function updatePrice(uint256 _toUpdatePrice) external {
        require(hasRole(PAUSER_ROLE, _msgSender()), "BoxesV1: must have pauser role to pause");
        price=_toUpdatePrice;       
    }    

    function updateStrategy(address _toUpdateSrategy) external {
        require(hasRole(PAUSER_ROLE, _msgSender()), "BoxesV1: must have pauser role to updateStrategy");
        _strategy=_toUpdateSrategy;       
    }
    
    function updatePause() external {
        require(hasRole(PAUSER_ROLE, _msgSender()), "FeedV1: must have pauser role to pause");
        pause=!pause;       
    }
    
    function updateFeedPause() external {
        require(hasRole(PAUSER_ROLE, _msgSender()), "FeedV1: must have pauser role to pause");
        feedPause=!feedPause;       
    }

    function updateRewardPause() external {
        require(hasRole(PAUSER_ROLE, _msgSender()), "FeedV1: must have pauser role to pause");
        rewardPause=!rewardPause;       
    }




    function feed(uint256 tokenId,uint256 value) public{
        require(!pause,"Paused!");
        require(!feedPause,"Paused!");
        require(!Address.isContract(msg.sender),"no allow call from contract!");
        require(monkeyNFT.totalSupply()>tokenId, "no this tokenId");
        require(getFeedtimes(tokenId)+value<=5,"exceed daily max feedtimes");
        uint256 amountToPay=price.mul(value);
        tokenToPay.safeTransferFrom(msg.sender,address(this),amountToPay);
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
        userScore storage s = userScoreMapping[today()];
        require(monkeyNFT.totalSupply()>tokenId, "no this tokenId");
        require(getFeedtimes(tokenId)+value<=5);
        s.feedtimes[tokenId]=s.feedtimes[tokenId]+value;
        
        
        (uint256 feedmul,uint256 mininggiftGrowth,uint256 growthValueGrowth)=strategy.FeedStrategy(random());
        
        uint256 oldweight = s.weight[tokenId];
        (uint256 generation,uint256 mininggift,uint256 growthValue,,)=monkeyNFT.getMonkeyData(tokenId);
        if(mininggiftGrowth!=0){
            monkeyNFT.updateMonkeyData(tokenId,0,mininggiftGrowth.mul(value)+mininggift);
        }
        if(growthValueGrowth!=0){
            monkeyNFT.updateMonkeyData(tokenId,1,growthValueGrowth.mul(value)+growthValue);            
        }
        
        s.weight[tokenId]=oldweight.add(feedmul.mul(value));
        
        address nftOwner=monkeyNFT.ownerOf(tokenId);

        //FeedScore瓜分食物tokenToPay
        uint256 userFeedScoreAdd ;
        
        //miningScore瓜分MKY
        uint256 userminingScoreAdd ;
        (userFeedScoreAdd,userminingScoreAdd)=strategy.getScore(feedmul.mul(value), generation, mininggift ,growthValue);
        
        s.totalFeedScore=s.totalFeedScore.add(userFeedScoreAdd);
        s.userFeedScore[nftOwner]=s.userFeedScore[nftOwner].add(userFeedScoreAdd);

        s.totalMiningScore=s.totalMiningScore.add(userminingScoreAdd);
        s.userMiningScore[nftOwner]=s.userMiningScore[nftOwner].add(userminingScoreAdd);
        
        FEED(tokenId,value,feedmul,mininggiftGrowth,growthValueGrowth,userFeedScoreAdd,userminingScoreAdd,msg.sender,nftOwner);         
        //Event!!!
        
        s.FeedRewardPerScore = tokenToPay.balanceOf(address(this)).div(s.totalFeedScore);
        s.MKYRewardPerToken = dailyMKYReward.div(s.totalMiningScore);
    }
    

    
   
    
    function getTokenIDWeight(uint256 tokenId,uint256 day) external view returns (uint256 weight,uint256 feedtimes){
        userScore storage s = userScoreMapping[day];
        weight=s.weight[tokenId];
        feedtimes=s.feedtimes[tokenId];        
    }
    
    function getUserScore(address userAddress,uint256 day) external view returns (uint256 userFeedScore,uint256 userMiningScore,bool userClaimStatus){
        userScore storage s = userScoreMapping[day];
        userFeedScore=s.userFeedScore[userAddress];
        userMiningScore=s.userMiningScore[userAddress];       
        userClaimStatus=s.userClaimStatus[userAddress];
    }
    
    function getTotalScore(uint256 day) external view returns(uint256 totalFeedScore, uint256 totalMiningScore, uint256 FeedRewardPerScore,uint256 MKYRewardPerToken){
        userScore storage s = userScoreMapping[day];
        totalFeedScore=s.totalFeedScore;
        totalMiningScore=s.totalMiningScore;
        FeedRewardPerScore=s.FeedRewardPerScore;
        MKYRewardPerToken=s.MKYRewardPerToken;
    }    
    
 //only used emergency   
    function recountDailyReward(uint256 updateTotalFeedReward,uint256 updateTotalMiningReward) public {
        require(hasRole(WITHDRAW_ROLE, _msgSender()), "BoxesV1: must have withdraw role to withdraw");        
        require(!pause,"Paused!");

        userScore storage s = userScoreMapping[today()-1];
        
        s.FeedRewardPerScore = updateTotalFeedReward.div(s.totalFeedScore);
        s.MKYRewardPerToken = updateTotalMiningReward.div(s.totalMiningScore);

    }


    function claimable(address userAddress) view external returns (uint256 FeedReward,uint256 MKYReward){

        require(!pause,"Paused!");
        require(!rewardPause,"Paused!");
        userScore storage s = userScoreMapping[today()-1];
        if(s.userClaimStatus[userAddress]){
            return (0,0);
        }
        return (s.FeedRewardPerScore.mul(s.userFeedScore[userAddress]),s.MKYRewardPerToken.mul(s.userMiningScore[userAddress]));
    }        

    
  
    function claimReward() public{

        require(!pause,"Paused!");
        require(!rewardPause,"Paused!");
        userScore storage s = userScoreMapping[today()-1];

        require(!s.userClaimStatus[msg.sender],"User have claim yesterday reward");
        s.userClaimStatus[msg.sender]=true;
        tokenToPay.safeTransfer(msg.sender,s.FeedRewardPerScore.mul(s.userFeedScore[msg.sender]));
        monkeyToken.safeTransfer(msg.sender,s.MKYRewardPerToken.mul(s.userMiningScore[msg.sender]));
    } 
    
    function claimOldReward(uint256 day) public{

        require(!pause,"Paused!");
        require(!rewardPause,"Paused!");
        require(day<today());
        require(day>0);        
        userScore storage s = userScoreMapping[day];

        require(!s.userClaimStatus[msg.sender],"User have claim that day reward");
        s.userClaimStatus[msg.sender]=true;
        tokenToPay.safeTransfer(msg.sender,s.FeedRewardPerScore.mul(s.userFeedScore[msg.sender]));
        monkeyToken.safeTransfer(msg.sender,s.MKYRewardPerToken.mul(s.userMiningScore[msg.sender]));
    }     
      
    
    function getFeedtimes(uint256 tokenId) public view returns(uint256){
        require(monkeyNFT.totalSupply()>tokenId, "no this tokenId");
        userScore storage s = userScoreMapping[today()];
        return s.feedtimes[tokenId];
    }



    
    
    //get random number
    function random() internal returns (uint256){
        // 生成一个0到1 0000 0000的随机数:
        uint256 random0 = uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender, randNonce))).mod(10000);
        randNonce++;
        random0 = uint256(keccak256(abi.encodePacked(salt,random0, randNonce))).mod(100000000);
        salt = uint256(keccak256(abi.encodePacked(salt,msg.sender, randNonce))).mod(block.timestamp);
        randNonce++;
        return(random0);
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