---
layout: post
title: 支付宝小程序指定页面跳转
date: 2020-03-11 13:25:37
tags:
  - alipay
  - tinyapp
  - route
categories: Android
---

支付宝小程序支持从外部调起，具体做法是通过`scheme`，如下
```
alipays://platformapi/startapp?appId=[appId]&page=[pagePath]&query=[params]
```

- appId 是小程序唯一Id
- pagePath 是页面路径，也就是本文要讲的，不带则跳首页
- params 是额外参数

> 更多信息请前往官网[https://opensupport.alipay.com/support/knowledge/31867/201602383690?ant_source=zsearch](https://opensupport.alipay.com/support/knowledge/31867/201602383690?ant_source=zsearch)

<!-- More -->

## 例子 - 答答星球

### 如何拿到答答星球的appId

- 最简单的方法就是通过小程序分享功能，分享到钉钉，再打开，复制链接，可以拿到这么一串url
https://render.alipay.com/p/s/i/?scheme=alipays%3A%2F%2Fplatformapi%2Fstartapp%3FappId%3D77700189%26page%3Dpages%252Findex%252Findex%26enbsv%3D0.1.2003090940.1%26chInfo%3Dch_share__chsub_DingTalkSession
- decode一下scheme部分
alipays://platformapi/startapp?appId=77700189&page=pages%2Findex%2Findex&enbsv=0.1.2003090940.1&chInfo=ch_share__chsub_DingTalkSession
- 其中的77700189就是答答星球的appId

> page部分再decode则是pages/index/index，首页的意思，但是我想跳到其他页面那就得知道路径

### 拿路径

- 一台root的手机
- 进入到`data/data/com.eg.android.AlipayGphone/files/nebulaInstallApps`
![](http://images.zyhang.com/FhCa-97vEkQ7gaQQ9u7Xfcao0dm5)
- 找到77700189
![](http://images.zyhang.com/FiHuYsj6EhYBDSlQc5xXMPyXeMdK)
- 其中的tar文件就是答答星球打包后的压缩包
- 传到电脑解压拿到所有页面路径
![](http://images.zyhang.com/FrzcJjE1ZxCmTWt-C3vBvBQ62hds)

### 跳转

比方说想要跳转到答答星球的天天涨知识页面`pages/domain/home/index`
``` kotlin
val scheme = "alipays://platformapi/startapp?appId=77700189&page=pages%2Fdomain%2Fhome%2Findex"
val intent = Intent(Intent.ACTION_VIEW, Uri.parse(scheme))
intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
startActivity(intent)
```
