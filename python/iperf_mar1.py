#!/usr/local/apps/networking/bin/python2.7
# script will test all server clinet pairs with iperf
### this is the prd script
# pmw 2/18/16
import os
import re
import sys
import datetime
#from subprocess import Popen, PIP
import subprocess
import logging
from pprint import pprint
import argparse
import socket
import Queue
import threading
import thread
import signal
import time
from httplib import HTTPSConnection
from base64 import b64encode

#from servicenow import ChangeRequest, WebService, CSVService, ConfigurationItemFactory, CustomerFactory

socket.setdefaulttimeout(2)
report =''
#constants for sn
def get_time():
    return datetime.datetime.fromtimestamp(ts).strftime('%Y-%m-%d %H:%M:%S')

def run_script(list,fo,lock):
    global report
    try:
        cmd = 'ssh -q -i ttnet_key -o \"StrictHostKeyChecking no\" -l ttnetsftp ';
        cmd += list[1]
        cmd += ' \"iperf -s -p51281 -u -D\"'
        history = cmd + '\n'
        #os.spawnl(os.P_NOWAIT,cmd)
        proc = subprocess.Popen(cmd,shell=True ,stdout=subprocess.PIPE)
        tmp = proc.stdout.read()
        print(tmp)
        cmd = 'ssh -q -i ttnet_key -o \"StrictHostKeyChecking no\" -l ttnetsftp ';
        cmd += list[2]
        cmd += ' \"taskkill /f /im iperf.exe;iperf -c'
        cmd += list[1]
        cmd += ' -b'
        bw = str(list[5])
        bw  = re.sub(r'\D','',bw)
        if bw =='':
           bw =10
        if float(bw) >100:
           cmd += '10'
        else:
           cmd += str(bw)
        print('%s %s -> %s list of 5 (bandwidth) is %s' % (list[0],list[1],list[2],bw))
        cmd += 'M'
        cmd += ' -p51281 -i1 -t10 -r\"'
        history += cmd + '\n'
        # add timeout.  kill after 60 sec
        start = datetime.datetime.now()
        proc = subprocess.Popen(cmd,shell=True ,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
        while proc.poll() is None:
            time.sleep(0.5)
            now = datetime.datetime.now()
            if (now - start).seconds> 60:
               os.kill(proc.pid, signal.SIGKILL)
               os.waitpid(-1, os.WNOHANG)
        tmp = proc.stdout.read()
        # remove 
        # end remove
        summary = get_summ(list[1],cmd,tmp)
        cmd = 'ssh -q -i ttnet_key -o "StrictHostKeyChecking no" -l ttnetsftp ';
        cmd += list[1]
        cmd += ' "taskkill /f /im iperf.exe"'
        history += cmd + '\n' + list[0] + ','+ list[4]+ ','+ list[5] + ','+ str(summary)
        rep = list[0] + ','+ list[4]+ ','+ list[5] + ','+ str(summary) + '\n'
        proc = subprocess.Popen(cmd,shell=True ,stdout=subprocess.PIPE)
        tmp = proc.stdout.read()
        print(tmp) 
        lock.acquire_lock()
        if fo.closed: 
           fo = open('iperf_new.csv','a')
        report += rep
        fo.write(rep)

        print "%s\n" % history 
        lock.release_lock()
        return rep
    except socket.error, e:
        lock.acquire_lock()
        print "%s,%s" % (ip, e)
        # kill server iperf
        lock.release_lock()
        return False

def get_summ(ip,cmd,tmp):
    lines = tmp.split('\n')
    print(len(lines))
    i =0
    sum = 0
    for line in lines:
       if re.search(r'Mbits/sec.*ms.*\%',line):
          line = re.sub(r'^.*Bytes\s+','',line) 
          print(line)
          a = line.split()
          i += 1
          rate = float(a[0])
          sum += rate
          print('lin -> %s, %i' % (rate,i))
    if i==0:
       return 0 
    return round((sum / i),2)

def initLogger():
    logger = logging.getLogger()
    logFormatter = logging.Formatter('%(levelname)s: %(message)s')
    logStreamHandler = logging.StreamHandler()
    logStreamHandler.setFormatter(logFormatter)
    logger.addHandler(logStreamHandler)

def get_pairs(inp):
    f = open(inp)
    lines = f.read().split('\n')
    f.close()
    list = []
    for line in lines:
       a = line.split(',')
       #print('line %s\n' % (line))
       #print('a is -> %s\n' % (a))
       if len(a) >2:
          list.append(a)

    return list

def run_unsched(list,frep,lock):
    for items in list:
       #print(items[0]+' '+items[1]+' '+items[2]+' '+items[5]+'M' )
       rep = run_script(items, frep, lock)
       frep.write(rep)
       print(rep)
    return True

if __name__=='__main__':
    global report
    report  =''
    initLogger()
    logger = logging.getLogger()
    logger.setLevel(logging.INFO)

    parser = argparse.ArgumentParser(description='test ap xtr pairs')
    parser.add_argument('-f', '--file', nargs=1 ,help='file. format: group,from,to', required=False)
    parser.add_argument('-o', '--output', nargs=1 ,help='file. output file', required=False)
    args = parser.parse_args()
    clientIps = []
    
    print('args are -> %s' % args)    
      
    lock = thread.allocate_lock()
    if not args.output:
       frep = open('iperf_results.csv','w')
    else:
       frep = open(args.output[0],'w')
    if not args.file:
       list = get_pairs("iperf_pairs_short.csv")
    else:
       print('args are -> %s' % args.file)
       list = get_pairs(args.file[0])
    
    run_unsched(list,frep,lock)
    frep.close()
    frep = open('iperf_rep_2.csv','w')
    frep.write(report)
    frep.close()

