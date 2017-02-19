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
#constants for sn
def get_time():
    #return datetime.datetime.fromtimestamp(ts).strftime('%Y-%m-%d %H:%M:%S')
    return datetime.datetime.strftime(datetime.datetime.now(), '%Y-%m-%d %H:%M:%S')
def get_sorted(file):
    cmd = 'cat '+file+' | grep ",118" | grep -v Tu116 | sort -t"," -k3,3'
    proc = subprocess.Popen(cmd,shell=True ,stdout=subprocess.PIPE)
    tmp = proc.stdout.read()
    list = tmp.split('\n')
    last = ''
    curr =0
    e_lst = {}
    for l in list:
       elem = l.split(',')
       print(elem)
       if len(elem) <2:
          break
       if last == elem[2]:
          # add line to lists
          curr += 1
       else:
          curr = 0
          last = elem[2]
       if curr in e_lst.keys():
          e_lst[curr] += '\n'+l
       else:
          e_lst[curr] = l
    list = []
    for l in e_lst.keys():
       print("next list %s " % l) 
       print(e_lst[l])   
       list.append(e_lst[l])
    return list

def run_script(list,fo,lock):
    global report
    global dmsg
    try:
        cmd = 'ssh -q -i ttnet_key -o \"StrictHostKeyChecking no\" -l ttnetsftp ';
        cmd += list[1]
        cmd += ' \"taskkill /f /im iperf.exe;iperf -s -p51281 -u -D\"'
        history = cmd + '\n'
        #os.spawnl(os.P_NOWAIT,cmd)
        proc = subprocess.Popen(cmd,shell=True ,stdout=subprocess.PIPE)
        tmp = proc.stdout.read()
        dmsg += tmp + '\n'
        cmd = 'ssh -q -i ttnet_key -o \"StrictHostKeyChecking no\" -l ttnetsftp ';
        cmd += list[2]
        cmd += ' \"taskkill /f /im iperf.exe;iperf -c'
        cmd += list[1]
        cmd += ' -b'
        bw  = re.sub(r'\D','',str(list[5]))
        if bw =='':
           bw =10
        if float(bw) >100:
           cmd += '10'
        else:
           cmd += str(bw)
        dmsg += 'list of 5 (bandw)is ' +str(bw)+ '\n'
        cmd += 'M'
        cmd += ' -p51281 -i1 -t10 -r\"'
        history += cmd + '\n'
        # add timeout 
        start = datetime.datetime.now()        
        proc = subprocess.Popen(cmd,shell=True ,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
        while proc.poll() is None:
            time.sleep(0.1)
            now = datetime.datetime.now()
            if (now - start).seconds> 59:
               os.kill(proc.pid, signal.SIGKILL)
               os.waitpid(-1, os.WNOHANG)
        tmp = proc.stdout.read()
        # remove 
        # end remove
        summary = get_summ(list[1],cmd,tmp)
        cmd = 'ssh -q -i ttnet_key -o "StrictHostKeyChecking no" -l ttnetsftp ';
        cmd += list[1]
        cmd += ' "taskkill /f /im iperf.exe"'
        history += cmd + '\n' + list[0] + ','+ list[4]+ ','+ str(bw) + ','+ str(summary)
        rep = list[0] + ','+ list[4]+ ','+ str(bw) + ','+ str(summary) + '\n'
        proc = subprocess.Popen(cmd,shell=True ,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
        while proc.poll() is None:
            time.sleep(0.1)
            now = datetime.datetime.now()
            if (now - start).seconds> 60:
               os.kill(proc.pid, signal.SIGKILL)
               os.waitpid(-1, os.WNOHANG)
        tmp = proc.stdout.read()
        #print(tmp) 
        dmsg += tmp + '\n'
        lock.acquire_lock()
        report += rep
        dmsg += history + '\n'
        lock.release_lock()
        return rep
    except socket.error, e:
        lock.acquire_lock()
        print "%s,%s" % (ip, e)
        # kill server iperf
        lock.release_lock()
        return False

def get_summ(ip,cmd,tmp):
    global dmsg
    lines = tmp.split('\n')
    #print(len(lines))
    i =0
    sum = 0
    for line in lines:
       if re.search(r'Mbits/sec.*ms.*\%',line):
          line = re.sub(r'^.*Bytes\s+','',line) 
          #print(line)
          a = line.split()
          i += 1
          rate = float(a[0])
          sum += rate
          #print('lin -> %s, %i' % (rate,i))
          dmsg += line +'\n' + 'lin -> '+str(rate) + ', '+ str(i)
    if i==0:
       return 0 
    return round((sum / i),2)

def initLogger():
    logger = logging.getLogger()
    logFormatter = logging.Formatter('%(levelname)s: %(message)s')
    logStreamHandler = logging.StreamHandler()
    logStreamHandler.setFormatter(logFormatter)
    logger.addHandler(logStreamHandler)

def get_pairs(site):
    f = open('iperf_pairs.csv','r')
    list = []
    for line in f:
       a = line.split(',')
       #print('line %s\n' % (line))
       #print('a is -> %s\n' % (a))
       if re.search(site,line,re.I):
          list.append(a)
    f.close()
    return list

def run_unsched(list,frep,lock):
    for items in list:
       print(items[0]+' '+items[1]+' '+items[2]+' '+items[5]+'M' )
       rep = run_script(items, frep, lock)
       frep.write(rep)
    return True

def some_fun():
    global report 
    initLogger()
    logger = logging.getLogger()
    logger.setLevel(logging.INFO)

    parser = argparse.ArgumentParser(description='test ap xtr pairs')
    parser.add_argument('-s', '--site', nargs=1 ,help='site to test', required=True)
    args = parser.parse_args()
    clientIps = []
    
    print('args are -> %s' % args)    
    if not args.site:
       #list = get_pairs("tmp")
       sys.exit(1)
    else:
       print('args are -> %s' % args.site)
       list = get_pairs(args.site[0])
        
    lock = thread.allocate_lock()
    i =0
    frep = open('tmp_rep','w')
    #for items in list:
    run_unsched(list,frep,lock)
    frep.close()
    frep = open('iperf_rep_1.csv','w')
    frep.write(report)
    frep.close()

def main():
    global report
    global dmsg
    report = ''
    dmsg = get_time() + '\n'
    start = datetime.datetime.now()        
    list = get_sorted('iperf_pairs.csv')
    lock = thread.allocate_lock()
    i =0
    frep = open('iperf_rep.csv','w')
    #for items in list:
    for l in list:
      lst = l.split('\n')
      print('starting next batch ')
      for line in lst:
        items = line.split(',')
        i += 1
        print(items[0]+' '+items[1]+' '+items[2]+' '+items[5] )
        dmsg += '[main] iperf to be run on %s %s %s %s \n' % (items[0],items[1],items[2],items[5])
        # start iperf on server
        # run iperf on client also then done kill iperf on server
        t = threading.Thread(target=run_script, args=(items, frep, lock))

        t.start()
      # wait 90 sec before moving to next
      #time.sleep(60)
      t.join()
    frep.write(report)
    frep.close()
    frep = open('perf_run_msgs.log','w')
    frep.write(dmsg)
    dmsg = get_time() + '\n'
    frep.write(dmsg)
    frep.close()
    print('Run time -> %s sec' %((datetime.datetime.now() - start).seconds))

if __name__=='__main__':
    main()
