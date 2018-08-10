---
layout: post
title: flutter-StatelessWidget与StatefulWidget的解耦
date: 2018-06-13 15:54:47
tags: learn
categories: Flutter
---

`StatelessWidget`和`StatefulWidget`是`flutter`的基础组件，日常开发中自定义`Widget`都是选择继承这两者之一。

两者的区别在于`状态的改变`，`StatelessWidget`面向那些始终不变的UI控件，比如标题栏中的标题；而`StatefulWidget`则是面向可能会改变UI状态的控件，比如有点击反馈的按钮。

`StatelessWidget`就没什么好研究的了，`StatefulWidget`的创建需要指定一个`State`，在需要更新UI的时候调用`setState(VoidCallback fn)`，并在`VoidCallback`中改变一些变量数值等，组件会重新`build`以达到刷新状态也就是刷新UI的效果。

官方有个`StatefulWidget`的例子，通过点击按钮使屏幕上的`Text`数值逐渐增长，可以很好理解`StatefulWidget`的使用

<!-- More -->

```dart
class Counter extends StatefulWidget {
  // This class is the configuration for the state. It holds the
  // values (in this nothing) provided by the parent and used by the build
  // method of the State. Fields in a Widget subclass are always marked "final".

  @override
  _CounterState createState() => new _CounterState();
}

class _CounterState extends State<Counter> {
  int _counter = 0;

  void _increment() {
    setState(() {
      // This call to setState tells the Flutter framework that
      // something has changed in this State, which causes it to rerun
      // the build method below so that the display can reflect the
      // updated values. If we changed _counter without calling
      // setState(), then the build method would not be called again,
      // and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance
    // as done by the _increment method above.
    // The Flutter framework has been optimized to make rerunning
    // build methods fast, so that you can just rebuild anything that
    // needs updating rather than having to individually change
    // instances of widgets.
    return new Row(
      children: <Widget>[
        new RaisedButton(
          onPressed: _increment,
          child: new Text('Increment'),
        ),
        new Text('Count: $_counter'),
      ],
    );
  }
}
```

## 解耦

上面的例子比较简单，当层级多、状态多的情况下，这样的代码会导致阅读性、扩展性较低的不友好情况发生。代码整洁、代码解耦在日常开发中都非常重要，官方也是非常注重这一点，也提供了思路，将按钮和文本控件从`Counter`分离，`Counter`负责更新状态，按钮和文本控件只负责显示，这样达到了解耦，保持代码整洁，扩展性也对应提高。
```dart
class CounterDisplay extends StatelessWidget {
  CounterDisplay({this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return new Text('Count: $count');
  }
}

class CounterIncrementor extends StatelessWidget {
  CounterIncrementor({this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return new RaisedButton(
      onPressed: onPressed,
      child: new Text('Increment'),
    );
  }
}

class Counter extends StatefulWidget {
  @override
  _CounterState createState() => new _CounterState();
}

class _CounterState extends State<Counter> {
  int _counter = 0;

  void _increment() {
    setState(() {
      ++_counter;
    });
  }

  @override
  Widget build(BuildContext context) {
    return new Row(children: <Widget>[
      new CounterIncrementor(onPressed: _increment),
      new CounterDisplay(count: _counter),
    ]);
  }
}
```

## 思考

好的编程思想对日常开发有非常大的帮助，官方只是提供一个很小的例子，仔细琢磨理清思路方能提高工作效率。