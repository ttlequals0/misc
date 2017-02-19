#!/usr/local/apps/networking/bin/python2.7
# script will test all server clinet pairs with iperf
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
from httplib import HTTPSConnection
from base64 import b64encode

#from servicenow import ChangeRequest, WebService, CSVService, ConfigurationItemFactory, CustomerFactory

socket.setdefaulttimeout(2)

#constants for sn
def get_time
    return datetime.datetime.fromtimestamp(ts).strftime('%Y-%m-%d %H:%M:%S')

def run_script(list,lock):
    try:
        cmd = 'ssh -q -i ttnet_key -o "StrictHostKeyChecking no" -l ttnetsftp ';
        cmd += list[2]
        cmd += ' "iperf -s -p51281 -u"'
        print(cmd)
        #proc = subprocess.Popen(cmd,shell=True ,stdout=subprocess.PIPE)
        #tmp = proc.stdout.read()
        os.spawnl(os.P_NOWAIT,cmd)
        cmd = 'ssh -q -i ttnet_key -o "StrictHostKeyChecking no" -l ttnetsftp ';
        cmd += list[1]
        cmd += ' '
        cmd += '"iperf -c'
        cmd += list[2]
        cmd += ' '
        cmd += '-b'
        cmd += list[5]
        cmd += ' -p51281 -i1 -t10 -r"'

        print(cmd)
        proc = subprocess.Popen(cmd,shell=True ,stdout=subprocess.PIPE)
        tmp = proc.stdout.read()
        summary = tmp
        summary = get_summ(ip,cmd,tmp)
        cmd = 'ssh -q -i ttnet_key -o "StrictHostKeyChecking no" -l ttnetsftp ';
        cmd += list[2]
        cmd += ' "taskkill /f /im iperf.exe"'
        print(cmd)
        proc = subprocess.Popen(cmd,shell=True ,stdout=subprocess.PIPE)
        tmp = proc.stdout.read()
        
        lock.acquire_lock()
 
        print "%s\n" % summary 
        lock.release_lock()
        return True
    except socket.error, e:
        lock.acquire_lock()
        print "%s,%s" % (ip, e)
        # kill server iperf
        lock.release_lock()
        return False

def get_summ(ip,cmd,tmp):
    lines = tmp.split('\n')
    for line in lines:
       a = line.split()
       if line.find('Kbits/sec')
          return a[4]
    return sum
def initLogger():
    logger = logging.getLogger()
    logFormatter = logging.Formatter('%(levelname)s: %(message)s')
    logStreamHandler = logging.StreamHandler()
    logStreamHandler.setFormatter(logFormatter)
    logger.addHandler(logStreamHandler)

def get_pairs(inp):
    f = open(inp)
    lines = f.read().split('\n')
    list = []
    for line in lines:
       a = line.split(',')
       #print('line %s\n' % (line))
       #print('a is -> %s\n' % (a))
       if len(a) >2:
          list.append(a)

    return list

if __name__=='__main__':
    initLogger()
    logger = logging.getLogger()
    logger.setLevel(logging.INFO)

    parser = argparse.ArgumentParser(description='test ap xtr pairs')
    parser.add_argument('-f', '--file', nargs=1 ,help='file. format: group,from,to', required=False)
    args = parser.parse_args()
    clientIps = []
    
    
    if not args:
       # assume followinf files:
       # iperf_pairs_thread.csv
       # iperf_pairs_thread.csv
       list = get_pairs("iperf_pairs_thread.csv")
    list = get_pairs("iperf_pairs_thread.csv")
    list = get_pairs("tmp")
    lock = thread.allocate_lock()
    i =0
    for items in list:
        i += 1
        print(items[0]+' '+items[1]+' '+items[2] )
        # start iperf on server
        # run iperf on client also then done kill iperf on server
        t = threading.Thread(target=run_script, args=(items, lock))
        t.start()



