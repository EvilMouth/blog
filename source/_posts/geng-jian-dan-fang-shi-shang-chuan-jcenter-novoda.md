---
layout: post
title: 更简单的方式上传jcenter
date: 2018-08-10 16:52:21
tags:
 - jcenter
 - novoda
categories: Maven
---

整理了一下`novoda`使用流程和步骤，结合`Android`项目结构，整合出一份通用并且更简单的使用方式

> 一键上传
> 支持多Library上传

<!-- More -->

## 0x00 注册bintray

注册`bintray`这个步骤就不打扰了[https://blog.zyhang.com/maven-jcenter/](https://blog.zyhang.com/maven-jcenter/)

## 0x01 配置步骤

先放上`novoda`链接
[https://github.com/novoda/bintray-release](https://github.com/novoda/bintray-release)

再放上我的`demo`链接
[https://github.com/izyhang/novoda-push](https://github.com/izyhang/novoda-push)

### 需要修改的文件

- 根build.gradle - 添加novoda依赖
- 根gradle.properties - 配置仓库通用属性
- 仓库build.gradle - 添加fuck命令依赖
- 仓库gradle.properties - 配置仓库具体属性
- 根local.properties - 配置bintray密匙

### 添加novoda依赖

在项目`根build.gradle`添加novoda依赖
``` groovy
buildscript {
    repositories {
        // novoda依赖需要依赖jcenter
        jcenter()
    }
    dependencies {
        // 添加novoda依赖
        classpath 'com.novoda:bintray-release:0.8.1'
    }
}
```

### 配置仓库通用属性

在项目`根gradle.properties`配置仓库通用属性
``` properties
POM_GROUP_ID=com.zyhang
POM_PUBLISH_VERSION=2.0.0-alpha

POM_REPO_NAME=maven
POM_USER_ORG=zyhang
POM_LICENCES=Apache-2.0
POM_WEBSITE=https://github.com/izyhang/Damon
POM_ISSUE_TRACKER=https://github.com/izyhang/Damon/issues
POM_REPOSITORY=https://github.com/izyhang/Damon.git
```

### 配置仓库具体属性

在具体仓库（也就是Library Module）`gradle.properties`配置仓库具体属性
``` properties
POM_UPLOAD_NAME=Damon
POM_ARTIFACT_ID=damon
POM_DESC=mvp framework
```

### 添加fuck命令依赖

在具体仓库（也就是Library Module）`build.gradle`添加fuck命令依赖
``` groovy
apply plugin: 'com.android.library'

android {
    ...
    defaultConfig {
        ...
        versionCode 1
        versionName POM_PUBLISH_VERSION // 建议加上这句
    }
}

// 在底部加上这句
apply from: 'https://raw.githubusercontent.com/izyhang/novoda-push/master/gradle/push.gradle'
```

### 配置bintray密匙

在根`local.properties`配置`bintray`密匙
``` properties
bintray.user=***
bintray.apikey=******
```

## 0x02 使用步骤

在配置后各属性后，直接执行具体`Library Module`的`fuck`命令。
之后更新版本就是修改`根gradle.properties`文件的`POM_PUBLISH_VERSION`后执行`fuck`

![](http://images.zyhang.com/18-8-10/69524790.jpg)

## 0x03 一些坑

- 使用`kotlin`编写的项目可能会遇到`.kt`文件无法生成`javadoc`情况，可以在`根build.gradle`文件下添加
``` groovy
tasks.getByPath(":your module:releaseAndroidJavadocs").enabled = false
```