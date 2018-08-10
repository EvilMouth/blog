---
layout: post
title: 为SeekBar添加滑动跟随气泡
date: 2017-08-09 16:44:02
tags: seekBar
categories: Android
---

最近的项目需要做聊天语音消息，自然是用`SeekBar`实现进度条，这个倒不难，播放拖动进度等功能。但是设计师要拖动进度的同时`thumb`上方显示一个气泡显示秒数，效果如下
![](http://images.zyhang.com/17-8-9/68316050.jpg)

毕竟`SeekBar`没提供这个功能，所以首先想到的是自定义`View`，然后重写`onTouch`滑动显示气泡，气泡也属于自定义`View`里面，但是这样有个问题，由于气泡包在自定义`View`里面，所以控件高度不会是设计师要的效果，所以想到了`Window`。跟`Dialog`、`Toast`类似。

<!-- More -->

首先实现气泡，原理是在需要的时候向`WindowManager`请求添加一个`View`到窗口并及时更新气泡的位置
``` java
WindowManager windowManager = (WindowManager) context.getSystemService(Context.WINDOW_SERVICE);
WindowManager.LayoutParams layoutParams = new WindowManager.LayoutParams();
layoutParams = new WindowManager.LayoutParams();
layoutParams.gravity = Gravity.START | Gravity.TOP;
layoutParams.width = ViewGroup.LayoutParams.WRAP_CONTENT;
layoutParams.height = ViewGroup.LayoutParams.WRAP_CONTENT;
layoutParams.format = PixelFormat.TRANSLUCENT;
layoutParams.flags = WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL |
        WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE |
        WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED;
if (XiaoMiUtils.isMIUI() || Build.VERSION.SDK_INT >= Build.VERSION_CODES.N_MR1){
    layoutParams.type = WindowManager.LayoutParams.TYPE_APPLICATION;
} else {
    layoutParams.type = WindowManager.LayoutParams.TYPE_TOAST;
}
```

>FLAG_NOT_TOUCH_MODAL : 当前Window区域以外的单击事件传递给底层Window，不拦截，一般需要开启此标记
>FLAG_NOT_FOCUSABLE : 不需要获取焦点
>FLAG_SHOW_WHEN_LOCKED : 显示在锁屏上
>XiaoMiUtils.isMIUI() : 由于小米对TYPE_TOAST管制比较严，在有些小米手机会显示不了

并在适当的时候调用
``` java
windowManager.addView(bubbleView, layoutParams);
windowManager.updateViewLayout(bubbleView, layoutParams);
windowManager.removeViewImmediate(bubbleView);
```

最难的部分气泡的显示其实一点也不难，在适当的时候也就是`onTouch`的事件处理时调用而已，这样气泡功能就实现了。

### 但是

哈哈，自定义`View`不是我想要的，这样做侵入性很强，说不定以后设计师改了个样式就麻烦了，所以就要改到`SeekBar`。既然这样干脆不要自定义`View`，我就想到了`SeekBar`本身提供的`setOnSeekBarChangeListener`，里面有三个回调
``` java
public interface OnSeekBarChangeListener {
        void onProgressChanged(SeekBar var1, int var2, boolean var3);

        void onStartTrackingTouch(SeekBar var1);

        void onStopTrackingTouch(SeekBar var1);
    }
```
简直完美符合我的思路，在`onStartTrackingTouch`的时候`addView`，在`onStopTrackingTouch`的时候`removeViewImmediate`，在滑动过程中，也就是`onProgressChanged`的时候`updateViewLayout`更新气泡位置，这样做完全不会影响到项目原有的代码，只需要注入气泡显示的代码即可。

于是有了下面的`Delegate`
``` java
public class SeekBarBubbleDelegate implements SeekBar.OnSeekBarChangeListener {

    /**
     * 气泡
     */
    private View mBubble;
    private boolean mIsDragging;
    private WindowManager mWindowManager;
    private WindowManager.LayoutParams mLayoutParams;
    /**
     * 气泡移动范围
     */
    private Rect mRect;
    /**
     * 状态栏高度
     */
    private int mStatusBarHeight;
    private List<SeekBar.OnSeekBarChangeListener> mListeners;

    public SeekBarBubbleDelegate(Context context, View bubble) {
        mBubble = bubble;
        mBubble.setVisibility(View.INVISIBLE);

        mIsDragging = false;

        mWindowManager = (WindowManager) context.getSystemService(Context.WINDOW_SERVICE);

        mLayoutParams = new WindowManager.LayoutParams();
        mLayoutParams.gravity = Gravity.START | Gravity.TOP;
        mLayoutParams.width = ViewGroup.LayoutParams.WRAP_CONTENT;
        mLayoutParams.height = ViewGroup.LayoutParams.WRAP_CONTENT;
        mLayoutParams.format = PixelFormat.TRANSLUCENT;
        mLayoutParams.flags = WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL |
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE |
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED;
        if (XiaoMiUtils.isMIUI() || Build.VERSION.SDK_INT >= Build.VERSION_CODES.N_MR1) {
            mLayoutParams.type = WindowManager.LayoutParams.TYPE_APPLICATION;
        } else {
            mLayoutParams.type = WindowManager.LayoutParams.TYPE_TOAST;
        }

        mRect = new Rect();

        mStatusBarHeight = getStatusBarHeight();

        mListeners = new ArrayList<>();
    }

    @Override
    public void onProgressChanged(SeekBar seekBar, int progress, boolean fromUser) {
        int bubbleWidth = mBubble.getWidth();
        if (mIsDragging && bubbleWidth > 0) {
            float x = mRect.left + ((float) mRect.width() / seekBar.getMax() * progress) - (bubbleWidth / 2);
            mLayoutParams.x = (int) x;
            mLayoutParams.y = mRect.top - mStatusBarHeight - mBubble.getHeight();

            //更新气泡位置
            mWindowManager.updateViewLayout(mBubble, mLayoutParams);
            mBubble.setVisibility(View.VISIBLE);
        }

        for (SeekBar.OnSeekBarChangeListener listener : mListeners) {
            listener.onProgressChanged(seekBar, progress, fromUser);
        }
    }

    @Override
    public void onStartTrackingTouch(SeekBar seekBar) {
        mIsDragging = true;
        //获取整个SeekBar在屏幕的位置
        seekBar.getGlobalVisibleRect(mRect);
        //重复赋值left right为气泡移动范围
        int offset = seekBar.getThumb().getIntrinsicWidth() / 2 - seekBar.getThumbOffset();
        mRect.left = mRect.left + seekBar.getPaddingLeft() + offset;
        mRect.right = mRect.right - seekBar.getPaddingRight() - offset;
        //将气泡加入window
        mWindowManager.addView(mBubble, mLayoutParams);

        for (SeekBar.OnSeekBarChangeListener listener : mListeners) {
            listener.onStartTrackingTouch(seekBar);
        }
    }

    @Override
    public void onStopTrackingTouch(SeekBar seekBar) {
        mIsDragging = false;
        removeBubble();

        for (SeekBar.OnSeekBarChangeListener listener : mListeners) {
            listener.onStopTrackingTouch(seekBar);
        }
    }

    public View getBubble() {
        return mBubble;
    }

    public boolean isDragging() {
        return mIsDragging;
    }

    private int getStatusBarHeight() {
        int height = 0;
        try {
            Resources resources = Resources.getSystem();
            height = resources.getDimensionPixelSize(resources.getIdentifier("status_bar_height", "dimen", "android"));
        } catch (Exception e) {
            e.printStackTrace();
        }
        return height;
    }

    public void addOnSeekBarChangeListener(SeekBar.OnSeekBarChangeListener l) {
        mListeners.add(l);
    }

    public void removeOnSeekBarChangeListener(SeekBar.OnSeekBarChangeListener l) {
        mListeners.remove(l);
    }

    public void clearOnSeekBarChangeListener() {
        mListeners.clear();
    }

    public void removeBubble() {
        try {
            mWindowManager.removeViewImmediate(mBubble);
        } catch (Exception e) {
            //do nothing
        }
    }
}
```

>onProgressChanged下拿到progress进度去计算从而更新气泡位置

使用方法极其简单，给`SeekBar`设置监听并交给`delegate`管理即可
``` java
SeekBarBubbleDelegate delegate = new SeekBarBubbleDelegate(context, bubbleView);
seekBar.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() {
            @Override
            public void onProgressChanged(SeekBar seekBar, int progress, boolean fromUser) {
                delegate.onProgressChanged(seekBar, progress, fromUser);
            }

            @Override
            public void onStartTrackingTouch(SeekBar seekBar) {
                delegate.onStartTrackingTouch(seekBar);
            }

            @Override
            public void onStopTrackingTouch(SeekBar seekBar) {
                delegate.onStopTrackingTouch(seekBar);
            }
        });
```

### 项目地址
[https://github.com/izyhang/SeekBarBubble](https://github.com/izyhang/SeekBarBubble)
