// SPDX-License-Identifier: MIT
//Kovan Testnet:0x72f9912E656f235543869521ed66dca7749aC0D8
//

pragma solidity ^0.8.0;


import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/presets/ERC721PresetMinterPauserAutoId.sol";

contract MonkeyNFT is ERC721PresetMinterPauserAutoId {

    string private _baseTokenURI; 
    
    constructor(string memory name, string memory symbol, string memory baseTokenURI) ERC721PresetMinterPauserAutoId( name, symbol, baseTokenURI) {
        _baseTokenURI = baseTokenURI;  
        
    }
    
    struct NFTdata {
        uint256 _createtime;
        uint256 _generation;
        uint256 _growthValue;
        uint256 _mininggift;
        mapping (uint256 => uint256) appearance;
        mapping (uint256 => uint256) moredatauint;
        mapping (uint256 => string) moredatastring;
        mapping (uint256 => address) moredataaddress;       
    }
    mapping (uint256 => NFTdata) nftdata;
    
    function changeURI(string memory baseTokenURI) external {
        _baseTokenURI = baseTokenURI;
    }
    
    
    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }
    
    //Required parameters for current version
    function mintMonkey(address to,uint256 generation,uint256 mininggift,uint256 growthValue) external {
        require(hasRole(MINTER_ROLE, _msgSender()), "ERC721PresetMinterPauserAutoId: must have minter role to mint");
        uint256 tokenId=totalSupply();
        NFTdata storage s = nftdata[tokenId];
        s._generation = generation;
        s._mininggift = mininggift;
        s._growthValue = growthValue;
        s._createtime = block.timestamp;
        s.appearance[0]=uint256(keccak256(abi.encodePacked(block.timestamp, generation, tokenId)));
        mint(to);
    }

    //Required parameters for current version
    function getMonkeyData(uint256 tokenId) external view  returns (uint256 generation,uint256 mininggift,uint256 growthValue,uint256 createtime,uint256 appearance) {
        require(_exists(tokenId), "ERC721: query for nonexistent token");
        NFTdata storage s = nftdata[tokenId];
        return (s._generation,s._mininggift,s._growthValue,s._createtime,s.appearance[0]);
  
    }    
    
    //Reserved for expansion
    function getMonkeyMoreUint(uint256 tokenId,uint256 dataId,uint256 num)  external view returns(uint256 dataValue){
        NFTdata storage s = nftdata[tokenId];
        if(dataId==0){
            dataValue=s.appearance[num] ;

        }
        
        if(dataId==1){
            dataValue=s.moredatauint[num] ;

        }
    }
    
    //dataId Reserved for expansion
    function getMonkeyDataMoreString(uint256 tokenId,uint256 dataId,uint256 num)  external view returns(string memory dataValue){
        NFTdata storage s = nftdata[tokenId];
            dataValue= s.moredatastring[num] ;
    }
 
     //dataId Reserved for expansion   
    function getMonkeyDataMoreAddress(uint256 tokenId,uint256 dataId,uint256 num)  external view returns(address dataValue){
        NFTdata storage s = nftdata[tokenId];
            dataValue= s.moredataaddress[num] ;
    }

    //Required parameters for current version
    function updateMonkeyData(uint256 tokenId,uint256 dataId,uint256 dataValue) external {
        require(_exists(tokenId), "ERC721: query for nonexistent token");
        require(hasRole(MINTER_ROLE, _msgSender()), "ERC721PresetMinterPauserAutoId: must have minter role to mint");
        NFTdata storage s = nftdata[tokenId];
        if(dataId==0){
            s._mininggift = dataValue;
        }else if(dataId==1){
            s._growthValue = dataValue;            
        }else if(dataId==2){
            s._generation = dataValue;                
        }   

    }     
    
   //Reserved for expansion   
    function updateMonkeyDataMoreUint(uint256 tokenId,uint256 dataId,uint256 num,uint256  dataValue) external {
        require(_exists(tokenId), "ERC721: query for nonexistent token");
        require(hasRole(MINTER_ROLE, _msgSender()), "ERC721PresetMinterPauserAutoId: must have minter role to mint");
        NFTdata storage s = nftdata[tokenId];
        if(dataId==0){
            s.appearance[num] = dataValue;
        }else if(dataId==1){
            s.moredatauint[num] = dataValue;            
        }

    }      
    
    //dataId Reserved for expansion
    function updateMonkeyDataMoreString(uint256 tokenId,uint256 dataId,uint256 num,string memory dataValue) external {
        require(_exists(tokenId), "ERC721: query for nonexistent token");
        require(hasRole(MINTER_ROLE, _msgSender()), "ERC721PresetMinterPauserAutoId: must have minter role to mint");
        NFTdata storage s = nftdata[tokenId];
        s.moredatastring[num] = dataValue;

    }      
    
    //dataId Reserved for expansion
     function updateMonkeyDataMoreAddress(uint256 tokenId,uint256 dataId,uint256 num,address dataValue) external {
        require(_exists(tokenId), "ERC721: query for nonexistent token");
        require(hasRole(MINTER_ROLE, _msgSender()), "ERC721PresetMinterPauserAutoId: must have minter role to mint");
        NFTdata storage s = nftdata[tokenId];
        s.moredataaddress[num] = dataValue;

    }        


} 