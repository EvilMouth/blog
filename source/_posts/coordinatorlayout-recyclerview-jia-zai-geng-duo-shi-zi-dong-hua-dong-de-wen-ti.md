---
layout: post
title: CoordinatorLayout+RecyclerView加载更多时自动滑动的问题
date: 2018-06-15 16:34:17
tags:
 - coordinatorLayout
 - recyclerView
 - loadMore
 - scroll
categories: Android
---

记录一下`CoordinatorLayout`+`RecyclerView`组合联动时，滑到底部触发加载更多并通过`notifyItemRangeInserted`添加数据时，`RecyclerView`会顺着继续滑动的问题。

<!-- More -->

# 问题GIF

使用`CoordinatorLayout`联动`RecyclerView`的情况下（普通情况不会），加载更多是通过设置`多Type`的方式注入`adapter`实现的。当快速滑动`RecyclerView`时，通过`notifyItemRangeInserted`插入数据到尾部，则会发生下图所示的情况。

![1.gif](../assets/coordinatorlayout-recyclerview-jia-zai-geng-duo-shi-zi-dong-hua-dong-de-wen-ti/before.gif)

# 解决之路

## 焦点问题？

在大多数场景是没有使用`CoordinatorLayout`的，正常的使用`RecyclerView`是不会出现这种现象，所以一开始就觉得是`CoordinatorLayout`嵌套的焦点问题，焦点被`RecyclerView`抢夺导致自动滑动（Ps：以前见多了各种`ScrollView`嵌套的焦点问题）。所以给`CoordinatorLayout`做了焦点拦截，直接在布局文件设置属性
```xml
android:descendantFocusability="blocksDescendants"
```

> 但是并没有解决问题

之后试了半天布局修改，例如`android:focusable="true"
    android:focusableInTouchMode="true"`等都解决不了问题，只能上网搜搜了。。。

## positionStart？

搜到的第一个类似问题，附带个链接 -> [Link](https://stackoverflow.com/questions/27079899/android-notifyitemrangeinserted-disable-autoscroll/30455749)

这位码友也是遇到类似自动滑动的问题，也是添加数据后触发，只不过他的情况是他有个`多type`的头部，所以调用`notifyItemRangeInserted`时的`positionStart`得`+1`，这也提醒我们打代码的时候得多注意，很多神奇的bug都是这样来的。。。

> 也不是解决方案

## RecyclerView设计初衷？

再搜到一个类似问题，再附带链接 -> [Link](https://stackoverflow.com/questions/49016668/recyclerview-notifyitemrangeinserted-not-maintaining-scroll-position)

这次这位码友的情况跟我挺相似的，也是利用`多type`实现`footer`，利用这个`footer`实现加载更多的功能，同样插入数据会自动滑动。最佳回答是这样说的：

> 该码友在有`footer`的时候调用`notifyItemRangeInserted(0, list.size())`时，由于`footer`是唯一存在的第一条`item`，`RecyclerView`为了保持用户视觉体验、能继续看到`footer`，所以自动滑动到`footer`的位置。推荐该码友在`list.size() == 0`时候调用`notifyDataSetChanged()`代替

> 这一现象确实存在，也是平时需要注意的点，但也不是这次的解决方案

## 解决！！！

再之后找不到相关的问题了，也是自己看了下`RecyclerView`的源码，找到了个方法

> recyclerview.stopScroll()

所以最后也是投机取巧的暂时解决这个问题，在插入数据之前停止滚动
（暂时无法从`NestedScroll`联动滑动机制解决这个问题，如果有大佬知道这个问题解决方案恳请告知一声，下方评论或Email我都可以，谢谢）

```java
recyclerview.stopScroll();
adapter.addList(list);

public void addList(List<Object> list) {
    final int index = mList.size();
    mList.addAll(list);
    notifyItemRangeInserted(index, list.size());
}
```

![](../assets/coordinatorlayout-recyclerview-jia-zai-geng-duo-shi-zi-dong-hua-dong-de-wen-ti/after.gif)