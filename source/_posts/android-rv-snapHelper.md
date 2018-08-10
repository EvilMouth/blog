---
layout: post
title: 使用SnapHelper帮助RecyclerView滑动停留
date: 2017-02-13 15:22:04
tags: recyclerView
categories: Android
---

现在做项目早已抛弃`ListView`而选择`RecyclerView`，而且使用`RecyclerView`起来也已经得心应手，但是`RecyclerView`有很多隐藏功能比较少用到，比如接下来的`SnapHelper`

<!-- More -->

偷偷截下Google Play的图
![](http://images.zyhang.com/17-2-23/16894468-file_1487829796199_12e18.png)
如上图所示，上面的banner就是中对齐的效果，下面的游戏列表就是左对齐的效果

官网support包提供了`SnapHelper`帮助实现这样的效果
``` java
public abstract class SnapHelper extends RecyclerView.OnFlingListener
```

使用方法很简单，官方已经帮我们实现了一个`LinearSnapHelper`供我们直接使用，运行后是中对齐的效果
``` java
SnapHelper snapHelper = new LinearSnapHelper();
snapHelper.attachToRecyclerView(recyclerview);
```

官方没有提供左对齐，想要左对齐需要自己动手，继承`LinearSnapHelper`并重写`calculateDistanceToFinalSnap`和`findSnapView`方法
``` java
public class FirstItemSnapHelper extends LinearSnapHelper {
    private OrientationHelper mVerticalHelper, mHorizontalHelper;

    /**
     * 计算移动距离
     */
    @Override
    public int[] calculateDistanceToFinalSnap(@NonNull RecyclerView.LayoutManager layoutManager, @NonNull View targetView) {
        int[] out = new int[2];

        //如果是水平滑动，计算x偏移量
        if (layoutManager.canScrollHorizontally()) {
            out[0] = distanceToStart(targetView, getHorizontalHelper(layoutManager));
        } else {
            out[0] = 0;
        }

        //如果是垂直滑动，计算y偏移量
        if (layoutManager.canScrollVertically()) {
            out[1] = distanceToStart(targetView, getVerticalHelper(layoutManager));
        } else {
            out[1] = 0;
        }

        return out;
    }

    /**
     * 寻找需要移动的item
     */
    @Override
    public View findSnapView(RecyclerView.LayoutManager layoutManager) {
        if (layoutManager instanceof LinearLayoutManager) {
            if (layoutManager.canScrollHorizontally()) {
                return getStartView(layoutManager, getHorizontalHelper(layoutManager));
            } else {
                return getStartView(layoutManager, getVerticalHelper(layoutManager));
            }
        }

        //返回null以不进行偏移移动
        return null;
    }

    private int distanceToStart(View targetView, OrientationHelper helper) {
        return helper.getDecoratedStart(targetView) - helper.getStartAfterPadding();
    }

    private View getStartView(RecyclerView.LayoutManager layoutManager, OrientationHelper helper) {
        if (layoutManager instanceof LinearLayoutManager && layoutManager.getItemCount() > 0) {
            //出于对item宽度或高度不够大的考虑，故需要判断是否滑动最后一个item了，否则可能会导致永远会滑不到最后
            boolean isLastItem = ((LinearLayoutManager) layoutManager).findLastCompletelyVisibleItemPosition() == layoutManager.getItemCount() - 1;
            if (isLastItem) {
                return null;
            }

            //因为是要对齐第一个item，所以这里找到使用findFirstVisibleItemPosition
            int firstChild = ((LinearLayoutManager) layoutManager).findFirstVisibleItemPosition();
            View child = layoutManager.findViewByPosition(firstChild);

            //根据该item的右坐标比对该item的一半（宽度或高度）返回最终的SnapView
            if (helper.getDecoratedEnd(child) > 0 && helper.getDecoratedEnd(child) >= helper.getDecoratedMeasurement(child) / 2) {
                return child;
            } else {
                return layoutManager.findViewByPosition(firstChild + 1);
            }
        }

        //返回null以不进行偏移移动
        return null;
    }

    private OrientationHelper getVerticalHelper(RecyclerView.LayoutManager layoutManager) {
        if (mVerticalHelper == null) {
            mVerticalHelper = OrientationHelper.createVerticalHelper(layoutManager);
        }
        return mVerticalHelper;
    }

    private OrientationHelper getHorizontalHelper(RecyclerView.LayoutManager layoutManager) {
        if (mHorizontalHelper == null) {
            mHorizontalHelper = OrientationHelper.createHorizontalHelper(layoutManager);
        }
        return mHorizontalHelper;
    }
}
```
使用方法也是去`attachToRecyclerView`，最终实现左对齐的效果

##### 使用注意
`SnapHelper`一般项目需要都是用于水平列表，但其实`SnapHelper`同样适用于垂直列表，需要注意的一点是，`SnapHelper`具体原理是根据判断哪个item到达指定位置的偏差小而去滑动的，当item的宽度或高度不够大的情况下（需要尽可能大于半屏），滑动到最后一个item会因为偏差不够前一个item大而导致选择了前一个item去移动。官方提供的`LinearSnapHelper`就是这样，如果item宽度不够大，会出现的情况是当滑动最后一松手，会判定倒数第二个item偏差小而选择倒数第二个item为`SnapView`去滑动到中间，导致最后一个item永远无法显示全。而本文提供的`FirstItemSnapHelper`虽然有相关处理是否到达最后一个item，当也许不是适合每个需求，具体还得根据需求去修改。
