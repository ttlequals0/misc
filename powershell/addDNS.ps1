#This Scripts creates DBS A records and the associated PTR record
#sCreate records.csv file with Computer,IP information 
#see example below add first line to your csv file 
# 
#Computer,IP 
#Computer,192.168.0.1 
#Computer1,192.168.0.2 
#Computer2,192.168.0.3 


#Connect to DC03
$session = New-PSSession -ComputerName dc03 

Invoke-Command -Session $session -ScriptBlock  {


Param(
    [string]$ServerName = "dc03",
    [string]$domain = "emmisolutions.com",
	[string]$Date = (Get-Date -F yyyy-MM-dd),
	[string]$InputCSV = "C:\share\dns\dnsRecords_$($Date).csv",
	[string]$log_file = "C:\share\dhcp\dnsRecords.txt"
)

 

Import-Csv $InputCSV | ForEach-Object { 
 
#Def variable 
$Computer = "$($_.Computer).$domain" 
$addr = $_.IP -split "\." 
$rzone = "$($addr[2]).$($addr[1]).$($addr[0]).in-addr.arpa" 
 
#Create Dns entries 
 
dnscmd $Servername /recordadd $domain "$($_.Computer)" A "$($_.IP)" 
 
#Create New Reverse Zone if zone already exist, system return a normal error 
dnscmd $Servername /zoneadd $rzone /primary 
 
#Create reverse DNS 
dnscmd $Servername /recordadd $rzone "$($addr[3])" PTR $Computer 
}
}