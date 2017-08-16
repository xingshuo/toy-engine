Toy-Engine
========
    A lightweight server framework
Wiki
-----
    1.该框架由lua和c编写，非分布式，没有服务的概念，只有一个VM，一条工作线程.
      该框架核心模块提取自云风老师的skynet框架.设计上也参考了skynet源代码[https://github.com/cloudwu/skynet]
      可以认为是一个简陋的单VM版skynet,目前只支持了CS socket通信,定时器,toy-engine节点间通信等功能，与三方进程(如mysql,mongodb,redis)通信的功能暂未支持.
    2.examples/chatroom 为一个多人聊天室的简例，客户端程序可从终端读入消息，
      服务器广播给所有玩家，服务器定时向全部玩家发送server tick消息.
      examples/cluster 为一个节点间通信的简例,每隔2s向对方节点发送handshake消息包,对方收到后回复.
    3.该框架仅用于学习娱乐,没有任何商业价值.
三方库
-----
    lua5.3.4源码[https://www.lua.org/ftp/lua-5.3.4.tar.gz]
编译链接
-----
    make
环境搭建
-----
    多人聊天室:
        服务器: sh examples/chatgs.sh
        客户端: sh examples/chatcs.sh (port) (ip) #可多终端启动
    节点间通信:
        sh examples/cluster.sh 1
        sh examples/cluster.sh 2