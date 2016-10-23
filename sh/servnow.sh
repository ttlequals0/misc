#!/bin/bash
#This tool is creating servicenow tickets from command line. 

while getopts ":t:c:" option; do
 case $option in
 	t) export inc_title=$OPTARG ;;
	c) export inc_comment=$OPTARG ;;
	*) echo "ERROR: Unsupported flag, please use -t & -c" && exit 1
 esac
done 

if [ $# -eq 0 ]; then
export inc_title="SOC Incident ticket" 
fi 

username=$(whoami)

if [ ! -f /home/$username/abrics/.p.txt ]; then
read -p "Please, enter your LDAP password: " -s password
else
password_file="/home/$username/s/.p.txt"
password="$(cat $password_file)"
fi
echo 
read -p "Now enter your AD password: " -s ad_password

 echo -e "\n$(sshpass -p "$password" ssh -o StrictHostKeyChecking=no soc-tools-1.dnet 'curl --user '$username':'$ad_password'  --header "Content-Type:application/json"  --header "Accept: application/json"  --request POST  --data '\''{"short_description":"'$inc_title'","comments":"Created from bash command line script","assigned_to":"'$username'","assignment_group":"Service Operations Center","u_source":"Alarming/Monitoring","state":"In Progress","urgency":"5","u_product_reference":"Others","u_resolution":"In Progress"}'\''  https://z.service-now.com/api/now/v1/table/incident' 2>/dev/null | tr \" "\n" | grep INC) has been created.\n" || echo
