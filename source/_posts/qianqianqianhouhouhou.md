---
layout: post
title: 前前前后后后
date: 2020-02-29 19:21:34
tags:
  - eggjs
  - sqeuelize
  - github actions
categories: Backend
---

.

<!-- More -->

## 前言

这两个星期是我最完整的一次全栈开发经历，前端`vue`，后端`eggjs`，服务器`淘宝`，域名`namecheap`。虽然之前也搭过服务器（本博客网站），但是这次也遇到了些许问题，包括`eggjs`、`sequelize`、`Github Actions`等等，让我慢慢一一道来

## eggjs

后端开发这块我之前是写`java`的，这次在服务器性能一般的考虑下，鉴于前端的`js`，故决定后端也使用`js`，正好也学一学`nodejs`。一开始后端框架选型的时候对准着`koa`，不过正好想到`eggjs`好像近期听得比较多，所以就上`eggjs`官网了解一下，对`koa`也没有很熟，那干脆就你了

### 打包问题

`eggjs`倒是用着没啥问题，就是最后打包部署的时候有点疑惑，根据[官方介绍](https://eggjs.org/zh-cn/core/deployment.html)，`eggjs`内置了`egg-cluster`代替`pm2`启动进程服务，使用是在项目的目录下直接运行`npm start`，那意味着项目在服务器需要是源码级别的文件，而不是想`vue`项目打包混淆后的`dist/`代替，希望看到这里的你能解答我的疑惑

### sequelize

TODO

## 服务器

很多跟SELinux有关，比方说
- Nginx安装启动后竟然连欢迎页都打不开
- 配置include外部conf文件竟然无效
- 读取conf文件竟然权限不足
- 配置上游但是不允许访问

基本上遇到很多之前搭服务器没遇到过的问题，遇到这些异常问题时，可以考虑下是否是SELinux的问题，试着先临时关闭它排查下

- netstat -tnpl
- sudo firewall-cmd --zone=public --add-port=3000/tcp --permanent
- sudo firewall-cmd --reload
- sudo firewall-cmd --remove-port=3000/tcp --permanent
- sudo firewall-cmd --reload

### Nginx

- yum install nginx
- service nginx start
- systemctl enable nginx
- vim /etc/nginx/nginx.conf
- include xxx/xxx/*.conf

#### 欢迎页无法访问

SELinux限制
- sudo firewall-cmd --permanent --zone=public --add-service=http
- sudo firewall-cmd --permanent --zone=public --add-service=https
- sudo firewall-cmd --reload

#### 无权限读取conf文件

同样是SELinux限制
- sudo restorecon xxx/xxx.conf

#### 配置上游但是不允许访问

[https://stackoverflow.com/questions/23948527/13-permission-denied-while-connecting-to-upstreamnginx](https://stackoverflow.com/questions/23948527/13-permission-denied-while-connecting-to-upstreamnginx)
- getsebool -a | grep httpd 发现其中 httpd_can_network_connect –> off
- setsebool httpd_can_network_connect 1

### Mysql

- yum install mysql-server
- service mysqld start
- systemctl enable mysqld
- grep 'temporary password' /var/log/mysqld.log
- mysql -uroot -p
- >mysql create user 'userxxx'@'localhost' identified of 'psdxxx';
- >mysql grant all privileges on *.* to 'userxxx'@'%' with grant option;
- >mysql flush privileges;
- >mysql use mysql;
- >mysql select Host,User from user where User='userxxx'

### cron自启动eggjs

nginx、mysql这些服务本身就支持设置开机启动，但是eggjs项目不行，这时候就可以利用cron服务

- yum install crontabs
- service crond start
- syctemctl enable crond
- vim xxx.sh 内容是启动eggjs的相关命令
- vim xxx.cron 内容是 @reboot xxx.sh
- crontab xxx.cron
- crontab -l 查看是否配置成功

## GitHub Actions自动部署

### sftp

在`Github Actions Marketplace`找到个[SFTP Deploy](https://github.com/marketplace/actions/sftp-deploy)帮助在构建后利用`sftp`将文件上传到服务器

比方说vue项目打包出`dist/`然后上传
- secrets.xxx 是类似环境变量，在github上的项目设置里配置

``` yml
on:
  push:
    branches:
      - master

env:
  NODE_VERSION: '10.x'                # set this to the node version to use

jobs:
  build-and-deploy:
    name: Build and Deploy
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    - name: Use Node.js ${{ env.NODE_VERSION }}
      uses: actions/setup-node@v1
      with:
        node-version: ${{ env.NODE_VERSION }}
    - name: npm install, build, and test
      run: |
        npm install
        npm run build
    - name: push
      uses: izyhang/SFTP-Deploy-Action@v1.1
      with:
        username: '${{ secrets.SSH_NAME }}'
        server: '${{ secrets.SSH_IP }}'
        ssh_private_key: ${{ secrets.SSH_PRIVATE_KEY }}
        local_path: './dist/*'
        remote_path: '${{ secrets.SSH_TARGET_PATH }}'
```

### 压缩后再sftp

项目文件多起来之后不压缩再上传实在效率低，那么自然要用到`tar`命令，但是

1、`tar -zcf ./release.tgz .` -> 压缩到项目文件夹下会报错
2、`tar -zcf ../release.tgz .` -> 压缩到项目上级文件夹不会报错但是sftp拿不到该文件
3、最后 -> `tar -zcf ../release.tgz .` -> `cp ../release.tgz ./release.tgz` -> 才搞定

前两步为什么不行我实在找不到原因

### sftp后解压

上一步压缩后上传到服务器需要解压等后续操作，所以我在[SFTP Deploy](https://github.com/marketplace/actions/sftp-deploy)基础上加多了个在服务器执行命令的操作得到了[新·SFTP Deploy](https://github.com/izyhang/SFTP-Deploy-Action)

比方说解压+eggjs重启

``` yml
on:
  push:
    branches:
      - master

env:
  NODE_VERSION: '10.x'                # set this to the node version to use
  TGZ_PATH: './release.tgz'
  KEY_PATH: './private_key'

jobs:
  build-and-deploy:
    name: Build and Deploy
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    - name: Use Node.js ${{ env.NODE_VERSION }}
      uses: actions/setup-node@v1
      with:
        node-version: ${{ env.NODE_VERSION }}
    - name: npm install, build, and test
      run: |
        npm install --production
    - name: tar c
      run: |
        tar -zcf ../release.tgz .
        cp ../release.tgz ${{ env.TGZ_PATH }}
    - name: push
      uses: izyhang/SFTP-Deploy-Action@v1.1
      with:
        username: '${{ secrets.SSH_NAME }}'
        server: '${{ secrets.SSH_IP }}'
        ssh_private_key: ${{ secrets.SSH_PRIVATE_KEY }}
        local_path: '${{ env.TGZ_PATH }}'
        remote_path: '${{ secrets.SSH_TARGET_PATH }}'
        ssh_command: 'tar -zxf ${{ env.TGZ_PATH }};npm stop;npm start --env=prod'
```




