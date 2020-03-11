---
layout: post
title: Kotlin androidExtensions findViewById缓存问题
date: 2019-09-26 10:42:26
tags: kotlin
categories: Android
---

`Kotlin Android Extensions`用的肯定很爽，少了一堆`findViewById`的编写，插件本身为我们生成代码，并且还会缓存起来，通过调用`_$_findCachedViewById`代替，避免频繁调用`findViewById`，看起来方便又高效，实际上有一个需要注意的点被忽略

<!-- More -->

## 0x01 缓存问题
在实际项目中，往往不止在`Activity`或`Fragment`里面用到该插件，更多的会是在列表里面的`item`去使用，比方说`RecyclerView`的`ViewHolder`，往往只是这样写
``` kotlin
holder.itemView.textView1.text = "text1"
holder.itemView.textView2.text = "text2"
```

看上去跟`Activity`调用的方式差不多，只是需要通过具体的`itemView`去访问到具体的`textView1`，应该没什么问题，但是当把kotlin代码转成Java代码后，看到的是这样的情况
``` java
TextView var24 = (TextView)var3.findViewById(id.textView1);
var24.setText("text1")
```

可以看到并没有使用cache，也就是`_$_findCachedViewById`，当我改成调用两次
``` kotlin
holder.itemView.textView1.text = "text1"
holder.itemView.textView1.textSize = 16f
```

则会
``` java
TextView var24 = (TextView)var3.findViewById(id.textView1);
var24.setText("text1")
var24 = (TextView)var3.findViewById(id.textView1);
var24.setTextSize(14f)
```

竟然调用了两次`findViewById`

## 0x02 缓存问题解决

当在这种需要通过`view`去获取`子view`再去操作的情况下，官方其实后来给了一个解决方案
- LayoutContainer

需要额外再`build.gradle`配置
``` groovy
androidExtensions {
    experimental = true
}
```

然后将需要的类实现`LayoutContainer`接口
``` kotlin
class ViewHolder(override val containerView: View) : RecyclerView.ViewHolder(containerView), LayoutContainer {
    fun setup() {
        textView1.text = "text1"
        textView1.textSize = 16f
    }
}
```

这下再来看看编译后的代码
``` java
TextView var24 = (TextView)this._$_findCachedViewById(id.textView1);
var24.setText("text1")
var24 = (TextView)this._$_findCachedViewById(id.textView1);
var24.setTextSize(14f)
```

## 0x03 待续
