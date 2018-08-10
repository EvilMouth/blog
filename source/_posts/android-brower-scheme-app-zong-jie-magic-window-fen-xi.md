---
layout: post
title: Android浏览器们Scheme跳转App总结+魔窗分析
date: 2018-08-08 11:19:46
tags: scheme
categories: Android
---

偶然得知魔窗这款产品，其中的`mLink`企业级深度链接解决方案，在当今存在十几款浏览器的Android市场下，也是对浏览器跳转App提供了很好的兼容

之前也是做过浏览器跳转App，利用Scheme机制，对Activity加`intent-fliter`来实现，只不过看到魔窗mLink可以在没有安装App的情况下，用户下载App并打开后，竟然能够复原到具体页面感到好奇，于是好奇心作用下研究了下魔窗的sdk

<!-- More -->

## 0x00 Android Scheme

Android Scheme应该都不陌生，类似`zyhang://`这样的格式，在手机浏览器触发这么一段url，就可以启动对应的App，当然前提是App已安装
``` html
<a href="zyhang://">跳转App</a>
```

> 针对未安装App的情况下一般做法是跳转下载页，网上也有很多资料

## 0x01 浏览器兼容

然而，当今Android市场存在不少于十几款浏览器，每一款浏览器不能保证都是一样的处理scheme逻辑，所以也就存在很多奇怪现象的发生

浏览器scheme跳转例子如下
``` kotlin
val scheme = "zyhang://"
val uri = Uri.parse(scheme)
val intent = Intent(Intent.ACTION_VIEW, uri)
// 各个flag的作用自行搭配
intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
startActivity(intent)
```

### 坑一：怎么后台进程有两个我的App
![](http://images.zyhang.com/18-8-9/37431538.jpg)

应该是部分浏览器(例如华为浏览器)在处理scheme时没有针对intent添加`FLAG_ACTIVITY_NEW_TASK`flag，也就导致了App页面会在浏览器进程显示

> 针对这一个问题，可以在入口界面根据intent.data自行添加flag跳转主页之类去处理

### 坑二：百度浏览器跳不了App

这也是很服的，像微信这种白名单过滤存在利益竞争，但也可以注册微下载通过应用宝去跳转，一个浏览器竟然跳不了，暂时找不到方法绕过

### 坑三：Chrome跳转App会重启页面

包括UC、QQ浏览器也会存在这一现象

> 可以给MainActivity增加`FLAG_ACTIVITY_SINGLE_TOP`

## 0x02 魔窗复原场景分析

魔窗的mLink的浏览器跳转App功能也是利用Android Scheme机制实现，看上面↑，其中比较有趣的是复原场景功能，在下载App并打开后能够路由到具体页面，这个功能是Android Scheme无法做到的。

> iOS的App Store有这样的功能，依赖于App Store
> Android市场混乱，所以魔窗的这套解决方案的确很妙

### 源码分析

实现这一场景复原的功能是由这一句触发的
``` kotlin
MLink.getInstance(this).deferredRouter()
```

先看MLink初始化源码
``` java
private MLink(Context var1) {
        /* 省略 */
        this.onReferral();
    }

private void onReferral() {
        // needGetDPLs 判断时间和是否第一次获取DPLs
        if (this.needGetDPLs()) {
            this.getDPLs();
        }
    }

private void getDPLs() {
        /* 省略 */
        // 请求接口保存DPLs
        StringRequest var3 = new StringRequest(HttpMethod.POST, "https://stats.mlinks.cc/dp/dpls/v2", new h(this));
        var3.setBodyParams(var1);
        HttpFactory.getInstance(MWConfiguration.getContext()).addToRequestQueue(var3);
    }
```

抓个包看到，最下面的`ddl.dp`就是要触发的scheme
![](http://images.zyhang.com/18-8-9/99925369.jpg)

> 后面就是根据这个`ddl.dp`去跳转到具体页面，这就是魔窗能复原场景的原因，这个功能也是挺有用的

抓包过程中发现个问题，拿的是丰趣海淘抓的包，人家用的是旧的sdk，3.9版本的，魔窗没用https，所以丰趣海淘的scheme完全暴露，新的魔窗sdk就改接口了，不过还没试。比如scheme跳webView等就存在钓鱼风险了，所以使用还是要留个心眼。

## 0x03 demo

整理了一下，备份下

``` xml
<activity android:name=".SplashActivity">
            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
            <intent-filter>
                <data
                    android:scheme="zyhang"/>
                <action android:name="android.intent.action.VIEW"/>

                <category android:name="android.intent.category.DEFAULT"/>
                <category android:name="android.intent.category.BROWSABLE"/>
            </intent-filter>
        </activity>
```

``` kotlin
class SplashActivity : BaseActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_splash)

        if (!intent.dataString.isNullOrEmpty()) {
            val intent = Intent(this, MainActivity::class.java)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            startActivity(intent)
            
            // 处理scheme
            xxx
            
            finish()
        } else {
            startActivity(Intent(this, MainActivity::class.java))
            finish()
        }
    }
}
```
