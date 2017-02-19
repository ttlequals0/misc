#!/usr/local/apps/networking/bin/python2.7
# script will generate report for iperfs theat are 20% belowe the SLA
# db: iperf_results
### this is the prd script
# pmw 5/1/16
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
import smtplib
from httplib import HTTPSConnection
from base64 import b64encode


def get_rep(tresh):
    global dmsg
    # create html table with css
    tbl = """<table border = "1" style = "background-color: yellow; border: 1px dotted black; width:80%; border-collapse: collapse;">
    <tr style = "background-color: blue; color: white;">
    <th style = "padding: 3px;">"""
    tbl += 'CID' + '</th><th style = "padding: 3px;">'
    tbl += 'CS' + '</th><th style = "padding: 3px;">'
    tbl += 'Client Name' + '</th><th style = "padding: 3px;">'
    tbl += 'DC' + '</th><th style = "padding: 3px;">'
    tbl += 'Date Tested' + '</th><th style = "padding: 3px;">'
    tbl += 'SLA BW' + '</th><th style = "padding: 3px;">'
    tbl += 'Test BW' + '</th><th style = "padding: 3px;">'
    tbl += 'Priority' + '</th></tr>'

    rep ="""CID,Client,Subclient,DC,Date Tested,BW,Test BW,Priority\n"""
    
    conn = pymysql.connect(host='119.0.0.205',db='network_inv',user='user',password='password')
    cur = conn.cursor()
    q = "select CID,CONCAT('c',Client,'s',Subclient) as cs,Client_Name,DC,Date_Tested,BW,Test_BW,`Priority` from iperf_results where BW/Test_BW > %f" % (tresh)
    #print 'get_pip_cid ->\n'+q +'\n'
    cur.execute(q)
    i =0
    for row in cur:
       #print '%s client %s sub %s dc %s cid-> %s ' % (i,client,subclient,row[0],row[1])
       #print(q)
       dmsg += q +'\n'
       print(row)       
       tbl += '<tr>'
       for item in row:
           rep += str(item) + ','
           tbl += '<td style = "padding: 3px;">' + str(item) +'</td>'
       rep = re.sub(r',$','\n',rep)
       #rep += ','.join(row) + '\n'
       tbl += '</tr>'
       i += 1
    cur.close()
    conn.close()
    tbl += '</table>'
    return rep,tbl
def send_mail_exc(to,mrep_exc):
    fr = 'ttnet@ttnet.local'
    message = """From: Script <ttnet@ttnet.local>
Replay-To: user@domain
To: """+to+"""
Subject:  Iperf Test Exceptions
MIME-Version: 1.0
Content-Type: multipart/alternative; boundary="outer-boundary"

--outer-boundary
Content-Type: text/html; charset=us-ascii
Content-Transfer-Encoding: quoted-printable

<html>
<style type="text/css">
table {
background-color: yellow; border: 1px dotted black; width:80%; border-collapse: collapse;
}
th { background-color: blue; color: white; }
td { background-color: yellow; color: black; }
</style>
<body>
Following circuit did not pass iperf test.<br>
Note, additional testing might be needed.<br>
<br>
*This is still under development<br>
<br>
""" + mrep_exc + """
</body>
</html>

--outer-boundary--
"""
    try:
       smtpObj = smtplib.SMTP('localhost')
       smtpObj.sendmail(fr,to,message)
       print(message)
    except socket.error, e:
       print('error %s' % e)
    return

if __name__=='__main__':
   global dmsg
   dmsg =''
   rep,tbl = get_rep(1.2)
   print(rep) 
   send_mail_exc('user@domain',tbl)
   send_mail_exc('ptica1@hotmail.com',tbl)
