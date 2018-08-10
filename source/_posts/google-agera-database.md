---
layout: post
title: 初试Google Agera database
tags: agera
categories: Android
date: 2017-02-10 15:04:24
---

（内白：第一次真正意义上写博客，这几年来开发路程遇到过许多问题，但都是简单标记一下，并没有记录下来，等过段时间遇到同样问题脑袋一热都忘了又得翻翻翻，特此开始写博客记录我的开发路程，老了，记忆力下降了，再过几年连代码都不会打了。。。 0 0）

进入主题，最近打算用agera运用在新项目上，本来打算rxjava，貌似个个都在用。。但是对比了一下agera和rxjava，感觉在android上使用agera更适合，个人觉得rxjava的确很强大，但是操作符有点乱，什么action1、action2，虽然后面rxjava2更改并加强了概念，还是觉得使用起来有时候会忘记，况且agera跟android生命周期绑定，所以选择了agera

那么开始吧，先从常用的sqlite入手

### 依赖
Google官网出了一个database的库，就是基于Agera概念封装了一下sqlite，使用方法如下
``` java
compile 'com.google.android.agera:agera:1.2.0'
compile 'com.google.android.agera:database:1.2.0'
```
Agera Github 地址: [https://github.com/google/agera](https://github.com/google/agera)
还有中文翻译: [https://github.com/captain-miao/AndroidAgeraTutorial/wiki](https://github.com/captain-miao/AndroidAgeraTutorial/wiki)

<!-- more -->

### 首先是创建一个SQLiteOpenHelper
这里database库里有个`SqlDatabaseSupplier`帮我们继承了`SQLiteOpenHelper`并且实现了一个`Supplier`接口(这个Supplier接口是使用agera必须实现的)，所以直接继承`SqlDatabaseSupplier`就行了
``` java
public class BikeDBHelper extends SqlDatabaseSupplier {

    private static final String DB_NAME = "DB.db";
    public static final String TABLE_NAME = "Bikes";

    public BikeDBHelper(@NonNull Context context) {
        super(context, DB_NAME, null, 1);
    }

    @Override
    public void onCreate(SQLiteDatabase db) {
        String sql = "create table if not exists " + TABLE_NAME + " (id integer primary key,num text)";
        db.execSQL(sql);
        //插入两条数据模拟一下
        db.execSQL("insert into " + TABLE_NAME + " (id,num) values (1,'123456')");
        db.execSQL("insert into " + TABLE_NAME + " (id,num) values (2,'254365')");
    }

    @Override
    public void onUpgrade(SQLiteDatabase db, int oldVersion, int newVersion) {
        //do nothing
    }
}
```
下面是`SqlDatabaseSupplier`的源码，很简单
``` java
/**
 * Abstract extension of {@link SQLiteOpenHelper} implementing a sql database {@link Supplier} to be
 * used with the {@link SqlDatabaseFunctions}.
 */
public abstract class SqlDatabaseSupplier extends SQLiteOpenHelper
    implements Supplier<Result<SQLiteDatabase>> {

  /**
   * Extending the base constructor, for overriding in concrete implementations.
   */
  public SqlDatabaseSupplier(@NonNull final Context context, @NonNull final String path,
      @Nullable final CursorFactory factory, final int version) {
    super(context, path, factory, version);
  }

  @NonNull
  @Override
  public final synchronized Result<SQLiteDatabase> get() {
    try {
      return absentIfNull(getWritableDatabase());
    } catch (final SQLException e) {
      return failure(e);
    }
  }
}
```

### 创建Repository
在agera最重要的就是这个`Repository`了，先从查询开始
``` java
Repository<Result<List<Bike>>> query = Repositories.repositoryWithInitialValue(Result.<List<Bike>>absent())
                .observe(onSearchObservable)//这里观察一个按钮，点击按钮就获取一次
                .onUpdatesPerLoop()//刷新频率
                .getFrom(new Supplier<String>() {
                    @NonNull
                    @Override
                    public String get() {
                        return "";//可以是查询条件
                    }
                })
                .goTo(EXECUTOR)//异步
                .transform(new Function<String, SqlRequest>() {
                    @NonNull
                    @Override
                    public SqlRequest apply(@NonNull String input) {
                    	//这里的input就是getFrom返回的字符串，可以是查询条件，根据查询条件创建不同的SqlRequest
                        return SqlRequests.sqlRequest()
                                        .sql("SELECT * FROM " + BikeDBHelper.TABLE_NAME)
                                        .compile()
                    }
                })
                .thenTransform(SqlDatabaseFunctions.databaseQueryFunction(new BikeDBHelper(this), new Function<Cursor, Bike>() {
                    @NonNull
                    @Override
                    public Bike apply(@NonNull Cursor cursor) {
                        return new Bike(
                                cursor.getString(cursor.getColumnIndex("num"))
                        );
                    }
                }))
                .compile();
```
重点就是最后一步`thenTransform`，将`SqlRequest`转换成`Result<List<Bike>>`。官网提供了`SqlDatabaseFunctions`类，里面有数据库增删改查四个方法，这里用到的就是查询`databaseQueryFunction`方法，通过传入一个`Supplier<Result<SQLiteDatabase>>`，就是一开始创建的`BikeDBHelper`，还传入一个`Function`将里面处理好的游标`Cursor`提供给我们去获取转换成该游标下的数据，至此转换成最后需要的`Result<List<Bike>>`
``` java
/**
   * Creates a sql query {@link Function}.
   */
  @NonNull
  public static <T> Function<SqlRequest, Result<List<T>>> databaseQueryFunction(
      @NonNull final Supplier<Result<SQLiteDatabase>> database,
      @NonNull Function<Cursor, T> rowMap) {
    return new DatabaseFunction<>(database, new DatabaseQueryMerger<>(rowMap));
  }
```

### push event
``` java
@Override
    protected void onResume() {
        super.onResume();
        query.addUpdatable(this);
    }

@Override
    protected void onPause() {
        super.onPause();
        query.removeUpdatable(this);
    }
```

### pull data
``` java
@Override
    public void update() {
        query.get().ifSucceededSendTo(this);
    }

    @Override
    public void accept(@NonNull List<Bike> value) {
        mMainAdapter.setList(value);
    }
```

### 总结
创建`Repository`过程中涉及到一个`SqlRequest`，这其实就是一个查询request，针对增删改还有`SqlInsertRequest``SqlDeleteRequest``SqlUpdateRequest`一共四种request，都是通过`SqlRequests`创建。其实整个database库很小，一共也就几个类，所以使用起来还是挺方便的，重点还是得理解Repository。

![database库](http://images.zyhang.com/17-2-23/96957663-file_1487830209735_660c.png)
