#!/usr/local/apps/networking/bin/python2.7
# script will pull list all all devices and create
# shell script for obtaining data
#
# pmw 4/4/16
import os
import re
import sys
#from subprocess import Popen, PIP
import subprocess
import logging
from pprint import pprint
import argparse
import socket
import Queue
import threading
import thread
import smtplib
from httplib import HTTPSConnection
from base64 import b64encode
from datetime import datetime
import csv

def run_script(cmd):
    try:
        history = cmd + '\n'
        #os.spawnl(os.P_NOWAIT,cmd)
        proc = subprocess.Popen(cmd,shell=True ,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
        #tmp = proc.stdout.read()
        tmp, error = proc.communicate()
        if proc.returncode !=0:
           tmp =error
        print(tmp)
        return tmp
    except socket.error, e:
        print "%s,%s" % (ip, e)
        # kill server iperf
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


def main():
   my_data = []
   ip =[]
   f = open('iperf_pairs.csv', 'r')
   out = open('kill_iperf.ksh', 'w')
   top = """#!/bin/sh
#cd /home/user/dev_new
"""
   out.write(top)
   for  line in f:
      #print(list(reader))
      #raw_input()
      arr =[]
      arr = line.split(',')
      if arr[1] in ip:
         continue
      #print(arr)
      if re.search(r'117(\.\d+){3}',arr[1]):
         line = 'ssh -q -i ttnet_key -o "StrictHostKeyChecking no" -l ttnetsftp '+arr[1]+ ' "taskkill /f /im iperf.exe"'
         print(line)
         #run_script(line)
         line += ' &\n'
         out.write(line)
         ip.append(arr[1])
      if re.search(r'118(\.\d+){3}',arr[2]):
         if re.search(r'\(',arr[2]):
            arr[2] = re.sub(r'^.*\(','',arr[2])
            arr[2] = re.sub(r'\)','',arr[2])
         arr[2] = re.sub(r'\s+.*$','',arr[2])
         if arr[2] in ip:
            continue
         line = 'ssh -q -i ttnet_key -o "StrictHostKeyChecking no" -l ttnetsftp '+arr[2]+ ' "taskkill /f /im iperf.exe"'
         print(line)
         line += ' &\n'
         #run_script(line)
         out.write(line)
         ip.append(arr[2])

   out.write('wait\n')
   out.close
   os.chmod("kill_iperf.ksh",455)
def test_ssh(ip):
   return


if __name__=='__main__':
   main()

