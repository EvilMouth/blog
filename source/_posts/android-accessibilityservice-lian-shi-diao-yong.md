---
layout: post
title: Android AccessibilityService - 链式结构
date: 2018-08-27 15:50:53
tags: accessibilityService
categories: Android
---

提供一种链式结构AccessibilityService的方案，相比于正常使用AccessibilityService，有着几大优点：结构清晰、调用链一目了然、方便调试等

<!-- More -->

## 0x00 AccessibilityService

最原始的写法，就是在`onAccessibilityEvent(AccessibilityEvent)`回调中根据`eventType`处理相应的动作
``` java
@Override
public void onAccessibilityEvent(AccessibilityEvent event) {
    switch (event.getEventType()) {
        case AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED:
            break;
        case AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED:
            break;
        case AccessibilityEvent.TYPE_NOTIFICATION_STATE_CHANGED:
            break;
    }
}
```

> 处理界面越来越多的时候这里的逻辑就会越来越复杂，维护和调试的难度大大提升

## 0x01 引入链式概念

引入了`Situation`概念，将每种变化通过链式结构连接起来，只需要关心 **当前变化的判定**、**当前变化的处理**、**下一步变化的预判**

``` java
Situation.java

public interface Situation {
    // 定义eventType 支持多种
    // 例如
    // TYPE_NOTIFICATION_STATE_CHANGED | TYPE_WINDOW_STATE_CHANGED
    int eventTypes();

    // 判定当前变化是否匹配
    boolean match(@NonNull AccessibilityService accessibilityService, @NonNull AccessibilityEvent accessibilityEvent);

    // 匹配 -> 执行任务
    boolean execute(@NonNull AccessibilityService accessibilityService, @NonNull AccessibilityEvent accessibilityEvent);

    // 设定下一步 支持多种
    Situation[] nextSituations();
}
```

> 继承`LinkedAccessibilityService`创建辅助服务
> 实现`Situation`创建步骤

## 0x02 例子

简单的微信抢红包例子
[https://github.com/izyhang/LinkedAccessibilityService/blob/master/example/src/main/java/com/zyhang/linkedaccessibilityservice/example/AccessibilityServiceExample.kt](https://github.com/izyhang/LinkedAccessibilityService/blob/master/example/src/main/java/com/zyhang/linkedaccessibilityservice/example/AccessibilityServiceExample.kt)
