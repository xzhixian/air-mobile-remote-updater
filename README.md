# air-mobile-remote-updater

This is an Adobe AIR/ActionScript module (swc) provides remote application update on mobile AIR app


## Requirement
 * AIR SDK 3.4 and higher

## 设计考量：

这个实现是一个基于函数编程的线性过程

设个实现设计的考量如下：
 1. 应该尽可能少的占用内存 —— 所以是一个单例的静态实现，所以只转手二进制而不持有二进制
 2. 应该努力释放不再使用的内容 —— 所以在过程中所创建的对象放在本地变量中，然后用动态创建的监听方法进行监听处理

## 使用示例

 https://github.com/GamaLabs/air-mobile-remote-updater/blob/demo/src/RemoteExecutableDemo.as






