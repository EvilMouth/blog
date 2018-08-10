---
layout: post
title: Android Architecture Components分析记录（三）
date: 2017-08-18 15:48:32
tags: aac
categories: Android
---

记录分析`AAC`第三篇---`ViewModel`，官方地址
[https://developer.android.com/topic/libraries/architecture/viewmodel.html?hl=zh-cn](https://developer.android.com/topic/libraries/architecture/viewmodel.html?hl=zh-cn)

<!-- More -->

## 前言

由于`UI组件`可能会因为某些原因（比如旋转屏幕等）导致被系统销毁或者重建从而导致所持数据丢失，通知针对这种状况采取的做法是通过`onSaveInstanceState`保存数据，并在界面重建后取出来，例如`EditText`编辑框中的内容，然而这种做法只适应于少量数据甚至最好只存储基本类型的数据。

官方针对此问题设计了`ViewModel`（当然不止这个原因），例如一个列表页，以往的做法下旋转屏幕后还需要重新请求数据，使用`ViewModel`后可以将减少这一次请求，而且这一切恢复操作完全不需要我们管理，这样又能减轻界面的负担。

下面先看看`ViewModel`的使用方法

## 使用

先创建`ViewModel`
``` java
public class UserInfoModel extends ViewModel {

    private MutableLiveData<UserInfo> mUserInfoMutableLiveData;

    public LiveData<UserInfo> getUserInfoLiveData() {
        if (mUserInfoMutableLiveData == null) {
            mUserInfoMutableLiveData = new MutableLiveData<>();
            loadUserInfo();
        }
        return mUserInfoMutableLiveData;
    }

    private void loadUserInfo() {
        //例如网络加载操作
    }
}
```

然后就可以在`Activity`使用
``` java
UserInfoModel userInfoModel = ViewModelProviders.of(this).get(UserInfoModel.class);
        userInfoModel.getUserInfoLiveData().observe(this, new Observer<UserInfo>() {
            @Override
            public void onChanged(@Nullable UserInfo userInfo) {
                //更新UI
            }
        });
```

> 注意是通过`ViewModelProviders`而不是`new`拿到`ViewModel`实例

## 分析

在上门的例子可以看到实例`ViewModel`的方法不是`new`而是通过`ViewModelProviders`取得

### of()

``` java
@MainThread
    public static ViewModelProvider of(@NonNull FragmentActivity activity) {
        initializeFactoryIfNeeded(activity.getApplication());
        return new ViewModelProvider(ViewModelStores.of(activity), sDefaultFactory);
    }

    private static DefaultFactory sDefaultFactory;

    private static void initializeFactoryIfNeeded(Application application) {
        if (sDefaultFactory == null) {
            sDefaultFactory = new DefaultFactory(application);
        }
    }
```
`of()`方法其实有四个，分别是
- of(@NonNull Fragment fragment)
- of(@NonNull FragmentActivity activity)
- of(@NonNull Fragment fragment, @NonNull Factory factory)
- of(@NonNull FragmentActivity activity,@NonNull Factory factory)

第二个参数是支持自定义`Factory`，由于`ViewModel`是通过反射实例化的，所以默认的构造函数的无参的，如果需要操作系统服务，可以选择继承`AndroidViewModel`，这也是第一句`initializeFactoryIfNeeded(activity.getApplication())`初始化`sDefaultFactory`的原因，为了在后面反射时传入`application`。

`of()`返回的是一个`ViewModelProvider`
``` java
public ViewModelProvider(ViewModelStore store, Factory factory) {
        mFactory = factory;
        this.mViewModelStore = store;
    }
```
只是赋值了下`ViewModelStore`和`Factory`，具体实例化是在`get()`中。

### ViewModelStore

先看看`ViewModelStore`怎么来的
``` java
ViewModelStores.of(activity)

public static ViewModelStore of(FragmentActivity activity) {
        return holderFragmentFor(activity).getViewModelStore();
    }

public static HolderFragment holderFragmentFor(FragmentActivity activity) {
        return sHolderFragmentManager.holderFragmentFor(activity);
    }

HolderFragment holderFragmentFor(FragmentActivity activity) {
            FragmentManager fm = activity.getSupportFragmentManager();
            HolderFragment holder = findHolderFragment(fm);
            if (holder != null) {
                return holder;
            }
            holder = mNotCommittedActivityHolders.get(activity);
            if (holder != null) {
                return holder;
            }

            if (!mActivityCallbacksIsAdded) {
                mActivityCallbacksIsAdded = true;
                activity.getApplication().registerActivityLifecycleCallbacks(mActivityCallbacks);
            }
            holder = createHolderFragment(fm);
            mNotCommittedActivityHolders.put(activity, holder);
            return holder;
        }

private static HolderFragment createHolderFragment(FragmentManager fragmentManager) {
            HolderFragment holder = new HolderFragment();
            fragmentManager.beginTransaction().add(holder, HOLDER_TAG).commitAllowingStateLoss();
            return holder;
        }
```
`ViewModelStore`是通过一个`HolderFragment.getViewModelStore()`获得，这个`HolderFragment`是一个透明无界面的`Fragment`，`ViewModelStores`就是保存在`HolderFragment`中。随后通过`FragmentManager`将`HolderFragment`添加到`Activity`，这也是为什么这个库要依赖于`FragmentActivity`的原因。

接着看`getViewModelStore()`
``` java
public ViewModelStore getViewModelStore() {
        return mViewModelStore;
    }

private ViewModelStore mViewModelStore = new ViewModelStore();

public class ViewModelStore {

    private final HashMap<String, ViewModel> mMap = new HashMap<>();

    final void put(String key, ViewModel viewModel) {
        ViewModel oldViewModel = mMap.get(key);
        if (oldViewModel != null) {
            oldViewModel.onCleared();
        }
        mMap.put(key, viewModel);
    }

    final ViewModel get(String key) {
        return mMap.get(key);
    }

    /**
     *  Clears internal storage and notifies ViewModels that they are no longer used.
     */
    public final void clear() {
        for (ViewModel vm : mMap.values()) {
            vm.onCleared();
        }
        mMap.clear();
    }
}
```
所以`ViewModel`是被保存在这里，通过一个`HashMap`进行存取。
咦，等一下，这个`HashMap`以及这个`ViewModelStore`都是局部变量，旋转屏幕也会销毁呀，明明不能保存数据。

### setRetainInstance

这时候看到了`HolderFragment`的构造函数
``` java
public HolderFragment() {
        setRetainInstance(true);
    }
```

查看`API`
``` java
/**
     * Control whether a fragment instance is retained across Activity
     * re-creation (such as from a configuration change).  This can only
     * be used with fragments not in the back stack.  If set, the fragment
     * lifecycle will be slightly different when an activity is recreated:
     * <ul>
     * <li> {@link #onDestroy()} will not be called (but {@link #onDetach()} still
     * will be, because the fragment is being detached from its current activity).
     * <li> {@link #onCreate(Bundle)} will not be called since the fragment
     * is not being re-created.
     * <li> {@link #onAttach(Activity)} and {@link #onActivityCreated(Bundle)} <b>will</b>
     * still be called.
     * </ul>
     */
    public void setRetainInstance(boolean retain) {
        mRetainInstance = retain;
    }
```
设定了`retain=true`之后，`Fragment`的生命周期将会改变，不会因为旋转屏幕等操作重建，但是会有以下几点后果
- `onDestroy()`将不会回调
- `onDetach`仍会回调，因为`Activity`重建了，所以`Fragment`暂时分离
- `onCreate(Bundle)`也不会回调，因为`Fragment`并没有销毁
- `onAttach()`、`onActivityCreated(Bundle)`仍会回调

通过`setRetainInstance(true)`，改变了`HolderFragment`的部分生命周期流程，从而保持`ViewModelStore`从而保持`ViewModel`，所以保持了`ViewModel`中的数据。

### get()

最后看`ViewModelProvider.get()`
``` java
public <T extends ViewModel> T get(Class<T> modelClass) {
        String canonicalName = modelClass.getCanonicalName();
        if (canonicalName == null) {
            throw new IllegalArgumentException("Local and anonymous classes can not be ViewModels");
        }
        return get(DEFAULT_KEY + ":" + canonicalName, modelClass);
    }

public <T extends ViewModel> T get(@NonNull String key, @NonNull Class<T> modelClass) {
        ViewModel viewModel = mViewModelStore.get(key);

        if (modelClass.isInstance(viewModel)) {
            //noinspection unchecked
            return (T) viewModel;
        } else {
            //noinspection StatementWithEmptyBody
            if (viewModel != null) {
                // TODO: log a warning.
            }
        }

        viewModel = mFactory.create(modelClass);
        mViewModelStore.put(key, viewModel);
        //noinspection unchecked
        return (T) viewModel;
    }
```
先在`ViewModelStore`拿`viewModel`，拿到直接返回，拿不到就通过`Factory.create()`反射实例化

``` java
@Override
        public <T extends ViewModel> T create(Class<T> modelClass) {
            if (AndroidViewModel.class.isAssignableFrom(modelClass)) {
                //noinspection TryWithIdenticalCatches
                try {
                    return modelClass.getConstructor(Application.class).newInstance(mApplication);
                } catch (NoSuchMethodException e) {
                    throw new RuntimeException("Cannot create an instance of " + modelClass, e);
                } catch (IllegalAccessException e) {
                    throw new RuntimeException("Cannot create an instance of " + modelClass, e);
                } catch (InstantiationException e) {
                    throw new RuntimeException("Cannot create an instance of " + modelClass, e);
                } catch (InvocationTargetException e) {
                    throw new RuntimeException("Cannot create an instance of " + modelClass, e);
                }
            }
            return super.create(modelClass);
        }

@Override
        public <T extends ViewModel> T create(Class<T> modelClass) {
            //noinspection TryWithIdenticalCatches
            try {
                return modelClass.newInstance();
            } catch (InstantiationException e) {
                throw new RuntimeException("Cannot create an instance of " + modelClass, e);
            } catch (IllegalAccessException e) {
                throw new RuntimeException("Cannot create an instance of " + modelClass, e);
            }
        }
```
如果是`AndroidViewModel`的话，则会带多个`application`参数，所以官方提供自定义`Factory`自行操作
``` java
/**
     * Implementations of {@code Factory} interface are responsible to instantiate ViewModels.
     */
    public interface Factory {
        /**
         * Creates a new instance of the given {@code Class}.
         * <p>
         *
         * @param modelClass a {@code Class} whose instance is requested
         * @param <T>        The type parameter for the ViewModel.
         * @return a newly created ViewModel
         */
        <T extends ViewModel> T create(Class<T> modelClass);
    }
```

## 总结
`ViewModel`负责帮`UI`准备数据，减轻UI负担，并能够自动保存数据防止某些场景丢失、快速读取更新UI。
由于`LiveData`的观察者特性，所以`ViewModel`还可以实现数据共享，例如最常见的`ViewPager`绑定着多个`Fragment`，某些场景会涉及到`Fragment`之间的通信，以往的做法要不是通过`Activity`进行中转通信，要不是使用事件总线。使用`ViewModel`可以很方便解决这个问题，通过`of(getActivity())`绑定到`Activity`，这样的`ViewModel`将会是同一个实例，也就能共同使用同一份数据从而进行通信等操作。

`ViewModel`的生命周期会持续到`Activity.onDestroy`、`Fragment.onDetach`，并会回调`onCleared`，所以有些大型操作依旧得进行解除。
