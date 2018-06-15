---
layout: post
title: CoordinatorLayout+RecyclerView加载更多时自动滑动的问题
date: 2018-06-15 16:34:17
tags: learn
categories: Android
---

记录一下`CoordinatorLayout`+`RecyclerView`组合联动时，滑到底部触发加载更多并通过`notifyItemRangeInserted`添加数据时，`RecyclerView`会顺着继续滑动的问题。

<!-- More -->

## 问题GIF

使用`CoordinatorLayout`联动`RecyclerView`的情况下（普通情况不会），加载更多是通过设置`多Type`的方式注入`adapter`实现的。当快速滑动`RecyclerView`时，通过`notifyItemRangeInserted`插入数据到尾部，则会发生下图所示的情况。

![1.gif](../assets/coordinatorlayout-recyclerview-jia-zai-geng-duo-shi-zi-dong-hua-dong-de-wen-ti/before.gif)

## 解决



## 最后

最后是投机取巧的方法解决这个问题，在插入数据之前停止滚动
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