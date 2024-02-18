// SPDX-License-Identifier: MIT
//Kovan : 0x3Fe19453b60fB3aaDDb04bbA3FFC4F0D18387AEA
pragma solidity ^0.8.0;
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/math/SafeMath.sol";
contract Strategy {
    using SafeMath for uint256;
    constructor(){}
    
    function OpenBoxesStrategy(uint256 random,uint256 random2,uint256 random3) public pure returns(uint256 generation,uint256 mininggift,uint256 growthValue){
        uint256 random1 =random.mod(2000);//0-1999
        if(random1>1998){   //  1/2000
            generation=0;
        }else if(random1>1988){  //  1/200
            generation=1;
        }else if(random1>1908){   //   1/25
            generation=2;
        }else if(random1>1508){   //  1/5
            generation=3;
        }else{
            generation=4;      //others
        } 
        
        //100-199
        mininggift=random2.mod(100)+100; //100-199
        
         //100-199
        growthValue=random3.mod(100)+100; //100-199       
    }
    
    function FeedStrategy(uint256 random0) public pure returns(uint256 feedmul,uint256 mininggiftGrowth,uint256 weightGrowth){
        uint256 random1 =random0.div(1000000);
        if(random1>80){
            feedmul=20;
        }else if(random1>60){
            feedmul=5;
        }else{
            feedmul=10;//60%
        }
        
        mininggiftGrowth = 0;
        weightGrowth = 0;
        uint256 random2 =random0.mod(100);
        if(random2>90){
           mininggiftGrowth =10;
        }else if(random2>80){
          weightGrowth =10;
        }       
    }
    
    
    function getScore(uint256 base, uint256 generation, uint256 mininggift ,uint256 growthValue) public pure returns(uint256 feedScore,uint256 miningScore){
            uint256 generationRatio;
            if(generation==0){
                generationRatio=130;
            }else if(generation==1){
                generationRatio=169;                
            }else if(generation==2){
                generationRatio=220;                   
            }else if(generation==3){
                generationRatio=286;                   
            }else if(generation==4){
                generationRatio=371;                   
            }
            feedScore = base.mul(mininggift).div(generationRatio);
            miningScore = base.mul(mininggift).mul(generationRatio);
    }
    
    function MKTFeedGetScore(uint256 value,uint256 generation,uint256 mininggift ,uint256 growthValue) pure external returns (uint256 score){
        return value.mul(105).div(100);
    }
    
}