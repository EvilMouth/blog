---
layout: post
title: 在java中调用shell命令
date: 2017-05-27 11:18:51
tags: shell
categories: Java
---

[https://github.com/izyhang/ShellCommand](https://github.com/izyhang/ShellCommand)

<!-- More -->

习惯直接在电脑终端执行`Shell`命令控制连接电脑的`Android`设备，最近在帮别人弄个软件类似脚本自动运行，一开始就想到直接用`Shell`命令在手机上跑，毕竟这功能特别强大，但是真正实现起来还是有坑的。

可以直接看上面的链接拉依赖下来，使用`ShellCommand.exec(String,boolean)`直接运行命令，比如
``` java
ShellCommand.exec("monkey -vvv 1000",true)
```
注意在pc上原命令是`adb shell monkey -vvv 1000`
在手机上运行就可以忽略掉`adb shell`了

### monkey.script
monkey是Android一个压力测试工具，使用方法以及常用命令可以看官网[https://developer.android.com/studio/test/monkey.html](https://developer.android.com/studio/test/monkey.htmlhttps://developer.android.com/studio/test/monkey.html)

这里要讲的是一个隐藏功能`monkey.script`，可以直接新建这个文件，编辑一堆命令，并保存到手机，最后执行
```
adb shell monkey -f filePath 1
```

具体`monkey.script`文件编写如下
```
type = user
count = 1
speed = 500
start data >>
//这里开始你的表演(自定义命令)
```
自定义命令有(详情可以看[http://www.jianshu.com/p/85454be8424f](http://www.jianshu.com/p/85454be8424f))
```
LaunchActivity ( pkg_name , act_name )
UserWait ( sleepTime )
DispatchPointer
DispatchKey
DispatchFlip ( keyboardOpen )
DispatchString( input )
...
```

### 还有这个
```
adb shell input tap 50 250 //点击屏幕坐标(50,250)
adb shell inpput swipe 50 250 250 250 500 //滑动
adb shell input text abd //输入abc
adb shell input keyevent keyCode //点击功能键
```
功能键表如下
```
KEYCODE_UNKNOWN=0;     

KEYCODE_SOFT_LEFT=1;     

KEYCODE_SOFT_RIGHT=2;     

KEYCODE_HOME=3;     

KEYCODE_BACK=4;     

KEYCODE_CALL=5;     

KEYCODE_ENDCALL=6;     

KEYCODE_0=7;     

KEYCODE_1=8;     

KEYCODE_2=9;     

KEYCODE_3=10;     

KEYCODE_4=11;     

KEYCODE_5=12;     

KEYCODE_6=13;     

KEYCODE_7=14;     

KEYCODE_8=15;     

KEYCODE_9=16;     

KEYCODE_STAR=17;     

KEYCODE_POUND=18;     

KEYCODE_DPAD_UP=19;     

KEYCODE_DPAD_DOWN=20;     

KEYCODE_DPAD_LEFT=21;     

KEYCODE_DPAD_RIGHT=22;     

KEYCODE_DPAD_CENTER=23;     

KEYCODE_VOLUME_UP=24;     

KEYCODE_VOLUME_DOWN=25;     

KEYCODE_POWER=26;     

KEYCODE_CAMERA=27;     

KEYCODE_CLEAR=28;     

KEYCODE_A=29;     

KEYCODE_B=30;     

KEYCODE_C=31;     

KEYCODE_D=32;     

KEYCODE_E=33;     

KEYCODE_F=34;     

KEYCODE_G=35;     

KEYCODE_H=36;     

KEYCODE_I=37;     

KEYCODE_J=38;     

KEYCODE_K=39;     

KEYCODE_L=40;     

KEYCODE_M=41;     

KEYCODE_N=42;     

KEYCODE_O=43;     

KEYCODE_P=44;     

KEYCODE_Q=45;     

KEYCODE_R=46;     

KEYCODE_S=47;     

KEYCODE_T=48;     

KEYCODE_U=49;     

KEYCODE_V=50;     

KEYCODE_W=51;     

KEYCODE_X=52;     

KEYCODE_Y=53;     

KEYCODE_Z=54;     

KEYCODE_COMMA=55;     

KEYCODE_PERIOD=56;     

KEYCODE_ALT_LEFT=57;     

KEYCODE_ALT_RIGHT=58;     

KEYCODE_SHIFT_LEFT=59;     

KEYCODE_SHIFT_RIGHT=60;     

KEYCODE_TAB=61;     

KEYCODE_SPACE=62;     

KEYCODE_SYM=63;     

KEYCODE_EXPLORER=64;     

KEYCODE_ENVELOPE=65;     

KEYCODE_ENTER=66;     

KEYCODE_DEL=67;     

KEYCODE_GRAVE=68;     

KEYCODE_MINUS=69;     

KEYCODE_EQUALS=70;     

KEYCODE_LEFT_BRACKET=71;     

KEYCODE_RIGHT_BRACKET=72;     

KEYCODE_BACKSLASH=73;     

KEYCODE_SEMICOLON=74;     

KEYCODE_APOSTROPHE=75;     

KEYCODE_SLASH=76;     

KEYCODE_AT=77;     

KEYCODE_NUM=78;     

KEYCODE_HEADSETHOOK=79;     

KEYCODE_FOCUS=80;//*Camera*focus     

KEYCODE_PLUS=81;     

KEYCODE_MENU=82;     

KEYCODE_NOTIFICATION=83;     

KEYCODE_SEARCH=84;     

KEYCODE_MEDIA_PLAY_PAUSE=85;     

KEYCODE_MEDIA_STOP=86;     

KEYCODE_MEDIA_NEXT=87;     

KEYCODE_MEDIA_PREVIOUS=88;     

KEYCODE_MEDIA_REWIND=89;     

KEYCODE_MEDIA_FAST_FORWARD=90;     

KEYCODE_MUTE=91;
```
