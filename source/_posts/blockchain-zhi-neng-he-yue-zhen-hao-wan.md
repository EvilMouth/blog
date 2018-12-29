---
layout: post
title: 智能合约真好玩
date: 2018-12-29 14:51:16
tags: 
 - ethereum
 - contract
categories: Blockchain
---

> 吐槽一下Mist客户端mac版，网络连接异常+是不是崩溃，不过智能合约开发起来真好玩
> 这几天学习了智能合约开发语言solidity，实践起来部署了一份合约并在以太坊主网验证发布，拿着开发的币在测试账号转来转去超好玩。这几天开发遇到了各种各样的小问题和智能合约开发需要注意的一些问题，总结记录一下

<!-- More -->

### rinkeby测试节点

在mist客户端可以切换节点到rinkeby，就可以测试开发，还可以在rinkeby上获取点eth来部署合约
[rinkeby](https://www.rinkeby.io/#stats)

### remix在线开发

使用[remix](https://remix.ethereum.org/#optimize=false)在线测试部署你的合约

### sol文件

智能合约是用solidity语言开发，也就是sol后缀，我是用vscode+sol插件开发的

### event事件兼容

定义一个event事件如下
```solidity
event Something(unit256 value);
```

触发event事件需要使用emit
```solidity
emit Something(value);
```

### 所有者访问限制 - modifier

某些方法如果需要加上身份验证，可以使用modifier，首先定义一个modifier
```solidity
modifier onlyOwner() {
    require(msg.sender == ethFundDeposit, "auth fail"); 
    _;
}
```

之后直接在需要验证身份的方法后面加上onlyOwner，例如
```solidity
function action() external onlyOwner {
    ...
}
```

- external 必须在最前

### throw弃用 - require assert revert

以前使用throw来抛出异常现在有三个代替语法

- require(condition, string) 一般放在方法最前面，会退回剩余gas
- assert(condition) 会消耗所有gas
- revert(string) 会撤销修改状态，会退回剩余gas

### constant view pure

constant被拆分成view和pure

- view 与constant效果一致，只能读状态变量不能改
- pure 不能改甚至不能读状态变量

### decimals

一开始看到计算总量的时候以为看错，原来只是精度

### constructor

构造函数需要使用constructor声明，并且是public修饰

- 注意constructor不需要function声明，否则会有安全问题

### No data is deployed on the contract address!

在部署合约的时候可能会遇到这种gas不足的问题，可以通过手动加gas解决，虽然会花费多一些eth
