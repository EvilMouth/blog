---
layout: post
title: 使用Hexo搭载博客
date: 2017-02-24 16:18:14
tags: blog
categories: Hexo
---

记录一下通过Hexo搭载个人博客过程，不得不说Hexo真的强大。

官方文档
[https://hexo.io/zh-cn/docs/index.html](https://hexo.io/zh-cn/docs/index.html)

<!-- More -->

## 安装前提
系统环境必须有Node和Git
- [https://nodejs.org/zh-cn/](https://nodejs.org/zh-cn/)
- [https://git-scm.com/](https://git-scm.com/)

## 安装Hexo
```
$ npm install -g hexo-cli
```
没有npm可以使用HomeBrew安装，很强大的工具（mac）
[https://brew.sh/](https://brew.sh/)

## 初始化
安装完Hexo后需要init一下并创建本地blog文件夹

下面的`<folder>`随意换成自己想要的文件夹名，如blog
```
$ hexo init <folder>
$ cd <folder>
$ npm install
```
运行后可以在根目录找到<folder>文件夹，里面目录大概如下
```
.
├── _config.yml
├── package.json
├── scaffolds
├── source
|   ├── _drafts
|   └── _posts
└── themes
```

## 验证是否配置成功
```
$ hexo s
```
运行后可以看到命令行
```
INFO  Start processing
INFO  Hexo is running at http://localhost:4000/. Press Ctrl+C to stop.
```
打开链接能正常显示就算配置成功了

## Github Pages Or Coding Pages
接下来就是网站部署了，这样别人就可以访问
### 前提
- 需要配置ssh管理密匙，比较推荐使用这种方式，也可以使用普通的https，还没配置ssh的话可以参考这个
[https://blog.zyhang.com/git-ssh-mac/](https://blog.zyhang.com/git-ssh-mac/)
- 需要给Hexo安装个Git插件
```
$ npm install hexo-deployer-git --save
```

### 第一个选择 部署到Github Pages
部署到Github是个不错的选择，免费且有300MB空间，正常博客够用的，不过是国外的，访问速度可能有点慢
#### 创建仓库
这里要注意下，仓库名必须是唯一的，例如你的用户名是abcd，那么创建的仓库名必须为abcd.github.io。点击Create repository。
![](http://images.zyhang.com/17-2-25/69559239-file_1488012142278_eb7b.png)

#### 创建Github Pages
进入仓库设置，拉到下面看到Github Pages
![](http://images.zyhang.com/17-2-25/32385771-file_1488012069872_12719.png)
可以看到上图save点不了，要求你的仓库起码有点内容，这时候返回仓库首页随便创建一下README就行了，因为后面git博客内容不会管其它文件的。
![](http://images.zyhang.com/17-2-25/77330531-file_1488012110942_20b7.png)
再回到仓库设置，选择主分支，并Save
![](http://images.zyhang.com/17-2-25/31777698-file_1488012122046_1353f.png)
这时候会多出一栏文字
```
Your site is ready to be published at http://abcd.github.io/.
```
就可以通过这个网址访问了

#### 配置_config.xml
打开刚才初始化时的文件夹根目录下的_config.xml文件，并修改deploy下属性，abcd改为你的Github用户名
```
deploy:
  type: git
  repo:
    github: git@github.com:abcd/abcd.github.io.git
  branch: master
```

#### 部署
```
$ hexo d -g
```
部署成功后使用刚才Github Pages地址就可以访问你的博客了。

### 第二个选择 部署到Coding Pages
也可以部署到Coding，毕竟国内，而且项目可以设置私有，避免泄露某些重要key
#### 创建仓库
同样先创建仓库，注意仓库名也必须是唯一的：abcd.coding.me，abcd是你的用户名
![](http://images.zyhang.com/17-3-4/6216032-file_1488590422021_81e4.png)
#### 创建Coding Pages
来到->代码->Pages服务，选择来源master主分支并保存
![](http://images.zyhang.com/17-3-4/59293459-file_1488590628082_7b05.png)
可以看到已经成功运行
![](http://images.zyhang.com/17-3-4/293295-file_1488590762691_7c6f.png)

#### 配置_config.xml
打开刚才初始化时的文件夹根目录下的_config.xml文件，并修改deploy下属性，abcd改为你的Coding用户名，可以看到github被注释掉了，如果想同时部署到多个仓库，就可以采用这种方式
```
deploy:
  type: git
  repo:
    # github: git@github.com:abcd/abcd.github.io.git
    coding: git@git.coding.net:abcd/abcd.coding.me.git
  branch: master
```

#### 部署
```
$ hexo d -g
```
同样部署成功后使用刚才Coding Pages地址就可以访问你的博客了。

## 博客配置
部署的博客上面有些信息是默认的，比如博客名称作者名称等等，肯定需要改成自己的，可以参考
[http://theme-next.iissnan.com/getting-started.html(http://theme-next.iissnan.com/getting-started.html)

这是个人比较喜欢的主题NexT，官网也有很多很好的主题，自行选择。

## 进阶-绑定域名
首先需要一个域名，GoDaddy、万网、新网都可以，建议还是买比较好的域名，毕竟有些域名备不了案。我是在万网买的域名zyhang.com，一年貌似几十块钱，非常便宜

### 设置DNS服务器
这里建议选择DNSPod，不过也可以用万网自己的。进入万网控制台，并修改DNS服务器为
![](http://images.zyhang.com/17-3-4/12514621-file_1488592560805_e07e.png)
- f1g1ns1.dnspod.net
- f1g1ns2.dnspod.net

### 解析
如果选择了DNSPod，那就要去DNSPod进行解析了。[DNSPod入口](https://www.dnspod.cn/)

#### 添加域名
进入DNSPod，进入域名解析并添加域名
![](http://images.zyhang.com/17-3-4/39339182-file_1488592865716_178e7.png)

#### 添加解析记录
可以解析到Github也可以解析到Coding也可以都解析

##### 解析到Github
- 解析到Github需要注意一点，就是需要在`<folder>`目录下的`source`目录里新建个文件CNAME并在文件里面添加一行你的域名，我这里是zyhang.com,如果不想解析到主域名，这里也可以写成类似blog.zyhang.com等等，记得重新git到Github上
![](http://images.zyhang.com/17-3-4/68548880-file_1488593305490_3e39.png)
- 继续到DNSPod添加解析记录，添加以下三项，域名解析有时候得等一会，稍后就可以使用你的域名访问网站了
![](http://images.zyhang.com/17-3-4/49314180-file_1488606823923_13b25.png)

##### 解析到Coding
- 解析到Coding不需要像Github一样新建个CNAME文件，只需要直接到项目控制台->代码->Pages服务->自定义域名，填写你的域名进行绑定就可以了
![](http://images.zyhang.com/17-3-4/95278537-file_1488607513967_a276.png)
- 然后依然是到DNSPod添加解析记录，添加以下两项即可
![](http://images.zyhang.com/17-3-4/28231828-file_1488607212191_7e90.png)

至此自定义域名绑定成功
