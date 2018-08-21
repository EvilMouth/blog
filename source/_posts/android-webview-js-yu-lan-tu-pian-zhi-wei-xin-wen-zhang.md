---
layout: post
title: Android WebView注入Js预览图片 - 微信公众号文章
date: 2018-08-21 16:45:03
tags:
 - webView
 - js
categories: Android
---

通常的做法是通过`document.getElementsByTagName("img")`，然后遍历元素拿到`src`为图片地址。但是针对微信公众号文章就不适用了，尤其是其图片元素采用懒加载方式，所以取到的`src`为空，但是在微信客户端能够正常取到所有图片，所以对文章进行分析

<!-- More -->

## 0x00 文章图片懒加载

`Chrome`打开一篇微信公众号文章，审查元素，控制台输入`document.getElementsByTagName("img")`。可以看到正文图片的`img`标签定义了`img_loading`的`class`属性
![](http://images.zyhang.com/18-8-21/55262970.jpg)

此时再看向该标签的`src`属性，是一张`base64`的`loading`图。这也就导致通常的做法是获取不到图片地址从而进行预览的
![](http://images.zyhang.com/18-8-21/34624449.jpg)

## 0x01 分析

然而在微信客户端可以正常预览，推测微信应该是在别的属性进行获取，定位到具体的标签看到文章中的`img`标签都定义了`data-src`、`data-type`属性（这是自定义属性，区分src，方便js调用）
``` html
<img class="img_loading"
data-ratio="0.53375"
data-src="https://mmbiz.qpic.cn/mmbiz_jpg/h5tEWrMy7mrq9iclTia1O8M2C5Se7nr5TgN6IibURS7YYpCSTwT0U5KUhOmGrxusN8iaQKrFDjtTBaMox6Dgp2Hfbg/640?wx_fmt=jpeg"
data-type="jpeg"
data-w="800"
_width="677px"
src="data:image/gif;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQImWNgYGBgAAAABQABh6FO1AAAAABJRU5ErkJggg=="
style="width: 647px !important; height: 345.336px !important;">
```

## 0x02 解决

现在知道问题所在，针对`data-x`自定义属性可以通过`dataset`获得，之所以判断`dataset.type !== "gif"`是为了过滤掉`gif`，如果你想显示`gif`，可以去掉
``` js
function wxImgClick() {
    let objs = document.getElementsByTagName("img");
    let imgs = [];
    for (let i = 0; i < objs.length; i++) {
        let dataset = objs[i].dataset;
        if (dataset.src && dataset.type !== "gif") {
            let index = imgs.push(dataset.src) - 1;
            objs[i].onclick = function () {
                window.xxxxxx.openImage(imgs, index)
            }
        }
    }
}
```

## 0x03 完整例子

可以在`webView`创建之时调用`addJavascriptInterface`进行监听
``` java
addJavascriptInterface(new JavascriptInterface(getContext().getApplicationContext()), "xxxxxx");

private class JavascriptInterface {
    private Context context;

    private JavascriptInterface(Context context) {
        this.context = context;
    }

    @android.webkit.JavascriptInterface
    public void openImage(String[] imgs, int index) {
        // 预览图片操作
    }
}
```

在合适的时候注入`Js`，我这里是在`onPageFinished`
``` java
@Override
public void onPageFinished(WebView view, String url) {
    super.onPageFinished(view, url);
    addWXImgClickJs();
}

private void addWXImgClickJs() {
    // 用"javascript:(%s)()"包住
    String js = "javascript:(function wxImgClick() {\n" +
            "    let objs = document.getElementsByTagName(\"img\");\n" +
            "    let imgs = [];\n" +
            "    for (let i = 0; i < objs.length; i++) {\n" +
            "        let dataset = objs[i].dataset;\n" +
            "        if (dataset.src && dataset.type !== \"gif\") {\n" +
            "            let index = imgs.push(dataset.src) - 1;\n" +
            "            objs[i].onclick = function () {\n" +
            "                window.xxxxxx.openImage(imgs, index)\n" +
            "            }\n" +
            "        }\n" +
            "    }\n" +
            "})()";
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
        evaluateJavascript(js, null);
    } else {
        loadUrl(js);
    }
}
```

> evaluateJavascript()是比loadUrl()更高效的注入Js的做法，还支持回调，推荐