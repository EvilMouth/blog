---
layout: post
title: Android Glide踩坑记 - AppGlideModule
date: 2018-11-06 15:43:24
tags: glide
categories: Android
---

在最新的`Glide 4.x`中，应该是`4.x`开始吧，官方改变了`Glide`的请求结构，许多api包括常用`centerCrop()`、`error()`、`placeholder()`等都需要通过`RequestOptions`去配置，从而导致从`3.x`迁移过来一路坎坷。所以官方为我们提供了`AppGlideModule`让我们保留以前的流式调用，然而...

<!-- More -->

## 0x01 You cannot call Glide.get() in registerComponents(), use the provided Glide instance instead

这是什么鬼，明明debug包玩的好好的，打个release包就崩溃了，赶紧点进去看看
``` java
public static Glide get(@NonNull Context context) {
  if (glide == null) {
    synchronized (Glide.class) {
      if (glide == null) {
        checkAndInitializeGlide(context);
      }
    }
  }
  return glide;
}

private static void checkAndInitializeGlide(@NonNull Context context) {
  // In the thread running initGlide(), one or more classes may call Glide.get(context).
  // Without this check, those calls could trigger infinite recursion.
  if (isInitializing) {
    throw new IllegalStateException("You cannot call Glide.get() in registerComponents(),"
        + " use the provided Glide instance instead");
  }
  isInitializing = true;
  initializeGlide(context);
  isInitializing = false;
}
```

调用`Glide.with()`会去拿单例，从而进入到`checkAndInitializeGlide`，报错的原因单例`glide=null`并且`isInitializing`，这东西怎么感觉不是我的问题。

这个是`Glide`的初始化问题，是什么导致的呢？协程？同步锁？混淆？

我一开始也是以为是混淆问题，所以赶紧去官网翻了下混淆文档
![](http://images.zyhang.com/18-11-6/89875063.jpg)

嗯？没什么问题，一切按照文档配置，针对自定义的`AppGlideModule`也有防混，那么只能上issue看看了

[https://github.com/bumptech/glide/issues/2780](https://github.com/bumptech/glide/issues/2780)

貌似有人说了初始化的问题，要放到`Application.onCreate()`去初始化？？？看了整页都没有解决方案，那只好试一下了

## 0x02 GeneratedAppGlideModuleImpl is implemented incorrectly. If you've manually implemented this class, remove your implementation. The Annotation processor will generate a correct implementation.

？？？虽然也是崩溃，不过这次报的错不一样，不过好像能看出什么

`GeneratedAppGlideModuleImpl`这个东西就是我们自定义`AppGlideModule`会帮我们生成的代理类，这里说它实现错误了
``` java
private static GeneratedAppGlideModule getAnnotationGeneratedGlideModules() {
  GeneratedAppGlideModule result = null;
  try {
    Class<GeneratedAppGlideModule> clazz =
        (Class<GeneratedAppGlideModule>)
            Class.forName("com.bumptech.glide.GeneratedAppGlideModuleImpl");
    result = clazz.getDeclaredConstructor().newInstance();
  } catch (ClassNotFoundException e) {
    if (Log.isLoggable(TAG, Log.WARN)) {
      Log.w(TAG, "Failed to find GeneratedAppGlideModule. You should include an"
          + " annotationProcessor compile dependency on com.github.bumptech.glide:compiler"
          + " in your application and a @GlideModule annotated AppGlideModule implementation or"
          + " LibraryGlideModules will be silently ignored");
    }
  // These exceptions can't be squashed across all versions of Android.
  } catch (InstantiationException e) {
    throwIncorrectGlideModule(e);
  } catch (IllegalAccessException e) {
    throwIncorrectGlideModule(e);
  } catch (NoSuchMethodException e) {
    throwIncorrectGlideModule(e);
  } catch (InvocationTargetException e) {
    throwIncorrectGlideModule(e);
  }
  return result;
}

private static void throwIncorrectGlideModule(Exception e) {
  throw new IllegalStateException("GeneratedAppGlideModuleImpl is implemented incorrectly."
      + " If you've manually implemented this class, remove your implementation. The Annotation"
      + " processor will generate a correct implementation.", e);
}
```

之所以报错就是找不到这个类，可以看到这里是通过`Class.forName`去查找的，既然找不到，说明很可能就是我一开始想的，被混淆了，赶紧打开`mapping.txt`看下
```
com.bumptech.glide.GeneratedAppGlideModuleImpl -> gi:
```

果然。。。那就加个混淆
```
-keep class com.bumptech.glide.GeneratedAppGlideModuleImpl { *; }
```

搞定，正常运行