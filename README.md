Toy-Engine
========
    A lightweight server framework
Wiki
-----
    1.该框架由lua和c编写，非分布式，没有服务的概念，只有一个VM，一条工作线程.
      该框架核心模块提取自云风老师的skynet框架.设计上也参考了skynet源代码[https://github.com/cloudwu/skynet]
      可以认为是一个简陋的单VM版skynet,目前只支持了CS socket通信和timer两个模块，进程间通信的模块暂未支持.
    2.examples/文件夹下为一个多人聊天室的简例，客户端程序可从终端读入消息，
      服务器广播给所有玩家，服务器定时向全部玩家发送server tick消息.
    3.该框架仅用于学习娱乐,没有任何商业价值.
编译链接
-----
    make
环境搭建
-----
    服务器: sh rungs.sh
    客户端: sh runcs.sh (port) (ip) #多终端启动