import socket
import os
import struct
import sys
import threading
import thread
import time

ip = '0.0.0.0'
port = 8888
if len(sys.argv) > 1:
    port = int(sys.argv[1])
    if len(sys.argv) > 2:
        ip = sys.argv[2]

def date_str():
    return time.strftime('%Y-%m-%d %H:%M:%S',time.localtime(time.time()))

def sock_send(fd, data):
    fd.sendall(struct.pack("!H", len(data)) + data)

def sock_recv(fd):
    data = fd.recv(4096) #not strict
    if len(data) < 2:
        return ""
    ilen = struct.unpack('!H', data[:2])[0]
    return data[2:2+ilen]

def cs_chat_in(fd):
    while True:
        try:
            line = sys.stdin.readline()
        except:
            break
        if not line:
            break
        sock_send(fd, line)

def cs_chat_out(fd):
    while True:
        msg = sock_recv(fd)
        if not msg:
            break
        msg = msg.replace("\n","")
        dct = eval("%s"%(msg))
        if dct["sender"] == 0:
            print "[%s][System]:%s\n"%(date_str(),dct["msg"])
        else:
            if dct["sender"] == dct["self"]:
                print "[%s][Yourself(%s)]:%s\n"%(date_str(),dct["self"],dct["msg"])
            else:
                print "[%s][Player-%s]:%s\n"%(date_str(),dct["sender"],dct["msg"])

ss=socket.socket(socket.AF_INET,socket.SOCK_STREAM)

print "connect:%s:%d start"%(ip,port)
ss.connect((ip,port))
print "connect:%s:%d end"%(ip,port)

t = threading.Thread(target = cs_chat_in, args = (ss,))
t.daemon = True
t.start()
cs_chat_out(ss)