#! /usr/local/apps/networking/bin/python2.7
#  query service now to get info on circiuts
#  site info will be taken from current prod circuits
#  script will extract CID, vendor, cir priority and Bandwith
#
#  pwm 1/26/16

import requests
import json
import re
import sys
reload(sys)
sys.setdefaultencoding("utf-8")
import httplib2
#from __future__ import print_function

import pymysql
import itertools
import pprint
import time
import json
#from apiclient.discovery import build
#from oauth2client.file import Storage
#from oauth2client.client import AccessTokenRefreshError
#from oauth2client.client import OAuth2WebServerFlow
#from oauth2client.tools import run_flow
#from oauth2client.client import flow_from_clientsecrets

class PortMod(object):

    def __init__(self, number, sysid, intkey):
        self.number = number
        self.sysid = sysid
        self.intkey = intkey

def main():

    f = open('run_msgs_SN.log','w')        
    #print()
    pp = pprint.PrettyPrinter(depth=4)
    dic = get_circuits(f)
    #pp.pprint(dic)
    for i in range(len(dic)):
        obj = dic[i]
        write_sn(obj,f)
        # get post config string
    f.write('-main start-\n')
    f1 = open('pip_circuits.csv','w')
    f2 = open('pip_circuits_exceptions.csv','w')
    f3 = open('pip_circuits_sysid.csv','w')
    incr = 22
    arr =[] 
    for i in my_range(0,1000,incr):
        url = 'u_subclient_siteLIKE117.&sysparm_limit='+str(incr)+'&sysparm_offset='+str(i)+'&sysparm_display_value=true'
        ret_code,tmp_arr = process_sn(url,f)
        if ret_code =='':
           break
        else:
           print('SN RESTAPI i = '+str(i))
        arr.extend(tmp_arr)
    for i in range(len(arr)):
        #write_sn(arr[i],f) 
        cid,vendor,client,subclient,speed,prod,pri,port,site,sysid = get_item(arr[i],f)
        #f1.write(cid+','+vendor+','+client+','+subclient,speed,prod,pri,port,site)
        f1.write('%s,%s,%s,%s,%s,%s,%s,%s,%s\n' % (site,cid,client,subclient,prod,pri,port,speed,sysid))
    f.close()
    sys.exit(0)
def write_sn(str,f):
    #parsed = json.loads(str)
    f.write('\n-------sn dump begin -------\n')
    f.write(json.dumps(str, indent=4))
    f.write('\n-------sn dump output end-------\n')

def my_range(start, end, step):
    while start <= end:
        yield start
        start += step

def get_item(sn_dic,f):
    #print(type(sn_dic))
    cid = sn_dic['name']
    vendor = sn_dic['vendor']
    client = re.sub('117.*0\s*','',sn_dic['u_sponsor'])
    client = re.sub(',','/',client)
    subclient = re.sub('117.*$','',sn_dic['u_subclient_site'])
    subclient = re.sub(',','.',subclient)
    site = re.sub('^.*117\.','',sn_dic['u_subclient_site'])
    site = re.sub('\.0\s*$','',site)
    site = 'c'+site
    site = re.sub('\.','s',site)
    #if(site.find('s') != 0):
    #   site += 's0'
    speed = sn_dic['u_access_speed']
    port = str(sn_dic['u_port_speed'])
    prod = sn_dic['install_status']
    pri = sn_dic['u_primary']
    sysid = sn_dic['sys_id']
    return cid,vendor,client,subclient,speed,prod,pri,port,site,sysid

def get_post_config(intkey):
    config = ''
    conn = pymysql.connect(db='network_inv', user='user',passwd='password',host='119.0.200.99')
    cur = conn.cursor()
    cur.execute("select PostMod_Config,Status from PORTMOD_SERVICE_NOW_v where intkey =" + str(intkey) +" and PostMod_Config IS not NULL;")
    state =''
    #print(columns)
    for row in cur:
       #tmp = {columns[0]:row[0],columns[1]:row[1],columns[2]:row[2],columns[3]:row[3]}
       if row[1] != 'Completed':
          return '',''
       else:
          state =row[1]
       config+=row[0]+'\n'
    cur.close()
    conn.close()
    return config,state
def get_circuits(f):
    list = []
    conn = pymysql.connect(db='network_inv', user='user',passwd='password',host='119.0.0.205')
    cur = conn.cursor()

    cur.execute("select REC_ID,CID,Client,SubClient,Preference,Vendor_Info from RTNG_NEI_CLIENT_v order by Client,SubClient;")

    #print(cur.description)

    for row in cur.fetchall():
        f.write('\n--get_circuits--'+str(row)+'\n')
        dic = { 'REC_ID':  row[0],
                'CID': row[1],
                'Client': row[2],
                'SubClient': row[3],
                'Preference': row[4],
                'Vendor_Info': row[5]}
        list.append(dic)
        f.write('----\n')
      
    cur.close()
    conn.close()

    return list
#`
def upd_portmod(intkey,sys_id,f):
    list = []
