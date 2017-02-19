#!/usr/local/apps/networking/bin/python2.7
# script will test all server client pairs with iperf
# several option will be available
# iperf will run between ap (server mode) and xtr (client mode)
### this is the prd script
# pmw 2/18/16
# 3 stages
# 1. selct all info pertaining to a site
#    cid, primary and secondary.  data paths from pip to dcs
#    exclude all ipsec tunnels
#    if same dc only pri circuit can be tested 
#    all reliable test will need not tested circuit to be put in passive 
#    PIP info is in PIP_Clients
#    ap_xtr pairs are in iperf_ap_xtr
#    reults are put in iperf_result
#
# pmw 6/1/2016

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
import pymysql
from httplib import HTTPSConnection
from base64 import b64encode
from common import *

#from servicenow import ChangeRequest, WebService, CSVService, ConfigurationItemFactory, CustomerFactory

socket.setdefaulttimeout(2)
report =''
#constants for sn
def get_time():
    return datetime.datetime.fromtimestamp(ts).strftime('%Y-%m-%d %H:%M:%S')

def run_script(ap,xtr,bw,dc,cid,fo,lock):
    global report
    # list[1] = AP
    # list[2] = XTR
    # bw = str(list[4])
    try:
        cmd = 'ssh -q -i ttnet_key -o \"StrictHostKeyChecking no\" -l ttnetsftp ';
        cmd += ap
        cmd += ' \"iperf -s -p51281 -u -D\"'
        history = cmd + '\n'
        #os.spawnl(os.P_NOWAIT,cmd)
        proc = subprocess.Popen(cmd,shell=True ,stdout=subprocess.PIPE)
        tmp = proc.stdout.read()
        print(tmp)
        cmd = 'ssh -q -i ttnet_key -o \"StrictHostKeyChecking no\" -l ttnetsftp ';
        cmd += xtr
        cmd += ' \"taskkill /f /im iperf.exe;iperf -c'
        cmd += ap
        cmd += ' -b'
        bw = str(bw)
        bw  = re.sub(r'\D','',bw)
        if float(bw) >100:
           cmd += '10'
        else:
           cmd += bw
        print('list of 5 (bandw)is ',bw)
        cmd += 'M'
        cmd += ' -p51281 -i1 -t10 -r\"'
        history += cmd + '\n'
        # add timeout 
        start = datetime.datetime.now()        
        proc = subprocess.Popen(cmd,shell=True ,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
        while proc.poll() is None:
            time.sleep(0.1)
            now = datetime.datetime.now()
            if (now - start).seconds> 60:
               os.kill(proc.pid, signal.SIGKILL)
               os.waitpid(-1, os.WNOHANG)
        tmp = proc.stdout.read()
        # remove 
        # end remove
        summary = get_summ(ap,cmd,tmp)
        cmd = 'ssh -q -i ttnet_key -o "StrictHostKeyChecking no" -l ttnetsftp ';
        cmd += ap
        cmd += ' "taskkill /f /im iperf.exe"'
        history += cmd + '\n' + ap + ','+ xtr + ','+ bw + ','+ str(summary)
        #rep = list[0] + ','+ list[3]+ ','+ bw + ','+ str(summary) + '\n'
        rep = '%s,%s,%s,%s,%s\n' % (cid,ap,xtr,bw,str(summary))
        proc = subprocess.Popen(cmd,shell=True ,stdout=subprocess.PIPE)
        tmp = proc.stdout.read()
        # print(tmp) 
        lock.acquire_lock()

        #print "%s\n" % history 
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

def get_route(site,route):
    ip = re.sub(r'c','',site,re.I)
    oct = ip.split('s')
    ip = '117.' + oct[0] +'.' +oct[1] +'.11'
    ip = re.sub(r'\-','',ip,re.I)
    cmd = './get_route.exp ' + ip + ' ' + route
    next_hop = ''
    print('looking for route -> %s %s %s' % (ip,route,site))
    start = datetime.datetime.now()
    proc = subprocess.Popen(cmd,shell=True ,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
    while proc.poll() is None:
        time.sleep(0.1)
        now = datetime.datetime.now()
        if (now - start).seconds> 10:
            os.kill(proc.pid, signal.SIGKILL)
            os.waitpid(-1, os.WNOHANG)
    tmp = proc.stdout.read()
    next_hop = extract_ip(tmp)
    if re.search(r'^116',next_hop):
       return next_hop
    ip = re.sub(r'11$','12',ip)
    start = datetime.datetime.now()
    cmd = './get_route.exp ' + ip + ' ' + route
    proc = subprocess.Popen(cmd,shell=True ,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
    while proc.poll() is None:
        time.sleep(0.1)
        now = datetime.datetime.now()
        if (now - start).seconds> 10:
            os.kill(proc.pid, signal.SIGKILL)
            os.waitpid(-1, os.WNOHANG)
    tmp = proc.stdout.read()
    next_hop = extract_ip(tmp)
    return next_hop

def initLogger():
    logger = logging.getLogger()
    logFormatter = logging.Formatter('%(levelname)s: %(message)s')
    logStreamHandler = logging.StreamHandler()
    logStreamHandler.setFormatter(logFormatter)
    logger.addHandler(logStreamHandler)

def get_pairs(site):
    global dmsg
    # from PIP_Clients get pri and sec
    cl,subcl = get_site(site)
    # get circuit info from PIP_Clients table
    cir = get_clients(cl,subcl)
    # get ap xtr from ap_xtr table
    ret = get_ap_xtr(cl,subcl)
    ap_xtr = {}
    for line in ret:
       #a = line.split(',')
       #print('line %s\n' % (line))
       
       #print('[get_pairs]PIP_Client cir -> %s' % str(line))
       dmsg += '[get_pairs]PIP_Client ret line -> %s\n' % str(line)
       cid = line[3]
       ap_xtr[cid] = line
    cid = ['','']
    dc = ['','']
    # get cid and dc for earch cs from RTNG_NEI_CLIENT_v table:
    cid[0],cid[1],dc[0],dc[1] = get_pip_cid(cl,subcl)   
    # if both dc are the same passive is required for testing
    #
    p_dc = {}
    p_cid = {}
    p_dc[fix_cid(cid[0])] =dc[0]
    p_dc[fix_cid(cid[1])] =dc[1]
    p_cid[fix_cid(cid[0])] =cid[0]
    p_cid[fix_cid(cid[1])] =cid[1]
    if dc[0] == dc[1]:
       passive = 'passive'
    else:
       passive = 'active'
    #print(p_dc)
    #print(p_cid)
    
    dmsg += '[get_pairs] p_dc,p_cid -> %s %s \n' % (str(p_dc),p_cid)
    lst=[]
    ap_arr =['','']
    for line in cir:
        #print('[get_pairs] line-> %s ' % str(line))
        dmsg +='[get_pairs] line-> %s \n' % str(line)
        cid = line[0]
        if cid =='':
           continue
        
        if not cid in p_dc.keys():
           t_cid = fix_cid(cid)
        else:
           t_cid = cid
        if t_cid in p_dc.keys():
           dc = p_dc[t_cid]
           #print('[get_pairs]p_dc -> %s' % str(p_dc[t_cid]))         
           dmsg += '[get_pairs] loop cid %s p_dc -> %s\n' % (cid,str(p_dc[t_cid]))   
        else:
           dc = ''
        if cid in ap_xtr.keys(): 
           ap_arr = ap_xtr[cid]
        else:
           # get first item from ap_xtr dic
           for kcid in ap_xtr.keys():
               ap_arr = ap_xtr[kcid]
        #lst[t_cid] = list(line)
        #lst[t_cid].append(dc)
        #print('cid %s t_cid %s' % (cid ,t_cid))
        dmsg += 'cid %s t_cid %s\n' % (cid ,t_cid)
        if not cid in p_cid.keys():
           if not t_cid in p_cid.keys():
              string = '%s,%s,%s,%s,%s,%s,%s,%s,%s' % (cid,ap_arr[0],ap_arr[1],dc,line[1],line[4],line[5],passive,ap_arr[7])
              dmsg +='MISSING [get_pairs] CID -> %s %s %s\n' % (site,cid,line[5])
              print('MISSING [get_pairs] CID -> %s %s %s\n' % (site,cid,line[5]))
           else:   
              string = '%s,%s,%s,%s,%s,%s,%s,%s,%s' % (p_cid[t_cid],ap_arr[0],ap_arr[1],dc,line[1],line[4],line[5],passive,ap_arr[7])
        else:   
           string = '%s,%s,%s,%s,%s,%s,%s,%s,%s' % (p_cid[cid],ap_arr[0],ap_arr[1],dc,line[1],line[4],line[5],passive,ap_arr[7])
        string = list(string.split(','))
        lst.append(string) 
        dmsg += '[get_pairs] AP-XTR -> %s \n' % str(lst)   
        #print(ap_arr)
        dmsg +='[get_pairs]PIP_Client -> %s\n' % (string)
    dmsg += '[get_pairs] return lst %s\n' % str(lst)
    return lst

def run_unsched(site,list,frep,passive,lock):
    global dmsg
    # items 1 ap
    # items 2 xtr
    # items 4 bw
    # items 3 bw
    # items 0 cid
    rep ='actual run is commented out %s %s %s' % (site,passive,str(list))
    rep = ''
    lst = []
    #print('len-> %s' % len(list))
    if len(list) > 3:
       lst.append(list)
    else:
       lst = list 
    for items in lst:
       # if items[1] or items[2] isnot an ip address
       # exit
       # send email
       if items[1]=='' or items[2] =='':
          print('%s ap and/or xtr not defined.  nothing to test' % site)
          return ''
       print(site +' '+items[0]+' '+items[1]+' '+items[2]+' '+str(items[4])+'M'+' '+items[7]+' '+str(passive) )
       #print(items[7])
       #rep =''
       if items[7] == 'passive' and not passive and items[6] != 'Primary':
          print('skipping passive not selected cant test secondary %s %s' % (items[6],passive))
       if passive:
          dmsg += ''
          # print('need to put in passive %s %s' % (items[7],passive))
          # put opposite cid in passive 
       rep += run_script(items[1],items[2],items[4],items[3],items[0], frep, lock)
       ############ run_script(ap,xtr,bw,dc,cid
       if passive:
          dmsg += ''
          # print('need to reverse passive %s %s' % (items[7],passive))
          # put opposite cid in passive 
       frep.write(rep)
       print(rep)
    return rep

def ping_test(ip):
    global dmsg
    cmd = "ping -c 2 " + ip
    proc = subprocess.Popen(cmd,shell=True ,stdout=subprocess.PIPE)
    response = proc.stdout.read()
    #print('ping res %s ' % response)
    if re.search(r' 0\%.packet.loss',response):
        dmsg += "[ping_test] %s\n" % response
        return True
    return False

def verify_xtr(xtr,site,list):
    # is it a valid ip? 
    # use ping
    if not re.search(r'^118(\.\d+){3}$',xtr):
       #print('Invalid IP address %s ' % xtr)
       return '',0
    if not ping_test(xtr):
       return '',0    
    # modify list based on xtr
    n_lst = []
    dc,cid = get_dc_cid(site,xtr)
    for lst in list:
        if re.search(cid,lst[0]):
           n_lst = lst
           n_lst[2] = xtr
           break
    if not n_lst:
       return n_lst,False
    return n_lst,True

def verify_ap(ap,site,list):
    if not re.search('3[12]$',ap):
       return []
    else:
       last_octet = re.sub(r'.*\.','',ap)
       site = re.sub('c','',site,re.I)
       oc1,oc2 = site.split('s')
       ap = '117.%s.%s.%s' % (oc1,oc2,last_octet)
       #print('ap-> %s' % ap)
       #print('len-> %s' % len(list))
       if len(list) >2:
          list[1] = ap
       else:   
          for lst in list:
            print('lst-> %s' % str(lst))
            lst[1] = ap
    return list
def present_list(list):
    for item in list:
        cid,ap,xtr,dc,bw,status,priorty,act = item[:8]
        xtrs = []
        xtrs = item[8:]
        print('CID: %s' % cid)
        print('AP: %s' % ap)
        print('Test XTR: %s' % xtr)
        print('DC: %s' % dc)
        print('SLA Bandwidth: %s Mbps' % bw)
        print('Status: %s' % status)
        print('Priority: %s' % priorty)
        print('Passive/Active: %s' % act)
        print('Available XTRs: %s\n' % ','.join(xtrs))
    return True 

def get_dc_cid(site,xtr):
    global report
    global dmsg
    #print('top site-> %s xtr-> %s ' % (site,xtr))
    dc =''
    cid =''
    a = xtr.split('.')
    rtr = a[0]+'.'+a[1]+'.'+a[2]+'.'
    site +='-'

    conn = pymysql.connect(host='119.0.0.205',db='network_inv',user='user',password='password')
    cur = conn.cursor()
    next_hop = get_route(site,xtr)
    if re.search(r'^116',next_hop):
       dmsg += 'site %s xtr %s next hop-> %s \n' % (site,rtr,next_hop)
       q = "select DC,CID,Client,SubClient from RTNG_NEI_CLIENT_v where A_Neighbor_IP like '%s' " % (next_hop)
       #print(q)
       dmsg += q +'\n'
       rows = cur.execute(q)
       if rows:
          for row in cur:
              #print(row)
              dc = row[0]
              if re.search(r'^Tu|^tbd$',row[1],re.I):
                 continue
              dmsg += 'get_dc_cid looking for cid -> '+str(row) + '\n'
              cid = row[1]

       dmsg += 'dc-> %s cid-> %s ' % (dc,cid)
       dmsg += '\n'
    cur.close()
    conn.close()
    #if site=='c100s2' or site =='c19s8' or site =='c20s24':
    #   print('%s %s dc-> %s cid-> %s \nq' % (site,xtr,dc,cid))
    #print('%s %s dc-> %s cid-> %s ' % (site,xtr,dc,cid))
    return dc,cid

def get_route(site,route):
    ip = re.sub(r'c','',site,re.I)
    oct = ip.split('s')
    ip = '117.' + oct[0] +'.' +oct[1] +'.11'
    ip = re.sub(r'\-','',ip,re.I)
    cmd = './get_route.exp ' + ip + ' ' + route
    next_hop = ''
    print('looking for route -> %s %s %s' % (ip,route,site))
    start = datetime.datetime.now()
    proc = subprocess.Popen(cmd,shell=True ,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
    while proc.poll() is None:
        time.sleep(0.1)
        now = datetime.datetime.now()
        if (now - start).seconds> 10:
            os.kill(proc.pid, signal.SIGKILL)
            os.waitpid(-1, os.WNOHANG)
    tmp = proc.stdout.read()
    next_hop = extract_ip(tmp)
    if re.search(r'^116',next_hop):
       return next_hop
    ip = re.sub(r'11$','12',ip)
    start = datetime.datetime.now()
    cmd = './get_route.exp ' + ip + ' ' + route
    proc = subprocess.Popen(cmd,shell=True ,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
    while proc.poll() is None:
        time.sleep(0.1)
        now = datetime.datetime.now()
        if (now - start).seconds> 10:
            os.kill(proc.pid, signal.SIGKILL)
            os.waitpid(-1, os.WNOHANG)
    tmp = proc.stdout.read()
    next_hop = extract_ip(tmp)
    return next_hop

def extract_ip(text):
    # format is
    # * ip, from
    lines = text.split('\n')
    for line in lines:
      if re.search(r', from',line):
         line = re.sub(r',.*$','',line)
         line = re.sub(r'^.*\s+','',line)
         print('ip-> %s' % line)
         return line
    return ''

if __name__=='__main__':
    report  =''
    global dmsg
    dmsg = ''
    initLogger()
    logger = logging.getLogger()
    logger.setLevel(logging.INFO)

    parser = argparse.ArgumentParser(description='test ap xtr pairs with iperf tool')
    parser.add_argument('-s', '--site', nargs=1 ,help='site to test', required=True)
    parser.add_argument('-p', '--passive', help='force passive',action ='store_true')
    parser.add_argument('-x', '--xtr', nargs=1 ,help='specify xtr', required=False)
    parser.add_argument('-a', '--ap', nargs=1 ,help='specify AP', required=False)
    parser.add_argument('-v', '--vip', help='test all xtrs associated with a vip',action ='store_true')
    parser.add_argument('-l', '--list', help='list default ap xtr for given site',action ='store_true')
    args = parser.parse_args()
    clientIps = []
    
    dmsg +='[main] args are -> %s\n' % str(args)    
    if not args.site:
       #list = get_pairs("tmp")
       sys.exit(1)
    else:
       print('site  -> %s' % ' '.join(args.site))
       site = args.site[0]
       list = get_pairs(args.site[0].lower())
       if not args.passive:
          passive = False
       else:
          passive = True
       if args.list:
          present_list(list)
          sys.exit(1)
       if args.xtr:
          list,stat = verify_xtr(args.xtr[0],site,list) 
          print('list-> %s' % str(list)) 
          if not stat:
             print('invalid xtr %s ' % args.xtr[0])
             sys.exit(1)
       if args.ap:
          ap = args.ap[0]
          list = verify_ap(ap,site,list)
          print('list-> %s' % str(list)) 
          if not list:
             print('invalid AP %s ' % ap)
             sys.exit(1)
    dmsg +='[main] (list array of ap xtr ) %s\n' % str(list)    
    lock = thread.allocate_lock()
    i =0
    frep = open('ondemand.rep','w')
    #run iperf for each ap -xtr pair in the list:
    report = run_unsched(site,list,frep,passive,lock)
    frep.close()
    fname = 'iperf_rep_ondemand_' + site +'.csv'
    frep = open(fname,'w')
    frep.write(report)
    frep = open('iperf_ondemand_run.log','w')
    frep.write(dmsg)
    frep.close()

