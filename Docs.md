一、文档简易说明
1、所有连接的都是Kovan测试网，每个合约的合约地址在代码的第二行注释中
2、每个合约的ABI在第三行注释中

    address public _tokenToPay = 0x5E8A819CCF47E3a83864c6c8cb6328cbe223093C;//这个就是测试代币，用于购买盲盒、喂养、市场购买猴子等，实际在OKExChain上会替换为OKB、WOKT、USDT等主流币，因此【无需审计】
    address public _monkeyNFT = 0x72f9912E656f235543869521ed66dca7749aC0D8;//Monkey NFT的合约，用途是Monkey拥有证明+存储NFT的信息
    address public _boxesToken = 0x1FcB262dbD2Cc462091714517819448Ea754C5E8;//Boxex Token合约，用于是证明你拥有盲盒，通过BoxesV1合约购买可获得，通过过BoxesV1合约开盲盒换成Monkey NFT    
    address public _boxesV1 =0xa4b35FC534299fD7128b62f466b5eA3eC69bd153;//BoxesV1，用于 销售 Boxes Token（盲盒）、开Boxes Token盲盒获得 monkey NFT
    address public _feedV1=0xE2aED1f147a1f9FcF238288cE2D43Fa36719f7D1; //FeedV1 ，喂养合约，用于每日猴子喂养、喂养记录的查询、喂养挖矿（主流币+MKY双挖）的提取
    address public _market = 0xb29F82BB2C7a04127f6D7023BcBE0002d77e51Bb;//交易市场，买卖MonkeyNFT
    address public _monkeyToken =0x5243a416BF3EccAFA1A560F0C8A5E748EE4ED730;//MKY代币合约
    address public _ForFrontEnd =0xF0D26DE56DC72b4A97508933b1f7cfA6646C549A;//前端专用查询合约，【无需审计】，用途是聚合查询，纯查询 无交易。【此合约仍在开发中】
    address public _MKYFeedV1 = 0xd0DBd7a41986A5615cD9f319dCcde7E8d170a058;//限时活动:喂养MKY挖MKY
    address public _strategy = 0xe15eb4256895D903893c2FA448c7A0E05A07c005;//策略控制合约，用于控制概率、挖矿得分计算，纯查询 无交易。

二、前端接口需求(含跑通基本流程)
NFT展示
1、(view)根据地址查看拥有的猴子的属性 
2、(view)根据地址查看今天分数、昨天分数和收益，

盲盒
0、购买前准备：授权， Erc20ForTest.approve(BoxesV1,10000000000000000000000000)
1、购买盲盒（数量写死1）：BoxesV1.buy(1)
2、开盲盒前准备BoxexToken.approve(BoxesV1,10000000000000000000000000)
3、开盲盒： BoxesV1.openBox()

NFT喂养
0、喂养前准备，授权， Erc20ForTest.approve(FeedV1,10000000000000000000000000)
1、喂养单只（输入的是tokenId） FeedV1.feed(uint256 tokenId,uint256 value)
2、(限时活动)除了正在喂养额外喂养MKYFeedV1.feed(uint256 tokenId,uint256 value)
3、手动跳过一天FeedV1.addTodayForTest()
4、(限时活动)手动跳过一天MKYFeedV1.addTodayForTest()
5、提取收益FeedV1.claimReward()
6、(限时活动)MKYFeedV1.提取收益FeedV1.claimReward()

交易市场
0、使用前准备：NFT授权MonkeyNFT.setApprovalForAll(Market,true)
1、挂单出售（输入的是tokenId,价格）：Market.placeOrder(uint256 tokenId,uint256 price)
2、购买前准备：授权， Erc20ForTest.approve(Market,10000000000000000000000000)
3、交易市场可购列表展示ForFrontEnd.getMarketMore() view public returns(uint256[] memory orderIds,address[] memory  seller,uint256[] memory tokenId,uint256[] memory price,bool[] memory haveBroughtOrCancel)
3、购买（输入的是orderId）：Market.buy(uint256 orderId)

三、玩法及规则概述
1、盲盒
盲盒第一期（每日限购1万个）限7天
独一无二的NFT
50U开盲盒，未来2MKY开盲盒
1/2000 概率抽到等级0
1/200 等级一
1/25等级二
1/5等级三
其他等级四
初始属性100-199 二个属性: 掘金(mininggift)、成长值（growthValue）（成长值在本版本没有任何作用）
10天后开 二期初始属性160-250
20天后开 三期初始属性220-310
喂养1/10概率增加属性=喂养值*1

2、喂养
喂主流币，每天每只猴子可以喂5个主流币，也可以一次喂完5个主流币
喂养增加体重（又称 喂养基础分），任何猴子喂养一个币就增加10的体重，体重每日清零；有20%概率双倍喂养，有20%概率0.5倍喂养
喂养增加属性：10%概率提升掘金(mininggift) 10个点，10%概率提升成长值(growthValue)10个点

3、每日挖矿（双挖：既挖主流币又挖MKY）
掘金主流币
掘金分=喂养基础分*掘金/代系数，每日0点快照，根据单只小猴掘金分占所有小猴总掘金分的比例分享掘金池
掘金池=喂养金额100%+交易手续费50%+生育手续费50% (生育:玩客猴V2版本）
掘金MKY
掘金分=喂养基础分*掘金*代系数，每日0点快照，根据单只小猴掘金分占所有小猴总掘金分的比例分享掘金池
掘金池=每日注入10000MKY，

其中，代系数算法为：x等级系数=（1+标准系数）^x，如0等级为1，1等级就是1.3，2等级为1.69

4、限时挖矿（一定时间后关停）
不管等级代数，每日喂1MKY收益1.05MKY，年化收益率：912.5%
实际上就是盲盒或者生育产生小猴的成本是2MKY，让他们40天挖回这两个