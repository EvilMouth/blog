---
layout: post
title: AndroidX TabLayout点击效果兼容问题
date: 2018-10-24 14:08:49
tags: tabLayout
categories: Android
---

近期升级了一波`AndroidX`，发现原先取消掉的`TabLayout`点击阴影效果又出现了，以为是改了主题遍翻了翻`git`改动，发现并没有可疑的修改导致，最后在源码里面发现真凶！

<!-- More -->

## 0x00 support-27.1.1

此前`TabLayout`的点击效果是通过设置`app:tabBackground="@android:color/transparent"`进行取消

## 0x01 support-28.0.0

升级到28.0.0后`TabLayout`加多了一个属性`app:tabRippleColor`，查看源码可知

``` java
this.tabBackgroundResId = a.getResourceId(styleable.TabLayout_tabBackground, 0);
this.tabRippleColorStateList = MaterialResources.getColorStateList(context, a, styleable.TabLayout_tabRippleColor);

private void updateBackgroundDrawable(Context context) {
    if (TabLayout.this.tabBackgroundResId != 0) {
        this.baseBackgroundDrawable = AppCompatResources.getDrawable(context, TabLayout.this.tabBackgroundResId);
        if (this.baseBackgroundDrawable != null && this.baseBackgroundDrawable.isStateful()) {
            this.baseBackgroundDrawable.setState(this.getDrawableState());
        }
    } else {
        this.baseBackgroundDrawable = null;
    }
    Drawable contentDrawable = new GradientDrawable();
    ((GradientDrawable)contentDrawable).setColor(0);
    Object background;
    if (TabLayout.this.tabRippleColorStateList != null) {
        GradientDrawable maskDrawable = new GradientDrawable();
        maskDrawable.setCornerRadius(1.0E-5F);
        maskDrawable.setColor(-1);
        ColorStateList rippleColor = RippleUtils.convertToRippleDrawableColor(TabLayout.this.tabRippleColorStateList);
        if (VERSION.SDK_INT >= 21) {
            background = new RippleDrawable(rippleColor, TabLayout.this.unboundedRipple ? null : contentDrawable, TabLayout.this.unboundedRipple ? null : maskDrawable);
        } else {
            Drawable rippleDrawable = DrawableCompat.wrap(maskDrawable);
            DrawableCompat.setTintList(rippleDrawable, rippleColor);
            background = new LayerDrawable(new Drawable[]{contentDrawable, rippleDrawable});
        }
    } else {
        background = contentDrawable;
    }
    ViewCompat.setBackground(this, (Drawable)background);
    TabLayout.this.invalidate();
}
```

`TabView`的`background`根据`tabRippleColorStateList`去包装从而实现点击效果，只要让`tabRippleColorStateList = null`即可取消，其中的`unboundedRipple`是设置水波纹效果的开关

## 0x03 兼容与结论

- 通过设置`app:tabRippleColor="@android:color/transparent"`或者`TabLayout.setTabRippleColor(null);`即可取消点击阴影效果
- 由于`AndroidX`基于`28.0.0`，所以出现兼容问题