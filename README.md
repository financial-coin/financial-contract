# 无gas交易理财平台

1. 用户无需支付gas和发送交易
2. 持续集成多个理财产品
3. 一键签发授权，自动完成买卖
4. 接入BTC兑换BTU功能 ？
5. 接入BTU兑换USDT或USDC功能 ？


## 合约架构


### 入口合约

对理财产品进行管理，主要是创建理财合约；验证permit签名授权，然后调用对应理财合约接口，主要包括使用代币购买理财资产和卖出理财资产返回代币；买卖理财资产的手续费收取

1. 接口：创建理财产品合约（管理者可调用）
2. 接口：买入理财资产（用户permit签名，后端服务可调用）
3. 接口：卖出理财资产（用户permit签名，后端服务可调用）
4. 接口：查询理财产品列表、查询用户资产
5. 事件：创建理财产品

### 理财合约
抽象封装实际的金融产品，提供统一的买入卖出接口，简化用户理财资产管理；用户买入后会获得一个NFT凭证，代表用户持有对应的理财资产，卖出后销毁NFT凭证；可将NFT凭证转给其他地址

1. 接口：买入理财资产（入口合约或用户可调用）
2. 接口：卖出理财资产（入口合约或用户可调用）
3. 接口：查询用户资产
4. 接口：所有NFT类接口
5. 事件：买入或卖出理财资产

**入口合约和理财合约是一对多关系，理财合约的资产凭证会默认授权给入口合约，入口合约会统一验证用户的permit签名后再调用对应的理财合约接口**


## 合约流程

1. 管理员部署入口合约，配置合约参数：手续费接收地址等等
2. 按照预先定义好的接口，实现多个理财合约，管理员将理财合约发布到入口合约中
3. 前端用户会看到入口合约中理财产品（合约）列表，可选择指定理财产品进行买卖
4. 用户选择一个买入操作（理财合约地址、数量、代币等等），并对其签名后发给后端服务
5. 由后端服务调用入口合约，传入用户的操作和签名，执行理财产品的购买流程
6. 入口合约验证签名通过后，扣除手续费，再用剩余代币去调用指定理财合约的买入接口
7. 理财合约调用其绑定的金融产品合约购买接口，成功后铸造一个NFT返回给用户
8. 买入成功后会发出合约事件，用户可以通过事件或者直接调用合约接口查看持有的理财资产
9. 卖出理财资产和买入是类似的流程，销毁NFT并返回代币及其收益

**理财收益由第三方提供，平台不保证正收益**