#   conn = pymysql.connect(db='network_inv', user='user',passwd='password',host='119.0.0.205')
    conn = pymysql.connect(db='network_inv', user='user',passwd='password',host='119.0.200.99')
    cur = conn.cursor()
    cur.execute("select REC_ID from PORTMOD_SERVICE_NOW_v where intkey  = "+str(intkey)+";")
    f.write('-update portmod---'+str(intkey)+' '+sys_id+'\n')

    for row in cur:
        f.write('---rec_id --'+str(row)+' --intkey-> '+str(intkey)+'\n')
        list.append(row[0])
    cur.close()
    cur = conn.cursor()
    for recid in list:
        f.write('---update rec_id --'+str(recid)+' --intkey-> '+str(intkey)+'\n')
        #upd = "IF (select * FROM PORTMOD_SERVICE_NOW where REC_ID= %s) IS NULL THEN insert into PORTMOD_SERVICE_NOW (sys_id,REC_ID) VALUES ('%s',%s); END IF;" % (str(recid),sys_id,str(recid))
        upd = "INSERT INTO PORTMOD_SERVICE_NOW (sys_id,REC_ID) VALUES ('%s',%s) ON DUPLICATE KEY UPDATE sys_id= '%s';" % (sys_id,str(recid),sys_id)
        f.write('--upd:\n'+upd+'\n---end--upd\n')
        cur.execute(upd)
    upd = "UPDATE PORTMOD_SERVICE_NOW_v set `number` = `number` +1 where intkey  = "+str(intkey)+";"
    f.write('--upd inkey:\n'+upd+'\n---end--upd intkey\n')
    cur.execute(upd)
    conn.commit() 
    #print(cur.description)
    cur.close()
    conn.close()

    return list
def encode_sn(Post_Config,f):
    t_date = time.strftime("%Y-%m-%d")
    Post_Config = Post_Config.replace('\n','\r\n')
    json_dic={ 'end_date': t_date+' 22:00:00',
               'start_date': t_date+' 22:00:00',
               "close_notes": "Completed Portmod",
               "test_plan": Post_Config,
               'state': 3 }
    json_dic = json.dumps(json_dic)
    return json_dic
def defined(var):
    try:
       var
       return 0
    except:
       return 1

def process_sn(q,f):
    f.write('get_circuits--------------\n')
    url = 'https://tradingtech.service-now.com/api/now/table/u_cmdb_ci_network_circuits?sysparm_query='+q
    user = 'svc_ws_readwrite'
    pwd = '9USTAsat'
# Set proper headers
    headers = {"Accept":"application/json"}

    response = requests.get(url, auth=(user, pwd), headers=headers )
    f.write('response code is -> ' + str(response.status_code))
    f.write('\n'+url+'\n')
    if response.status_code != 200 or response.text =='':
        f.write('---record not found ---\n')
        print('---record not found ---')
        try:
           f.write('Status:', response.status_code, 'Headers:', response.headers, 'Error Response:',response.text)
           if defined(response.tex):
              write_sn(response.json(),f)
        except:
           pass
        f.write('+-- end record not found\n')
        return '',[]
    try: 
       arr = get_sn_records(response.json())
    except:
       f.write(' --- shit failed ----\n')
       if defined(response.tex):
           write_sn(response.json(),f)
       f.write(' ---END shit failed ----\n')
       print('shit failed')
       raw_input("wating for input ....")
       pass
       #return ''
    #print('-- in process_sn')
    #for i in range(len(arr)):
    #    write_sn(arr[i],f)
    return 1,arr
def patch_sn(sys_id,json_str,f):
    user = 'svc_ws_readwrite'
    pwd = '9USTAsat'
    # Set proper headers
    headers = {"Accept":"application/json"}
    url = 'https://tradingtechdev.service-now.com/api/now/table/change_request/'+sys_id
    response = requests.patch(url, auth=(user, pwd), headers=headers ,data=json_str)
    if response.status_code  !=201 and response.status_code  !=200:
        print('Status:', response.status_code, 'Headers:', response.headers, 'Error Response:',response.json())
        print("\n")
        # handle exception
        exit()
        # parse result
        #print('Status:',response.status_code,'Headers:',response.headers,'Response:',response.json())
    write_sn(response.json(),f)
    
def get_sn_records(lst):
    # Decode the JSON response into a dictionary and use the data
    #pp = pprint.PrettyPrinter(depth=4)
    lst = json.dumps(lst)
    #obj = json.loads(lst[0])
    #obj = json.JSONDecoder().decode(response.json())
    #print(type(lst))
    lst = re.sub('^.*\{"result": ','',lst)
    lst = re.sub('\}$','',lst)
    #if(lst.find('[')):
    lst = re.sub('^\[','',lst)
    lst = re.sub('\]$','',lst)
    lst = re.sub('^{','',lst)
    lst = re.sub('\}$','',lst)
    if re.search("}, {",lst):
       arr = lst.split("}, {")
    else:
       arr =[]
       arr.append(lst)
    ret_arr = []
    #print('length of arr is ->',len(arr))
    for i in range(len(arr)):
        arr[i] = re.sub('^','{',arr[i])
        arr[i] = re.sub('$','}',arr[i])
        #print (arr[i])
        obj = json.loads(arr[i])
        #pp.pprint(obj)
        tmp_dic = { "u_access_speed": obj['u_access_speed'],
                    "install_status": obj['install_status'],
                    "u_primary": obj['u_primary'], 
                    "u_port_speed": obj['u_port_speed'], 
                    "u_subclient_site": get_value(obj['u_subclient_site']),
                    "u_sponsor": get_value(obj['u_sponsor']),
                    "name": obj['name'],
                    "sys_id": obj['sys_id'],
                    "vendor": get_value(obj['vendor']) }
        ret_arr.append(tmp_dic)
    #for keys,values in lst.items():
    #    print(keys)
    #
    #    print(values)
    #    print('next\n\n')
    #print ('--done---')
    return ret_arr
def get_value(var):
    try:
       var['display_value']
       return var['display_value']
    except:
       return var

   
if __name__ == '__main__':
    main()

