# Overview
The dhcpres.ps1 is a powershell script that will create DHCP reservationss for newly created hosts.


## How it Works

* linux part 
During the bottstrap procees the new host will temporarily mount 192.168.101.117:dhcp tro /mnt/nfs and creates DHCP_Reservations_$($Date).csv updating it with the hosts IP, MAC and NAME.

* Windows part
The script copies a csv file DHCP_Reservations_$($Date).csv which is stored on //util01/dhcp to DC02. Then it reads contents of csv file and makes the DHCP reservations based on the information.

## Notes
* Script is located on util01 c:\share\dhcp\dhcpres.ps1
* This script will be ran automaticaly twice a day at 09:00 and 17:00 
* Script logs are stored on DC02 c:\share\dhcp\DHCPReservations.txt 
