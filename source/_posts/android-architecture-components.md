---
layout: post
title: Android Architecture Components分析记录（一）
date: 2017-08-10 10:26:59
tags: aac
categories: Android
---

记录一下分析`Google`出品的`AAC`库(ps:不是音频)，下面是官方地址
[https://developer.android.com/topic/libraries/architecture/index.html?hl=zh-cn](https://developer.android.com/topic/libraries/architecture/index.html?hl=zh-cn)

<!-- More -->

# Lifecycles
## 使用

这是一个用于管理`UI`组件生命周期和处理数据持久化的库，要使用这个库，需要手动拉下依赖
``` java
allprojects {
    repositories {
        jcenter()
        maven { url 'https://maven.google.com' }
    }
}

//For Lifecycles, LiveData, and ViewModel
compile 'android.arch.lifecycle:runtime:1.0.0-alpha5'
compile 'android.arch.lifecycle:extensions:1.0.0-alpha5'
annotationProcessor 'android.arch.lifecycle:compiler:1.0.0-alpha5'
```

>运行发现这三句都要添加

首先说下`Lifecycles`这块，这一模块旨在帮助没有生命周期的类能够方便的监听生命周期的变化，从而减少内存泄露的出现，使用的方法非常简单，官方提供了`LifecycleRegistryOwner`接口可以让你的`Activity`或者`Fragment`实现，其后实例化`LifecycleRegistry`即可
``` java
public class YourActivity extends AppCompatActivity implements LifecycleRegistryOwner {
    private LifecycleRegistry mLifecycleRegistry = new LifecycleRegistry(this);

    @Override
    public LifecycleRegistry getLifecycle() {
        return mLifecycleRegistry;
    }
}
```

之后则新建一个`Observer`（没有生命周期的类）去继承`LifecycleObserver`，并使用`@OnLifecycleEvent`注解方法指定需要监听的生命周期
``` java
public class YourObserver implements LifecycleObserver {

    private static final String TAG = "YourObserver";

    @OnLifecycleEvent(Lifecycle.Event.ON_ANY)
    public void onAny(LifecycleOwner owner, Lifecycle.Event event) {
        Log.i(TAG, "onAny: owner === " + owner + " event === " + event);
    }

    @OnLifecycleEvent(Lifecycle.Event.ON_RESUME)
    public void onResume() {
        Log.i(TAG, "onResume: ");
    }

    @OnLifecycleEvent(Lifecycle.Event.ON_PAUSE)
    public void onPause() {
        Log.i(TAG, "onPause: ");
    }
}
```

最后调用`LifecycleRegistry.addObserver()`进行绑定即可让`Observer`也获取相应的生命周期回调
``` java
getLifecycle().addObserver(new YourObserver());
```

## 分析

使用起来的确很简单，接下来就是开始分析，首先第一个问题是为什么`Observer`能够得到跟`Activity`一样的生命周期回调，先从`addObserver`读起
``` java
@Override
    public void addObserver(LifecycleObserver observer) {
        ObserverWithState observerWithState = new ObserverWithState(observer);
        mObserverSet.putIfAbsent(observer, observerWithState);
        observerWithState.sync();
    }
```

这里将`Observer`传进来之后会实例化一个`ObserverWithState`，然后放进一个`Map`保存起来，最后调用`sync`，先看看这个`ObserverWithState`
``` java
class ObserverWithState {
        private State mObserverCurrentState = INITIALIZED;
        private GenericLifecycleObserver mCallback;

        ObserverWithState(LifecycleObserver observer) {
            mCallback = Lifecycling.getCallback(observer);
        }

        void sync() {
            if (mState == DESTROYED && mObserverCurrentState == INITIALIZED) {
                mObserverCurrentState = DESTROYED;
            }
            while (mObserverCurrentState != mState) {
                Event event = mObserverCurrentState.isAtLeast(mState)
                        ? downEvent(mObserverCurrentState) : upEvent(mObserverCurrentState);
                mObserverCurrentState = getStateAfter(event);
                mCallback.onStateChanged(mLifecycleOwner, event);
            }
        }
    }
```

这个`GenericLifecycleObserver`是什么鬼，进去`Lifecycling`看下
``` java
@NonNull
    static GenericLifecycleObserver getCallback(Object object) {
        if (object instanceof GenericLifecycleObserver) {
            return (GenericLifecycleObserver) object;
        }
        //noinspection TryWithIdenticalCatches
        try {
            final Class<?> klass = object.getClass();
            Constructor<? extends GenericLifecycleObserver> cachedConstructor = sCallbackCache.get(
                    klass);
            if (cachedConstructor != null) {
                return cachedConstructor.newInstance(object);
            }
            cachedConstructor = getGeneratedAdapterConstructor(klass);
            if (cachedConstructor != null) {
                if (!cachedConstructor.isAccessible()) {
                    cachedConstructor.setAccessible(true);
                }
            } else {
                cachedConstructor = sREFLECTIVE;
            }
            sCallbackCache.put(klass, cachedConstructor);
            return cachedConstructor.newInstance(object);
        } catch (IllegalAccessException e) {
            throw new RuntimeException(e);
        } catch (InstantiationException e) {
            throw new RuntimeException(e);
        } catch (InvocationTargetException e) {
            throw new RuntimeException(e);
        }
    }
```

可以看出这里用了反射以`Observer`新建了个类`GenericLifecycleObserver`，这个类可以在`build/source`下找到
``` java
public class YourObserver_LifecycleAdapter implements GenericLifecycleObserver {
  final YourObserver mReceiver;

  YourObserver_LifecycleAdapter(YourObserver receiver) {
    this.mReceiver = receiver;
  }

  @Override
  public void onStateChanged(LifecycleOwner owner, Lifecycle.Event event) {
    mReceiver.onAny(owner,event);
    if (event == Lifecycle.Event.ON_RESUME) {
      mReceiver.onResume();
    }
    if (event == Lifecycle.Event.ON_PAUSE) {
      mReceiver.onPause();
    }
  }

  public Object getReceiver() {
    return mReceiver;
  }
}
```

看到`onStateChanged`方法下是实现就反应过来`YourObserver`的方法会响应生命周期的变化就是这里被调用的，所以继续看哪里调用了`onStateChanged`
``` java
void sync() {
            if (mState == DESTROYED && mObserverCurrentState == INITIALIZED) {
                mObserverCurrentState = DESTROYED;
            }
            while (mObserverCurrentState != mState) {
                Event event = mObserverCurrentState.isAtLeast(mState)
                        ? downEvent(mObserverCurrentState) : upEvent(mObserverCurrentState);
                mObserverCurrentState = getStateAfter(event);
                mCallback.onStateChanged(mLifecycleOwner, event);
            }
        }
```

额，这不就是刚才的`ObserverWithState`吗，原来在这里被调用，通过判断`mObserverCurrentState != mState`是否成立一直循环执行，所以可以指向`mState`，这个状态变化从而影响`sync()`从而调用`mCallback.onStateChanged`从而执行`YourObserver`的方法实现生命周期检测，那么继续看哪里改变了`mState`
``` java
/**
     * Only marks the current state as the given value. It doesn't dispatch any event to its
     * listeners.
     *
     * @param state new state
     */
    public void markState(State state) {
        mState = state;
    }

    /**
     * Sets the current state and notifies the observers.
     * <p>
     * Note that if the {@code currentState} is the same state as the last call to this method,
     * calling this method has no effect.
     *
     * @param event The event that was received
     */
    public void handleLifecycleEvent(Lifecycle.Event event) {
        if (mLastEvent == event) {
            return;
        }
        mLastEvent = event;
        mState = getStateAfter(event);
        for (Map.Entry<LifecycleObserver, ObserverWithState> entry : mObserverSet) {
            entry.getValue().sync();
        }
    }
```

啊哈，`markState()`只是单纯的改变`mState`，`handleLifecycleEvent()`不仅改变了`mState`，还遍历之前的`Map`再次执行`sync()`从而通知`Observer`生命周期的变化，继续往下看
``` java
private static void dispatchIfLifecycleOwner(Fragment fragment, Lifecycle.Event event) {
        if (fragment instanceof LifecycleRegistryOwner) {
            ((LifecycleRegistryOwner) fragment).getLifecycle().handleLifecycleEvent(event);
        }
    }
```

这部分代码在`LifecycleDispatcher`这个类找到，`dispatchIfLifecycleOwner`被调用的地方有四个，指向到`FragmentCallback`
``` java
static class FragmentCallback extends FragmentManager.FragmentLifecycleCallbacks {

        @Override
        public void onFragmentCreated(FragmentManager fm, Fragment f, Bundle savedInstanceState) {
            dispatchIfLifecycleOwner(f, ON_CREATE);

            if (!(f instanceof LifecycleRegistryOwner)) {
                return;
            }

            if (f.getChildFragmentManager().findFragmentByTag(REPORT_FRAGMENT_TAG) == null) {
                f.getChildFragmentManager().beginTransaction().add(new DestructionReportFragment(),
                        REPORT_FRAGMENT_TAG).commit();
            }
        }

        @Override
        public void onFragmentStarted(FragmentManager fm, Fragment f) {
            dispatchIfLifecycleOwner(f, ON_START);
        }

        @Override
        public void onFragmentResumed(FragmentManager fm, Fragment f) {
            dispatchIfLifecycleOwner(f, ON_RESUME);
        }
    }
```

看到`FragmentCallback`继承的是`FragmentManager.FragmentLifecycleCallbacks`就明白了，继续看
``` java
static class DispatcherActivityCallback extends EmptyActivityLifecycleCallbacks {
        private final FragmentCallback mFragmentCallback;

        DispatcherActivityCallback() {
            mFragmentCallback = new FragmentCallback();
        }

        @Override
        public void onActivityCreated(Activity activity, Bundle savedInstanceState) {
            if (activity instanceof FragmentActivity) {
                ((FragmentActivity) activity).getSupportFragmentManager()
                        .registerFragmentLifecycleCallbacks(mFragmentCallback, true);
            }
            ReportFragment.injectIfNeededIn(activity);
        }

        @Override
        public void onActivityStopped(Activity activity) {
            if (activity instanceof FragmentActivity) {
                markState((FragmentActivity) activity, CREATED);
            }
        }

        @Override
        public void onActivitySaveInstanceState(Activity activity, Bundle outState) {
            if (activity instanceof FragmentActivity) {
                markState((FragmentActivity) activity, CREATED);
            }
        }
    }
```

`FragmentCallback`在`DispatcherActivityCallback`构造方法中被实例化，继续
``` java
static void init(Context context) {
        if (sInitialized.getAndSet(true)) {
            return;
        }
        ((Application) context.getApplicationContext())
                .registerActivityLifecycleCallbacks(new DispatcherActivityCallback());
    }
```

哈哈，之所以`Observer`能够响应生命周期的回调，一切源头就在这里，通过对`Application`注册`Application.ActivityLifecycleCallbacks`监听所有`Activity`的生命周期回调，从而调用`sync()`、调用`mCallback.onStateChanged()`通知`Observer`生命周期的变化。那么这个`init`是在哪里调用的呢
``` java
public class LifecycleRuntimeTrojanProvider extends ContentProvider {
    @Override
    public boolean onCreate() {
        LifecycleDispatcher.init(getContext());
        ProcessLifecycleOwner.init(getContext());
        return true;
    }
  }
```

哇，原来官方利用了`ContentProvider`的特性，在创建的时候就注册了`Application.ActivityLifecycleCallbacks`，才有后面的可能。至于`ContentProvider`的注册，实际利用`Gradle`的合并`manifest`特性，相关资料看这里[https://developer.android.com/studio/build/manifest-merge.html?hl=zh-cn#_2](https://developer.android.com/studio/build/manifest-merge.html?hl=zh-cn#_2)，合并后的`manifest`可以在`build/intermediates/manifests`下找到
``` java
<provider
            android:name="android.arch.lifecycle.LifecycleRuntimeTrojanProvider"
            android:authorities="com.zyhang.testLifecycle.lifecycle-trojan"
            android:exported="false"
            android:multiprocess="true" />
```

### ProcessLifecycleOwner

看向`LifecycleRuntimeTrojanProvider.onCreate`，实现了两个`init`
``` java
LifecycleDispatcher.init(getContext());
ProcessLifecycleOwner.init(getContext());
```

其中`LifecycleDispatcher.init`则是我们逆推来的，其原理是利用`Application`的`registerActivityLifecycleCallbacks()`注册`Activity`生命周期监听，再根据判断`if (activity instanceof FragmentActivity)`继续调用`FragmentManager.registerFragmentLifecycleCallbacks`注册`Fragment`生命周期监听，最后都是调用`LifecycleRegistryOwner.handleLifecycleEvent`去通知各个`Observer`的方法从而管理生命周期。

还有一个`ProcessLifecycleOwner`是干嘛的呢，Let's go
``` java
private static final ProcessLifecycleOwner sInstance = new ProcessLifecycleOwner();
private final LifecycleRegistry mRegistry = new LifecycleRegistry(this);

static void init(Context context) {
        sInstance.attach(context);
    }

void attach(Context context) {
        mHandler = new Handler();
        mRegistry.handleLifecycleEvent(Lifecycle.Event.ON_CREATE);
        Application app = (Application) context.getApplicationContext();
        app.registerActivityLifecycleCallbacks(new EmptyActivityLifecycleCallbacks() {
            @Override
            public void onActivityCreated(Activity activity, Bundle savedInstanceState) {
                ReportFragment  .get(activity).setProcessListener(mInitializationListener);
            }

            @Override
            public void onActivityPaused(Activity activity) {
                activityPaused();
            }

            @Override
            public void onActivityStopped(Activity activity) {
                activityStopped();
            }
        });
    }
```

竟然是一个`sInstance`静态实例，最终同样是向`Application`注册生命周期监听，道理是一样的，但是与`LifecycleDispatcher`不同的是这里维护了一个自己的`Registry`并且`activityPaused`时调用`handleLifecycleEvent`的时机也是通过一个`Handler`并延时700ms执行，为什么这样做呢，看到了`ProcessLifecycleOwner`的注释
``` java
/**
 * Class that provides lifecycle for the whole application process.
 * <p>
 * You can consider this LifecycleOwner as the composite of all of your Activities, except that
 * {@link Lifecycle.Event#ON_CREATE} will be dispatched once and {@link Lifecycle.Event#ON_DESTROY}
 * will never be dispatched. Other lifecycle events will be dispatched with following rules:
 * ProcessLifecycleOwner will dispatch {@link Lifecycle.Event#ON_START},
 * {@link Lifecycle.Event#ON_RESUME} events, as a first activity moves through these events.
 * {@link Lifecycle.Event#ON_PAUSE}, {@link Lifecycle.Event#ON_STOP}, events will be dispatched with
 * a <b>delay</b> after a last activity
 * passed through them. This delay is long enough to guarantee that ProcessLifecycleOwner
 * won't send any events if activities are destroyed and recreated due to a
 * configuration change.
 *
 * <p>
 * It is useful for use cases where you would like to react on your app coming to the foreground or
 * going to the background and you don't need a milliseconds accuracy in receiving lifecycle
 * events.
 */
```
该类同样拥有`Activity`的生命周期的监听，但是会忽略掉`ON_DESTROY`，其中比较特殊的是`ON_PAUSE`会延迟700ms再执行`handleLifecycleEvent`，官方解释是这个延时足够确保当`Activity`销毁或者重建(比如旋转屏幕)时不会发生`ON_PAUSE`事件，这也可以非常简单的判断应用是否进入后台等情景。
