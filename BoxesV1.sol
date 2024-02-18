// SPDX-License-Identifier: MIT
//Kovan Testnet:0xa4b35FC534299fD7128b62f466b5eA3eC69bd153
//
pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/AccessControlEnumerable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/utils/SafeERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/math/SafeMath.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Address.sol";

interface BoxesToken{
    function  mint(address to, uint256 amount) external;
}

interface MonkeyNFT{
    function mintMonkey(address to,uint256 generation,uint256 mininggift,uint256 growthValue) external;
}

interface Strategy{
    function OpenBoxesStrategy(uint256 random,uint256 random2,uint256 random3) external pure  returns(uint256 generation,uint256 mininggift,uint256 growthValue);
}

contract BoxesV1 is AccessControlEnumerable{
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IERC20 public tokenToPay;
    IERC20 public tokenboxesToken;    
    BoxesToken public boxesToken;  
    MonkeyNFT public monkeyNFT; 
    Strategy public strategy; 
    address public _strategy;
    address public reservePool;
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant WITHDRAW_ROLE = keccak256("WITHDRAW_ROLE");
    bool public pause ;    
    uint256 public price;
    address public _tokenToPay;
    address public constant zero=0x6666666666666666666666666666666666666666;
    address public _boxesToken;
    address public _monkeyNFT;
    uint256 private randNonce = 0;
    uint256 private salt = 0;
    constructor() {
        price = 1;
        _tokenToPay = 0x5E8A819CCF47E3a83864c6c8cb6328cbe223093C;
        _boxesToken = 0x1FcB262dbD2Cc462091714517819448Ea754C5E8;
        _monkeyNFT = 0x72f9912E656f235543869521ed66dca7749aC0D8;
        _strategy = 0x1E2971956C8072600E67739a77fAa9664082963e;
        reservePool = 0x1A45fbe1E660f7cc998E696aD7f0309afe6F7E23;
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(PAUSER_ROLE, _msgSender());    
        _setupRole(WITHDRAW_ROLE, _msgSender());  
        tokenToPay=IERC20(_tokenToPay);
        boxesToken=BoxesToken(_boxesToken);
        tokenboxesToken=IERC20(_boxesToken);
        monkeyNFT=MonkeyNFT(_monkeyNFT);
        strategy=Strategy(_strategy);
    }
    
    
    function updatePause() external {
        require(hasRole(PAUSER_ROLE, _msgSender()), "BoxesV1: must have pauser role to pause");
        pause=!pause;       
    }
    
    function updatePrice(uint256 _toUpdatePrice) external {
        require(hasRole(PAUSER_ROLE, _msgSender()), "BoxesV1: must have pauser role to pause");
        price=_toUpdatePrice;       
    }
    // update OpenBoxes Strategy
    function updateStrategy(address _toUpdateSrategy) external {
        require(hasRole(PAUSER_ROLE, _msgSender()), "BoxesV1: must have pauser role to updateStrategy");
        _strategy=_toUpdateSrategy;       
    }
    //user buy boxes first    
    function buy(uint256 amount) external payable {
        require(!pause,"Paused!");
        require(!Address.isContract(msg.sender),"no allow call from contract!");
        uint256 amountToPay=price.mul(amount);
        tokenToPay.safeTransferFrom(msg.sender,reservePool,amountToPay);
        boxesToken.mint(msg.sender,amount);
    }
    //than user open boxes to get NFT Monkey    
    function openBox() public  {
        require(!pause,"Paused!");
        require(!Address.isContract(msg.sender),"no allow call from contract!");
        uint256 amountToPay=1;
        tokenboxesToken.safeTransferFrom(msg.sender,zero,amountToPay);
        (uint256 generation,uint256 mininggift,uint256 growthValue)=strategy.OpenBoxesStrategy(random(),random(),random());
        monkeyNFT.mintMonkey(msg.sender,generation,mininggift,growthValue);
    }

    
    function open5Boxes() external  {
        openBox();
        openBox();
        openBox();
        openBox();
        openBox();
    }    

    function random() internal returns (uint256){
        // 生成一个0到1 0000 0000的随机数:
        uint256 _random = uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender, randNonce))).mod(10000);
        randNonce++;
        _random = uint256(keccak256(abi.encodePacked(salt,_random, randNonce))).mod(100000000);
        salt = uint256(keccak256(abi.encodePacked(salt,msg.sender, randNonce))).mod(block.timestamp);
        randNonce++;
        return(_random);
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

}