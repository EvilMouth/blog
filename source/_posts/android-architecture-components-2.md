---
layout: post
title: Android Architecture Components分析记录（二）
date: 2017-08-16 10:38:02
tags: aac
categories: Android
---

记录分析`AAC`第二篇---`LiveData`，官方地址
[https://developer.android.com/topic/libraries/architecture/livedata.html?hl=zh-cn](https://developer.android.com/topic/libraries/architecture/livedata.html?hl=zh-cn)

<!-- More -->

# LiveData

`LiveData`是一个数据持有类并赋予数据`Observer`属性，使用`LiveData`能够在有观察者的时候触发获取请求，并在生命周期符合`OnStart`状态条件下通知观察者数据变化，所以官方很吊的说明下面几点
- No memory leaks
- No crashes due to stopped activities
- Always up to date data
- Proper configuration change
- Sharing Resources
- No more manual lifecycle handling

## 使用

比如最常用的`UserInfo`
``` java
public class UserInfoLiveData extends LiveData<UserInfo> {
    //当有观察者观察时会触发onActive
    @Override
    protected void onActive() {
        super.onActive();
        //假设获取UserInfo并返回
        UserInfo userInfo = getUserInfo();
        setValue(userInfo);
    }
}
```

在`Activity`添加观察代码
``` java
@Override
protected void onCreate(@Nullable Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);
    UserInfoLiveData userInfoLiveData = new UserInfoLiveData();
    userInfoLiveData.observe(this, new Observer<UserInfo> {
        @Override
        public void onChanged(@Nullable UserInfo userInfo) {
            //此方法会在LiveData的setValue被调用
            //在这里更新UI
        }
    });
}
```

## 分析
进入正题，这次从`LiveData`的`observe`方法开始追寻，看看发生了什么

### observe(LifecycleOwner, Observer<T>)
``` java
private SafeIterableMap<Observer<T>, LifecycleBoundObserver> mObservers =
            new SafeIterableMap<>();
@MainThread
    public void observe(LifecycleOwner owner, Observer<T> observer) {
        if (owner.getLifecycle().getCurrentState() == DESTROYED) {
            // ignore
            return;
        }
        LifecycleBoundObserver wrapper = new LifecycleBoundObserver(owner, observer);
        LifecycleBoundObserver existing = mObservers.putIfAbsent(observer, wrapper);
        if (existing != null && existing.owner != wrapper.owner) {
            throw new IllegalArgumentException("Cannot add the same observer"
                    + " with different lifecycles");
        }
        if (existing != null) {
            return;
        }
        owner.getLifecycle().addObserver(wrapper);
        wrapper.activeStateChanged(isActiveState(owner.getLifecycle().getCurrentState()));
    }
```
这个`observe`方法源码上面一堆密密麻麻的注释，大概重点就是当数据有变化的时候就会通知观察者。
首先不用多说，确定下当前生命周期的状态，不满足条件就`return`，之后将传进来的`owner`和`observer``new`了个`LifecycleBoundObserver`，先不管。然后通过`mObservers`从`Map`中看看有没有相同的`LifecycleBoundObserver`，根据`Observer`为`key`去查找，如果存在也`retuen`。这里注意官方不允许同个`Observer`添加到不同的`owner`。接着调用`owner.getLifecycle().addObserver(wrapper);`。。。看来这个`LifecycleBoundObserver`也是实现了`LifecycleObserver`(至于这个点可以看第一篇)。最后调用`LifecycleBoundObserver`的`activeStateChanged`方法，具体实现刚好跟刚才不管的一起分析

### LifecycleBoundObserver
``` java
class LifecycleBoundObserver implements LifecycleObserver {
        public final LifecycleOwner owner;
        public final Observer<T> observer;
        public boolean active;
        public int lastVersion = START_VERSION;

        LifecycleBoundObserver(LifecycleOwner owner, Observer<T> observer) {
            this.owner = owner;
            this.observer = observer;
        }

        @SuppressWarnings("unused")
        @OnLifecycleEvent(Lifecycle.Event.ON_ANY)
        void onStateChange() {
            if (owner.getLifecycle().getCurrentState() == DESTROYED) {
                removeObserver(observer);
                return;
            }
            // immediately set active state, so we'd never dispatch anything to inactive
            // owner
            activeStateChanged(isActiveState(owner.getLifecycle().getCurrentState()));

        }

        void activeStateChanged(boolean newActive) {
            if (newActive == active) {
                return;
            }
            active = newActive;
            boolean wasInactive = LiveData.this.mActiveCount == 0;
            LiveData.this.mActiveCount += active ? 1 : -1;
            if (wasInactive && active) {
                onActive();
            }
            if (LiveData.this.mActiveCount == 0 && !active) {
                onInactive();
            }
            if (active) {
                dispatchingValue(this);
            }
        }
    }
```
刚才在`observe`方法内实例化时传进来的`owner`和`observer`只是赋值了一下内部变量。其次`owner.getLifecycle().addObserver(wrapper);`意味着`onStateChange()`能够接收生命周期的变化通知，果不其然`onStateChange`中调用了
`activeStateChanged(isActiveState(owner.getLifecycle().getCurrentState()));`。

> isActiveState() 返回 boolean -> 当前生命周期状态是否至少处于START状态之后

`activeStateChanged`方法会根据传进来的`newActive`状态去调用`onActive()`或者`onInactive()`，也就是当有观察者主动观察时会调用`onActive()`进行数据获取请求，并在请求数据成功后手动调用`setValue(T)`通知观察者数据变化。`setValue(T)`内调用`dispatchingValue()`方法最后回调`onChanged(T)`通知观察者数据变化从而更新UI。

一句句理解
``` java
//当有观察者观察的时候或者生命周期变化的时候会调用此方法
//newActive : 当前生命周期是否START状态之后
void activeStateChanged(boolean newActive) {
    //如果新状态与当前状态一致则return
    if (newActive == active) {
        return;
    }

    //标明当前是否处于激活状态
    active = newActive;

    //mActiveCount是有多少个观察者在观察
    //所以wasInactive表示在这之前的观察者数
    boolean wasInactive = LiveData.this.mActiveCount == 0;

    //相应的+-1
    LiveData.this.mActiveCount += active ? 1 : -1;

    //如果是第一个观察并且激活状态则回调onActive()去获取数据
    if (wasInactive && active) {
        onActive();
    }

    //对应的取消绑定
    if (LiveData.this.mActiveCount == 0 && !active) {
        onInactive();
    }

    //下发数据变化 会回调onChanged(T)
    if (active) {
        dispatchingValue(this);
    }
}
```

### dispatchingValue(LifecycleBoundObserver)
下面看`dispatchingValue()`
``` java
private void dispatchingValue(@Nullable LifecycleBoundObserver initiator) {
        if (mDispatchingValue) {
            mDispatchInvalidated = true;
            return;
        }
        mDispatchingValue = true;
        do {
            mDispatchInvalidated = false;
            if (initiator != null) {
                considerNotify(initiator);
                initiator = null;
            } else {
                for (Iterator<Map.Entry<Observer<T>, LifecycleBoundObserver>> iterator =
                        mObservers.iteratorWithAdditions(); iterator.hasNext(); ) {
                    considerNotify(iterator.next().getValue());
                    if (mDispatchInvalidated) {
                        break;
                    }
                }
            }
        } while (mDispatchInvalidated);
        mDispatchingValue = false;
    }
```
这个方法的逻辑判断主要依赖于两个`boolean`:`mDispatchingValue`和`mDispatchInvalidated`。看完源码后感觉很巧妙，利用两个变量分发数据的变化通知观察者更新UI，并当有新的数据变化的时候`break`循环，减少了一次旧数据不必要的UI更新，很`nice`，点个赞。

### mVersion
`LiveData`内部维护了一个变量`mVersion`数据版本控制，计算数据变化次数，并在`dispatchingValue()`下发中与观察者的内部计数`version`判断从而调用`onChanged(T)`。

## 额外用法
`LiveData`还有两个很有用的`API`
 - observeForever(Observer<T> observer)
 ``` java
 @MainThread
     public void observeForever(Observer<T> observer) {
         observe(ALWAYS_ON, observer);
     }
 ```
 `ALWAYS_ON`也是一个`LifecycleOwner`，但是永远处于`RESUME`状态下，也就是使用这个方法的观察者将永远接收到数据变化，无论生命周期的影响，所以在适当的时候需要开发者手动调用`removeObserver(Observer)`取消观察。
 - postValue(T value)
 ``` java
 protected void postValue(T value) {
         boolean postTask;
         synchronized (mDataLock) {
             postTask = mPendingData == NOT_SET;
             mPendingData = value;
         }
         if (!postTask) {
             return;
         }
         AppToolkitTaskExecutor.getInstance().postToMainThread(mPostValueRunnable);
     }
 ```
 与`setValue(T)`不同的`postValue(T)`允许在其它线程调用

# Transformations of LiveData

官方提供`Transformations`工具帮助方便的转换`LiveData`并且依旧拥有`被转换者`的数据变化通知。下面给个🌰

> map(LiveData<X> source, final Function<X, Y> func)
> switchMap(LiveData<X> trigger, final Function<X, LiveData<Y>> func)

``` java
LiveData<String> stringLiveData = Transformations.map(userInfoLiveData, new Function<UserInfo, String>() {
            @Override
            public String apply(UserInfo input) {
                return input.getName();
            }
        });
        stringLiveData.observe(this, new Observer<String>() {
            @Override
            public void onChanged(@Nullable String s) {
                Log.i(TAG, "onChanged: s === " + s);
            }
        });
```
`stringLiveData`通过`Transformations.map()`方法实例化，在`apply(UserInfo input)`中取出需要的`String`数据返回，最后同样的`observe`一下，将会拥有的功能即：当`userInfo`数据改变，同样会通知此`LiveData`的观察者即回调`onChanged(T)`。

## 分析

官方提供这个转换`API`的原因是开发者可能需要在数据变化发送给观察者之前对数据进行改变等操作，这样的确会方便很多。那么开始看源码吧~

``` java
@MainThread
    public static <X, Y> LiveData<Y> map(LiveData<X> source, final Function<X, Y> func) {
        final MediatorLiveData<Y> result = new MediatorLiveData<>();
        result.addSource(source, new Observer<X>() {
            @Override
            public void onChanged(@Nullable X x) {
                result.setValue(func.apply(x));
            }
        });
        return result;
    }
```
先看`map()`，这里面涉及到三个`Observer`，可能会有点绕。首先一进来就实例了一个`MediatorLiveData<Y>`，也是一个`LiveData`，`map()`返回的就是这个家伙。返回之前调用了`addSource()`传入了第一个`Observer`。`map()`方法的第二个参数`Function`就是在这里被回调。接着看`addSource()`

``` java
private SafeIterableMap<LiveData<?>, Source<?>> mSources = new SafeIterableMap<>();
@MainThread
    public <S> void addSource(LiveData<S> source, Observer<S> onChanged) {
        Source<S> e = new Source<>(source, onChanged);
        Source<?> existing = mSources.putIfAbsent(source, e);
        if (existing != null && existing.mObserver != onChanged) {
            throw new IllegalArgumentException(
                    "This source was already added with the different observer");
        }
        if (existing != null) {
            return;
        }
        if (hasActiveObservers()) {
            e.plug();
        }
    }
```
看起来似曾相识，`LiveData.observe()`的逻辑跟这个方法的逻辑差不多一个样，原理都是一样的。这里实例化了一个`Source`，主要是为了保存一下数据变化的`version`，好判断通知观察者的时机。
这里有个`hasActiveObservers()`的判断，判断是否有观察者观察，有的话执行`plug()`，那么看向`Source`

``` java
private static class Source<V> {
        final LiveData<V> mLiveData;
        final Observer<V> mObserver;
        int mVersion = START_VERSION;

        Source(LiveData<V> liveData, final Observer<V> observer) {
            mLiveData = liveData;
            mObserver = new Observer<V>() {
                @Override
                public void onChanged(@Nullable V v) {
                    if (mVersion != mLiveData.getVersion()) {
                        mVersion = mLiveData.getVersion();
                        observer.onChanged(v);
                    }
                }
            };
        }

        void plug() {
            mLiveData.observeForever(mObserver);
        }

        void unplug() {
            mLiveData.removeObserver(mObserver);
        }
    }
```
`plug()`和`unplug()`不必多说，标准的注册取消注册步骤。看看构造函数里面又来了个`Observer`，也就是第二个`Observer`，在回调函数`onChanged`里判断了下`version`，前后不一致的话手动调用`observer.onChanged(v);`，也就是第一个`observer`。有点绕了0 0

那么第三个`Observer`在哪里呢，其实就是一开始通过`map()`转换得来的`LiveData`:`stringLiveData`进行观察的`observer`。具体流程如下
1.通过`map()`转换拿到`MediatorLiveData`
2.调用`observe()`对转换来的`MediatorLiveData`进行观察
3.生命周期到达`START`后会自动调用`onActive()`
4.`MediatorLiveData.onActive()`会遍历调用`plug()`
5.`plug()`中对`源LiveData`调用`observe()`观察
6.`源LiveData`回调`onChanged()`即`Source`中的`observer`(第二个`observer`)
7.继续回调第一个`onChanged()`也就是`Transformations.map()`中的`Observer`
8.`result.setValue(func.apply(x));`
9.最终回调第三个`onChanged()`：开发者自己的`observer`从而更新UI

有点累，饶了半天，不过终于知道为何源数据发生数据变化时，`新LiveData`也能及时响应的原因。

至于`switchMap()`更粗暴更自由化，内部还会自动判断前后`LiveData`的不同自动取消观察等等，所以开发者不需要担心内存泄露的问题。

# 总结
`LiveData`的用法还是挺方便的，内部帮助持有需要的数据，并使用`观察者模式`对数据变化进行观察，并拥有生命周期的特效，所以不用担心内存泄露等问题。
对于像官方提供的例子中的`Location`或者开发项目中最常见的`UserInfo`，甚至可以用`static`修饰`LiveData`使其可以供应给所有需要的地方。
