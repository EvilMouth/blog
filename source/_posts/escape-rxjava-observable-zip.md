---
layout: post
title: 摆脱Observable.zip烦人的zipper参数
date: 2018-05-28 21:47:16
tags: rxJava
categories: Android
---

开发中难免遇到单页面多任务的情景，比如详情页的信息可能需要从多个接口获取，虽然以用户体验来看多个接口返回数据互不影响，哪个接口先返回数据就先显示，但在某些特殊情景下，需要多个接口都成功返回数据再统一更新UI

这时就存在一个问题，网络请求都是异步的，怎样才能知道所有接口都请求成功了呢？实现方法有很多种，但要把代码写得优雅一点就不是那么容易了

rxjava有个`zip`操作符可以组合多个`Observable`发射数据再统一发射出来，所以能达到此类场景的要求

<!-- More -->

## zip介绍

这里模拟两个网络请求
```java
Observable<String> o1 = Observable.just("1");
Observable<Integer> o2 = Observable.just(2);
```

此时使用`zip`操作符将两个`Observable`组合到一起
```java
Disposable disposable = Observable.zip(o1, o2,
            new BiFunction<String, Integer, Object>() {
                @Override
                public Object apply(String s, Integer i) throws Exception {
                    return new Object();
                }
            })
            .subscribe(new Consumer<Object>() {
                @Override
                public void accept(Object o) throws Exception {
                    System.out.print(o);
                }
            });
```

`zip`操作符的作用其实就是把多个`Observable`组合成新的`Observable`，这个新的`Observable`还需要自己定义类型，所以实际开发中还需要为两个网络请求的返回数据类型包多一层
```java
public class Wrap {
    public String s;
    public Integer i;

    public Wrap(String s, Integer i) {
        this.s = s;
        this.i = i;
    }
}

Disposable disposable = Observable.zip(o1, o2,
            new BiFunction<String, Integer, Wrap>() {
                @Override
                public Wrap apply(String s, Integer i) throws Exception {
                    return new Wrap(s, i);
                }
            })
            .subscribe(new Consumer<Wrap>() {
                @Override
                public void accept(Wrap w) throws Exception {
                    System.out.print(w.s);
                    System.out.print(w.i);
                }
            });
```

看到`zip`源码，其中最后一个参数`zipper`就是将两个`Observable`组合起来的关键
```java
public static <T1, T2, R> Observable<R> zip(
        ObservableSource<? extends T1> source1, ObservableSource<? extends T2> source2,
        BiFunction<? super T1, ? super T2, ? extends R> zipper) {
    ObjectHelper.requireNonNull(source1, "source1 is null");
    ObjectHelper.requireNonNull(source2, "source2 is null");
    return zipArray(Functions.toFunction(zipper), false, bufferSize(), source1, source2);
}
```

## 正文 - 移除zipper

前面说了这么多，就是为了引出`zipper`。当上例提到的特殊情景越来越多的情况下，每次使用`zip`组合多个请求，就需要一个`Wrap`去包装多个返回数据，极其烦人，所以才有了此文，想方设法拜托这个烦人的`zipper`

`zipper`所需的新的数据类型`Wrap`的作用看来只是包装方便`Observable`返回，实际上最终订阅也只是为了拿到各个请求的数据，所以`Wrap`实体类的存在并没有多大意义

### java层面

`java`层面想要移除`zipper`可以通过一个中间层来帮助管理`Observable`，可以参考[https://github.com/izyhang/DamonTask](https://github.com/izyhang/DamonTask)

原理在于通过一个中间层管理类`TaskManager`来管理请求，一个`Task`对应一个`Observable`
```java
TaskManager.with(this)
            .task(new StringTask("1"), new StringTask("2"), new StringTask("3"))
            .start(new Consumer3<String, String, String>() {
                @Override
                public void accept(String s, String s2, String s3) throws Exception {
                    // print s
                }
            });
```

### kotlin层面

`kotlin`由于其语法特性，可以直接扩展`Observable`函数方法，所以实现起来更加流畅
[https://github.com/izyhang/RxCollection](https://github.com/izyhang/RxCollection)

通过针对`Observable`扩展函数`subscribeUnpack`实现脱离`zipper`
```kotlin
ObservableCollection.zip(
            Observable.just("1"),
            Observable.just(2),
            Observable.just(3L),
            Observable.just(4F)
    )
            .subscribeUnpack { s, i, l, fl ->
                println(s)
                println(i)
                println(l)
                println(fl)
            }

Observable.just("1")
            .zipWith(Observable.just(2F))
            .subscribeUnpack { s, fl ->
                println(s)
                println(fl)
            }
```
