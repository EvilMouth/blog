---
layout: post
title: 智能合约真好玩（二）
date: 2019-01-09 16:28:16
tags: 
 - ethereum
 - contract
categories: Blockchain
---

### address vs address payable

在solidity 5.0版本之后，address被拆分成address和address payable
![](http://images.zyhang.com/19-1-9/3339005.jpg)

在5.0之后，address将失去`transfer`功能，得声明成address payable才有

> msg.sender是一个address payable

<!-- More -->

### address 转 address payable

```sol
address addr = xxx;
address payable addr1 = address(uint160(addr))
```

### address payable 转 address

```sol
address payable addr = xxx;
address addr1 = address(addr);
```

### 合约支持接收eth

要使合约支持接收eth转账，需要声明payable函数，例如回退函数
```sol
function() external payable {
}
```

> !!! 如果合约支持接收eth，那么最好声明对应的提取eth函数，例如

```sol
function withdraw() external {
    require(msg.sender == owner);
    msg.sender.transfer(address(this).balance);
}
```

### payable测试

可以在remix上测试payable函数，填入Value数值调用即可
![](http://images.zyhang.com/19-1-9/9265427.jpg)

### ERC20规范

decimals需要先声明为uint8，再强转成uint256，例如定义500w总量
```sol
uint8 public constant decimals = 18;
uint256 public totalSupply = 5000000 * (10 ** uint256(decimals));
```

### gas不足

当合约代码中存在的操作越来越多，对应的gas消耗也会越来越多（具体可以看官方的gas计算方式），那么在部署或者进行函数调用时，可能会出现失败的情况

例如在remix部署合约时出现
![](http://images.zyhang.com/19-1-9/95151998.jpg)

这些情况都可能是设定的gas limit过低，需要消耗的gas超过了limit导致调用失败，遇到这种情况都可以通过上调gas支出解决

