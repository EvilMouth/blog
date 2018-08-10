---
layout: post
title: 上传项目到jitpack
date: 2017-05-08 14:56:48
tags: jitpack
categories: Maven
---

需要发布个人仓库方便其他项目使用，最容易的方法估计也就是`jitpack`了

`jitpack`官网其实就有教程[https://jitpack.io/docs/ANDROID/](https://jitpack.io/docs/ANDROID/)

<!-- More -->

## 添加maven插件
在根`build.gradle`配置插件
```
buildscript {
  dependencies {
    classpath 'com.github.dcendents:android-maven-gradle-plugin:1.5' // Add this line
```

## 配置library
在`library`的`build.gradle`添加
```
apply plugin: 'com.github.dcendents.android-maven'  

 group='com.github.YourUsername'
```

## 创建一个release
为你的`Github`仓库创建一个`release`
![](http://images.zyhang.com/17-5-8/84269509-file_1494227979898_fc74.png)
![](http://images.zyhang.com/17-5-8/22225564-file_1494228002946_9e3c.png)
![](http://images.zyhang.com/17-5-8/38416150-file_1494228025794_2f35.png)

## 拉依赖
```
allprojects {
 repositories {
    jcenter()
    maven { url "https://jitpack.io" }
 }
}
```
最后
```
dependencies {
    compile 'com.github.YourUsername:YourProjectName:YourProjectVersion'
}
```
