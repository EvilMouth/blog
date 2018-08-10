---
layout: post
title: 亚马逊S3`POST`上传策略
date: 2018-06-07 11:43:11
tags: amazon
categories: Backend
---

## 前言

最近在写后端，需要后端生成`token`给前端直接上传文件到`S3`，减轻服务器压力，记录一下踩的坑，附上官方文档
[https://docs.aws.amazon.com/zh_cn/AmazonS3/latest/API/sigv4-UsingHTTPPOST.html](https://docs.aws.amazon.com/zh_cn/AmazonS3/latest/API/sigv4-UsingHTTPPOST.html)

<!-- More -->

## 上传策略

第一步就是要创建上传策略，官方提供的模板是这样的，根据自己需要增加或减少策略属性，最终将这么一串策略进行`base64`编码一下得到`StringToSign`
```json
{ "expiration": "2015-12-30T12:00:00.000Z",
  "conditions": [
    {"bucket": "sigv4examplebucket"},
    ["starts-with", "$key", "user/user1/"],
    {"acl": "public-read"},
    {"success_action_redirect": "http://sigv4examplebucket.s3.amazonaws.com/successful_upload.html"},
    ["starts-with", "$Content-Type", "image/"],
    {"x-amz-meta-uuid": "14365123651274"},
    {"x-amz-server-side-encryption": "AES256"},
    ["starts-with", "$x-amz-meta-tag", ""],

    {"x-amz-credential": "AKIAIOSFODNN7EXAMPLE/20151229/us-east-1/s3/aws4_request"},
    {"x-amz-algorithm": "AWS4-HMAC-SHA256"},
    {"x-amz-date": "20151229T000000Z" }
  ]
}
```

那好吧，这么一串`json`属性又多，格式又乱，那应该有提供生成器吧，结果看了半天api文档都没找到（可能是我眼花了，有找到的朋友告知一下谢谢），介绍文档也只是说需要怎么操作，并没有提供工具。那只好自己来生成，我的思路是在本地新建个`policy.json`文件，将我需要的最终策略的`json`形式复制在里面，然后代码读取动态替换掉`value`，类似这样：`string.replaceAll("replace-bucket", bucket)`
```json
{
  "expiration": "replace-expiration",
  "conditions": [
    {
      "bucket": "replace-bucket"
    },
    [
      "starts-with",
      "$key",
      "replace-dir"
    ],
    {
      "acl": "replace-acl"
    }
}
```

最后`base64`一下就拿到`StringToSign`，后面签署签名的时候要用到
```java
// BinaryUtils是amazon sdk提供的工具
String encodePolicy = BinaryUtils.toBase64(policy.getBytes("utf-8"));
```

## 签名key

创建完`policy`之后就是创建`签名key`了，这一步文档倒是说得比较明白

![](http://images.zyhang.com/18-6-7/92746579.jpg)

官方也有提供对应的`HMAC-SHA256`
```java
private static byte[] HmacSHA256(String data, byte[] key) throws Exception {
    String algorithm = "HmacSHA256";
    Mac mac = Mac.getInstance(algorithm);
    mac.init(new SecretKeySpec(key, algorithm));
    return mac.doFinal(data.getBytes("utf-8"));
}

private static byte[] getSignatureKey(String key, String dateStamp, String regionName, String serviceName) throws Exception {
    byte[] kSecret = ("AWS4" + key).getBytes("utf-8");
    byte[] kDate = HmacSHA256(dateStamp, kSecret);
    byte[] kRegion = HmacSHA256(regionName, kDate);
    byte[] kService = HmacSHA256(serviceName, kRegion);
    byte[] kSigning = HmacSHA256("aws4_request", kService);
    return kSigning;
}
```

- key : AWSAccessKeySecret
- dateStamp : 过期日期，需要跟策略的credential date一致
- regionName : 服务地区名称[https://docs.aws.amazon.com/zh_cn/general/latest/gr/rande.html#s3_region](https://docs.aws.amazon.com/zh_cn/general/latest/gr/rande.html#s3_region)
- serviceName : AWS服务名称，这里是s3

## 签名

最后一步就是拿着`签名key`签署`StringToSign`，还是用官方提供的`HMAC-SHA256`，最终得到的是`byte[]`类型的签名，需要转换成`string`类型
```java
private static String byte2hex(byte[] b) {
    StringBuilder hs = new StringBuilder();
    String stmp;
    for (int n = 0; b != null && n < b.length; n++) {
        stmp = Integer.toHexString(b[n] & 0XFF);
        if (stmp.length() == 1)
            hs.append('0');
        hs.append(stmp);
    }
    return hs.toString().toLowerCase();
}
```

- 这里也是要注意签名的大小写，弄了半天大写一直说签名不对

## 签名例子
```java
String policy = ...;
String encodePolicy = BinaryUtils.toBase64(policy.getBytes("utf-8"));
byte[] bytes = getSignatureKey(accessKeySecret, "20180606", "ap-southeast-1", "s3");
String signature = byte2hex(HmacSHA256(encodePolicy, bytes));
```

## 返回数据

根据上面三步拿到两个`POST`上传需要的东西`encode-policy`和`signature`，然后将其他策略条件一并返回给前端，让前端直接将文件上传到`s3`

![](http://images.zyhang.com/18-6-7/7536730.jpg)