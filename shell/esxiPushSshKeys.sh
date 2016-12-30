#!/bin/bash
#Script is for pushing your public key to servers

red='\e[0;31m'
NC='\e[0m'
function usage {
echo -e "${red}ERROR:${NC} Please, give an argument for the server list \nExample: $0 serverlist"
}

if [ $# -eq 0 ]; then
    echo "Which servers you want to push keys?" && usage && exit 1
fi
echo -e "${red}#####################################################################
I assume you have a passphrase set up to your ssh keys!
If you have ssh keys but no passphrase, please CTRL -C out this script then
set your passphrase.(ssh-keygen -p). Please, wait and be patient this may take
a long time... If you do not have ssh keys in here, script will create one for you now.
#############################################################################${NC}"
sleep 5
echo  -n "Enter your password: "
read -s SSHPASS
echo
# Check if public key exist, if not create one.
if [[ ! -f ~/.ssh/id_rsa.pub ]]; then

    if [[ ! -d ~/.ssh/ ]]; then
        mkdir -m 0700 ~/.ssh
    fi

    cd ~/.ssh
    ssh-keygen -t rsa
fi

#Adding identity of yours:
eval `ssh-agent`
/usr/bin/ssh-add

#Create file for outfput for logging purposes
output_file="./esxPushSshKey.log"

key=$(cat ~/.ssh/id_rsa.pub)

# Check for home directories and .ssh directories in the servers; if none create one. Then push the key into authorized_keys file in the ~/.ssh/ dir.
for i in $(cat "$1"); do
 sshpass -p "$SSHPASS" ssh -l root  -o StrictHostKeyChecking=no -o NumberOfPasswordPrompts=1 -o ConnectTimeout=3 "$i" "if [ ! -d ~ ]; then
        /etc/profile.d/make_home_dir.sh
fi; if [ ! -d ~/.ssh/ ] ; then
        mkdir -m 0700 ~/.ssh
fi; echo $key >> /etc/ssh/keys-root/authorized_keys; chmod 600 /etc/ssh/keys-root/authorized_keys" && echo "$i -> SUCCESS!" || echo "$i -> FAILED" &
done | tee $output_file

echo -e "Script is complete! Output is saved into $(pwd) directory as $output_file."
exit
