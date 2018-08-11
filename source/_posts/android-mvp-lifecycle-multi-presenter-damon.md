---
layout: post
title: Android MVP - 拥有完整生命周期的Presenter，支持Multi P
date: 2018-08-11 10:16:29
tags: mvp
categories: Android
---

结合自己对`MVP`的理解，加上个人习惯，整理出这么一份`Android MVP`框架

- 通过注解动态注入Presenter
- Presenter拥有完整生命周期
- 支持多Presenter注入
- 状态复原

<!-- More -->

## 0x00 前言

此框架可以说是`Fork` **[nucleus](https://github.com/konmik/nucleus)** 而来，只不过结合了个人理解和习惯进行更改，放上此框架链接
[https://github.com/izyhang/Damon/tree/feature/multi-presenter](https://github.com/izyhang/Damon/tree/feature/multi-presenter)

## 0x01 介绍

先介绍一下`Damon`的简单使用

### 新建View、Presenter

`Presenter`具有与`Activity`一样的生命周期，这里展示部分生命周期
``` kotlin
interface MainView {
    fun log(msg: String)
}

class MainPresenter : BasePresenter<MainView>() {
    override fun onCreate(arguments: Bundle?, savedState: Bundle?) {
        super.onCreate(arguments, savedState)
        view.log("MainPresenter.onCreate")
    }

    override fun onResume() {
        super.onResume()
        view.log("MainPresenter.onResume")
    }

    override fun onPause() {
        super.onPause()
        view.log("MainPresenter.onPause")
    }

    override fun onDestroy() {
        super.onDestroy()
        view.log("MainPresenter.onDestroy")
    }
}
```

### 修改MainActivity

为`MainActivity`绑定`Presenter`，想要拿到`Presenter`通过`@BindPresenter`获取
``` kotlin
@RequiresPresenter(MainPresenter::class)
class MainActivity : BaseActivity(), MainView {
    @BindPresenter
    private var mainPresenter: MainPresenter? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)
        mainPresenter.xxx()
    }

    override fun log(msg: String) {
        println(msg)
    }
}
```

### 多Presenter注入

``` kotlin
@RequiresPresenter(value = [MainPresenter::class, SecondPresenter::class])
class MainActivity : BaseActivity(), MainView, SecondView {
    @BindPresenter
    private var mainPresenter: MainPresenter? = null
    @BindPresenter
    private var secondPresenter: SecondPresenter? = null

    override fun log(msg: String) {
        println(msg)
    }
}
```

## 0x02 工作原理

下面介绍一下`Damon`的工作原理

### Presenter的动态注入和赋值

用注解代替手动实例化`Presenter`更加方便，并且在封装好的`Activity`实现了状态恢复，避免重复创建`Presenter`

在界面创建之时会传入当前`class`到`ReflectionPresenterFactory`，通过`cls.getAnnotation`拿到`@RequiresPresenter`注解并保存，在这里也对当前`class`有`@BindPresenter`注解的成员进行保存
``` java
@Nullable
public static ReflectionPresenterFactory fromViewClass(Object host, Class<?> cls) {
    RequiresPresenter annotation = cls.getAnnotation(RequiresPresenter.class);
    Class<? extends MvpPresenter>[] pClass = null != annotation ? annotation.value() : null;
    if (null == pClass) {
        return null;
    }
    List<Field> fields = new ArrayList<>();
    for (Field field : cls.getDeclaredFields()) {
        Annotation[] annotations = field.getDeclaredAnnotations();
        if (annotations.length < 1) {
            continue;
        }
        if (annotations[0] instanceof BindPresenter) {
            fields.add(field);
        }
    }
    return new ReflectionPresenterFactory(host, pClass, fields);
}
```

### Presenter的创建

上面讲过`Damon`的`Presenter`是具有完整生命周期的，看到封装的`Activity` **[MvpAppCompatActivity.java](https://github.com/izyhang/Damon/blob/feature%2Fmulti-presenter/damon/src/main/java/com/zyhang/damon/support/MvpAppCompatActivity.java)**

在`Activity`的生命周期通过`PresenterLifecycleDelegate`去控制`Presenter`的方法调用，赋予其生命周期。其中还重载了`onSaveInstanceState`辅助`Presenter`状态恢复机制
``` java
public class MvpAppCompatActivity extends AppCompatActivity implements MvpView {

    private static final String PRESENTER_STATE_KEY = "presenter_state";
    private PresenterLifecycleDelegate mPresenterDelegate =
            new PresenterLifecycleDelegate(ReflectionPresenterFactory.fromViewClass(this, getClass()));

    @Override
    public void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        mPresenterDelegate.onCreate(this, getIntent().getExtras(), null != savedInstanceState ? savedInstanceState.getBundle(PRESENTER_STATE_KEY) : null);
    }

    @Override
    public void onSaveInstanceState(Bundle outState) {
        super.onSaveInstanceState(outState);
        outState.putBundle(PRESENTER_STATE_KEY, mPresenterDelegate.onSaveInstanceState());
    }

    @Override
    public void onStart() {
        super.onStart();
        mPresenterDelegate.onStart();
    }

    @Override
    public void onResume() {
        super.onResume();
        mPresenterDelegate.onResume();
    }

    @Override
    public void onPause() {
        mPresenterDelegate.onPause();
        super.onPause();
    }

    @Override
    public void onStop() {
        mPresenterDelegate.onStop();
        super.onStop();
    }

    @Override
    public void onDestroy() {
        mPresenterDelegate.onDestroy(!isChangingConfigurations());
        super.onDestroy();
    }
}
```

### PresenterLifecycleDelegate

最重要的就是此类，连接`Activity`和`Presenter`的枢纽，控制`Presenter`的创建、恢复、生命周期
``` java
public class PresenterLifecycleDelegate {

    private static final String PRESENTER_KEY = "presenter - ";
    private static final String PRESENTER_ID_KEYS = "presenter_ids";

    @Nullable
    private PresenterFactory mPresenterFactory;
    @Nullable
    private List<? extends MvpPresenter> mPresenters;

    private boolean mPresenterHasView;

    public PresenterLifecycleDelegate(@Nullable PresenterFactory presenterFactory) {
        this.mPresenterFactory = presenterFactory;
    }

    public void onCreate(MvpView view, @Nullable Bundle arguments, @Nullable Bundle savedState) {
        if (mPresenterFactory == null) {
            return;
        }
        Bundle presenterBundle = null;
        if (savedState != null) {
            presenterBundle = ParcelFn.unmarshall(ParcelFn.marshall(savedState));
        }
        createPresenter(presenterBundle);
        if (mPresenters != null && !mPresenters.isEmpty()) {
            mPresenterFactory.bindPresenter(mPresenters);
            for (MvpPresenter presenter : mPresenters) {
                //noinspection unchecked
                presenter.create(view, arguments, null != presenterBundle ? presenterBundle.getBundle(PRESENTER_KEY.concat(presenter.getClass().getSimpleName())) : null);
            }
        }
    }

    private void createPresenter(Bundle presenterBundle) {
        if (presenterBundle != null) {
            mPresenters = PresenterStorage.INSTANCE.getPresenter(presenterBundle.getStringArray(PRESENTER_ID_KEYS));
        }

        if (mPresenters == null) {
            //noinspection ConstantConditions
            mPresenters = mPresenterFactory.createPresenter();
            PresenterStorage.INSTANCE.add(mPresenters);
        }
    }

    public void onStart() {
        if (mPresenters != null && !mPresenters.isEmpty()) {
            for (MvpPresenter presenter : mPresenters) {
                presenter.start();
            }
        }
    }

    public Bundle onSaveInstanceState() {
        Bundle bundle = new Bundle();
        if (mPresenters != null && !mPresenters.isEmpty()) {
            String[] ids = new String[mPresenters.size()];
            for (MvpPresenter presenter : mPresenters) {
                Bundle presenterBundle = new Bundle();
                presenter.save(presenterBundle);
                bundle.putBundle(PRESENTER_KEY.concat(presenter.getClass().getSimpleName()), presenterBundle);

                ids[mPresenters.indexOf(presenter)] = PresenterStorage.INSTANCE.getId(presenter);
            }
            bundle.putStringArray(PRESENTER_ID_KEYS, ids);
        }
        return bundle;
    }

    public void onResume() {
        if (mPresenters != null && !mPresenters.isEmpty() && !mPresenterHasView) {
            for (MvpPresenter presenter : mPresenters) {
                presenter.resume();
            }
            mPresenterHasView = true;
        }
    }

    public void onPause() {
        if (mPresenters != null && !mPresenters.isEmpty() && mPresenterHasView) {
            for (MvpPresenter presenter : mPresenters) {
                presenter.pause();
            }
            mPresenterHasView = false;
        }
    }

    public void onStop() {
        if (mPresenters != null && !mPresenters.isEmpty()) {
            for (MvpPresenter presenter : mPresenters) {
                presenter.stop();
            }
        }
    }

    public void onDestroy(boolean isFinal) {
        if (isFinal && mPresenters != null && !mPresenters.isEmpty()) {
            for (MvpPresenter presenter : mPresenters) {
                presenter.destroy();
            }
            mPresenters.clear();
            mPresenters = null;
        }
    }
}
```

## 0x03 讲在最后

该框架实现的`Presenter`恢复机制，存储的`id`不止是单纯的`Presenter`类名，大可不必担心`Presenter`复用混乱的情况，具体可以看 **[PresenterStorage.java](https://github.com/izyhang/Damon/blob/feature%2Fmulti-presenter/damon/src/main/java/com/zyhang/damon/PresenterStorage.java)** 的实现

> 此次说讲`Multi Presenter`版本的`Damon`是新变支的`2.0.0-alpha`，未经过大量测试。
> 不过此前的`Single Presenter`版本的`Damon`，版本号`1.1.0`，则在开发环境稳定运行许久

最后再放上项目链接[https://github.com/izyhang/Damon/tree/feature/multi-presenter](https://github.com/izyhang/Damon/tree/feature/multi-presenter)

欢迎大家指出不足、留下您的意见~
