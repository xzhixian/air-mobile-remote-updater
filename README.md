# air-mobile-remote-executable-updater (REU)

This is an Adobe AIR/ActionScript module (swc) provides remote application update on mobile AIR app

这个 swc 针对 FLASH AIR 开发的手机客户端提供自动更新功能。

自动更新的逻辑如下：
把预装的版本号跟远程的版本比较, 如果远程的比较新，那么把远程的swf 拉到本地缓存，并且更新本地缓存版本号，然后用本地缓存
中间任何一步出异常，都自动回退，回退的规则是： 远程版本 > 退到本地缓存版本 > 退到预装版本


## 远程版本的文件

### 基本格式

文件格式： JSON

文件内容：

```
{
  "version" : 111,
  "url" : "http://path/to/remote/swf"
}
```

### 纯数值格式

远程文件的版本信息也可以是纯数字，如果是纯数字的话，就需要使用时指定远程swf的更新url

### 强制低版本整包更新格式

REU 支持对低版本的客户进行整包更新，只需要在版本信息文件中增加 `oldestAllowed` (低于这个版本就要整包更新了) 和 `throughlyUpdateUrl` (整包更新的 url)

```
{
	"version":21,
	"url":"http://mdthai.b0.upaiyun.com/remote.swf",
	"oldestAllowed" : 19,
	"throughlyUpdateUrl" : "http://you.client.have.to.update.com"
}
```

当客户端的版满足整包更新条件时，REU 会中断执行，并抛出 `gama.events.ForceUpdateEvent` 事件

## Requirement
 * AIR SDK 3.4 and higher

## 设计考量：

这个实现是一个基于函数编程的线性过程

设个实现设计的考量如下：
 1. 应该尽可能少的占用内存 —— 所以是一个单例的静态实现，所以只转手二进制而不持有二进制
 2. 应该努力释放不再使用的内容 —— 所以在过程中所创建的对象放在本地变量中，然后用动态创建的监听方法进行监听处理

## 使用示例

 https://github.com/GamaLabs/air-mobile-remote-updater/blob/demo/src/RemoteExecutableDemo.as






