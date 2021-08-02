#!/bin/bash
# This was writen by Murray Phillips (aka: Lucky) for simple use to send commands to multiple servers that you have or want to add to /etc/hosts
# It mainly works with Linux distros, but can work with bsd servers if you install sudo and add the user to sudoers
# This is not meant to be used in a professional environment. Was written just to send commands to multiple servers at once. With some testing and cleaning up, it could be used
# Use at own risk.

declare -A servers

red=`tput setaf 1`
green=`tput setaf 2`
blue=`tput setaf 4`
reset=`tput sgr0`

default_users=($( awk -F: '{ if($3>999 && $3<65000){ print $1 } }' /etc/passwd ))
default_user=${default_users[0]}

Remove_Key()
{
    su $serveruser -c "ssh-keygen -f \"$user_home/.ssh/known_hosts\" -R \"$server\""
}

Select_Server()
{
    host_servers=($( awk -F"\t" '{ print $2 }' /etc/hosts ))
    printf "\n - Choose Server from your /etc/hosts OR add new server or IP address\n\n **** ${blue}You can also choose multiple servers separated by a comma. 1,2,3,4${reset} ****\n\n"
    echo "0 - Return to main menu"

    for (( i = 0 ; $i < ${#host_servers[@]} ; i += 1 ))
    {
        echo $((i+1)) "-" ${host_servers[$i]}
    }    
    read server
    if [[ $server =~ ^[-+]?[0-9]+$ ]]
    then
        if [ "$server" -gt "${#host_servers[@]}" ]; then
            echo ""
            echo "HUH!? $server is greater than ${#host_servers[@]}"
            echo "${red} !!!!! That server doesn't exist !!!!! ${reset}"
            _start
        fi
        if [[ $(($server)) -eq 0 ]]
        then
            _start
        fi
        server=${host_servers[$((server-1))]}
        Add_Server "$server"
    elif [[ $server == "" ]]; then
        _start
        
    elif [[ $server == *","* ]]; then
        IFS=',' read -r -a s <<< "$server"
        
        for (( server_i = 0 ; $server_i < ${#s[@]} ; server_i ++ ))
        {
            Add_Server "${host_servers[$((s[$server_i]-1))]}"
        }   
    else
        Add_Server "$server"
    fi 
    printf "\n\n Add Another? (Y/n)\n"
    read another
    if [[ "$another" != "n" ]]; then
    Select_Server
    else
    _start
    fi    
}


Set_Keys()
{    
    echo ${servers[$1]}
    IFS=',' read -r -a s <<< "${servers[$1]}"
    server="${s[0]}"
    serveruser="${s[1]}"
    userpw="${s[2]}"
    rootpw="${s[3]}"
    KEY="${s[4]}"
    serverport="${s[5]}"
    user_home=$(bash -c "cd ~$(printf %q $serveruser) && pwd")

    ip=$(grep '\s'$server'' /etc/hosts | awk '{print $1}')
    su $serveruser -c "ssh-keygen -f \"$user_home/.ssh/known_hosts\" -R \"$ip\""
    su $serveruser -c "ssh-keygen -f \"$user_home/.ssh/known_hosts\" -R \"$server\""
    su $serveruser -c "sshpass -p $userpw ssh-copy-id -o StrictHostKeyChecking=no -o ConnectTimeout=5 -i $KEY $serveruser@$server -p $serverport"        
}

Set_Keys_SRV()
{
    i=1
    printf "\nThis will remove and reset the keys to the remote hosts to allow auto connections.\n
        You can remove these keys when you finish using the application if you choose to.\n\n"
        
    echo "0 - ALL"
    for keys in "${!servers[@]}"
    do
    
#       serv="$server[0],$serveruser[1],$userpw[2],$rootpw[3],$KEY[4],$serverport[5]"
        IFS=',' read -r -a s <<< "${servers[$keys]}"
        echo $((i++)) "-" ${s[0]}
        k+=($keys)
    done
    echo ""
    echo " ===================================="
    echo ""

    
    read svrkeys
    if [[ $svrkeys =~ ^[-+]?[0-9]+$ ]]
    then
        if [[ "$svrkeys" == "0" ]]; then
            echo "Resetting all keys"
            for nextkeys in "${!servers[@]}"
            do
                Set_Keys "$nextkeys"
            done            
        else
        Set_Keys "${k[$((svrkeys-1))]}"
        fi
        _start
    elif [[ $svrkeys == *","* ]]; then
        IFS=',' read -r -a sv <<< "$svrkeys"    
        for (( server_k = 0 ; $server_k < ${#s[@]} ; server_k ++ ))
        {
            Set_Keys "${k[$((svrkeys-1))]}"
        }         
    else
        _start
    fi   
}


Add_Server()
{
    if [[ -v servers[$1] ]] ; then
        unset -v servers[$1]
        echo "unsetting $1"
    fi
    server=$1
    cat << EOF
    **** This will add an automated key to the server. You can remove this later if you wish ****

    
EOF
    if ! command -v sshpass &> /dev/null
    then
        echo " For Automation, sshpass needs to be installed on this computer."
        echo " Install sshpass? (Y/n)"
        read sshp
        if [ "$sshp" == "n" ]
        then
        exit
        else
            if ! command -v apt-get &> /dev/null; then
                apt-get install -y sshpass
            elif ! command -v apt &> /dev/null; then
                apt install -y sshpass
            elif ! command -v pkg &> /dev/null; then
                pkg install -y sshpass
            fi
        fi
    fi
    
    if [ ! -n "$(grep $server /etc/hosts)" ]
        then
            echo "Add server to /etc/hosts? (Y/n)"
            read add_host_answer
            if [ "$add_host_answer" != "n" ]; then
                if [[ $server =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
                    echo "Enter the server name you want to add. i.e. ubuntu-worker1"
                    read s
                    echo -e "$server\t$s" >> /etc/hosts
                    $server=$s
                else
                    echo "Enter the IP address of $server"
                    read s
                    echo -e "$s\t$server" >> /etc/hosts
                fi
            fi
    fi
    
    echo " - Port to use to connect to $server (Default:22) r to Return to main menu"
    read sp
    if [[ $sp =~ ^[-+]?[0-9]+$ ]]
    then
        serverport=$sp
    elif [[ $sp == "" ]]; then
        serverport=22
    else
        _start
    fi     
    echo " - User used to gain access to that server (Default:$default_user) r to Return to main menu"

    for (( i = 0 ; $i < ${#default_users[@]} ; i += 1 ))
    {
        echo $((i+1)) "-" ${default_users[$i]}
    }
    read svruser
    if [[ $svruser =~ ^[-+]?[0-9]+$ ]]
    then
        serveruser=${default_users[$((svruser-1))]}
    elif [[ ${#svruser} > "1" ]]; then
        serveruser=$svruser
    elif [[ $sp == "" ]]; then
        serveruser=$default_user
    else
        _start
    fi    
    default_user=$serveruser
    
    echo ""
    echo " - Password for $default_user to gain access to that server"
    read -s userpw     
    echo ""
    echo " - Root password for that server"
    read -s rootpw
    
    echo ""
    echo " *** Is this information correct? (Y/n) *** "
    printf "Server = $serveruser:"
    for (( i = 0 ; $i < ${#userpw} ; i += 1 ))
    do
        printf "*"
    done
    printf "@$server"
    read answer
    if [ "$answer" != "n" ]
    then
        user_home=$(bash -c "cd ~$(printf %q $serveruser) && pwd")

        if [ -f "$user_home/.ssh/id_rsa" ]; then
            echo " - Use $user_home/.ssh/id_rsa? (Y/n)"
            read id_rsa
            if [ "$answer" != "n" ]; then
                KEY="$user_home/.ssh/id_rsa"
            else
                echo " ** Enter Key to use"
                read KEY
            fi
        else 
            echo " - Generate rsa key to send to $server? (Y/n)"
            read genkey
            if [[ "$genkey" != "n" ]]; then
                su - $serveruser -c ssh-keygen
                KEY="$user_home/.ssh/id_rsa"
                echo "Enter Key to use. i.e. ~$serveruser/.ssh/my_rsa_key"
                read KEY
            fi
        fi
        printf "\n\nRemove key from \"known_hosts\" before attempting to connect?\n 
        The reason for this, is if the address has changed, the remote server might assume a DNS spoofing attack.\n
        Remove the key first? (Y/n)\n"
        read rk
        if [[ "$rk" == "y" ]] || [[ "$rk" == "Y" ]] || [[ "$rk" == "" ]]; then
        ip=$(grep '\s'$server'' /etc/hosts | awk '{print $1}')
        su $serveruser -c "ssh-keygen -f \"$user_home/.ssh/known_hosts\" -R \"$ip\""
        su $serveruser -c "ssh-keygen -f \"$user_home/.ssh/known_hosts\" -R \"$server\""
        fi
        
        printf "\n\nAttempt to add KEY to $server? (Y/n)\n"
        read a
        if [[ "$a" == "y" ]] || [[ "$a" == "Y" ]] || [[ "$a" == "" ]]; then
        echo "Attempting test connection"
        su $serveruser -c "sshpass -p $userpw ssh-copy-id -o StrictHostKeyChecking=no -o ConnectTimeout=5 -i $KEY $serveruser@$server -p $serverport"        
        fi
        serv="$server,$serveruser,$userpw,$rootpw,$KEY,$serverport"
        servers[$server]=$serv
        echo ""
        echo "Server added"
        
    else
        echo "Start over? (Y/n)"
        read stov
        if [[ $stov != "n" ]]; then
        Select_Server
        else
        break
        fi
    fi
}


Show_Servers()
{
    i=1
    echo ""
    echo " ===================================="
    echo ""
    echo "${blue}  ** CURRENT SELECTED SERVERS **  ${reset}"
    echo ""
    for key in "${!servers[@]}"
    do
        IFS=',' read -r -a s <<< "${servers[$key]}"
#         echo $((i++)) " : " ${s[0]}
    echo $((i++)) " : " $key
    done
    echo ""
    echo " ===================================="    
    echo ""
    _start
}



Remove_Server()
{
    i=1
    echo " ===================================="
    echo ""
    echo "Choose the server you want to remove. r to return to menu"
    echo ""
    for key in "${!servers[@]}"
    do
    
#       serv="$server[0],$serveruser[1],$userpw[2],$rootpw[3],$KEY[4],$serverport[5]"
        IFS=',' read -r -a s <<< "${servers[$key]}"
        echo $((i++)) "-" ${s[0]}
        k+=($key)
    done
    echo ""
    echo " ===================================="
    echo ""
    read svr
    if [[ $svr =~ ^[-+]?[0-9]+$ ]]
    then
        unset -v servers[${k[$((svr-1))]}]
        _start
    else
        _start
    fi      
    
}

Send_Commands()
{
    IFS=',' read -r -a c <<< "${servers[$1]}"
    cmd=${2/\"/\"}
    su ${c[1]} -c "ssh -tt -o ConnectTimeout=5 ${c[0]} 'echo "${c[2]}" | sudo -Sv && $cmd'"
}

Send_Command()
{
    printf "If you are sending commands to a UNIX/BSD machine, ensure the remote machine has sudo installed/enabled\n and the user you're connecting with is a sudoer\n\n"
    i=1
    echo " ===================================="
    echo ""
    echo "0 - ALL"
    for key in "${!servers[@]}"
    do
    
#       serv="$server[0],$serveruser[1],$userpw[2],$rootpw[3],$KEY[4],$serverport[5]"
        IFS=',' read -r -a s <<< "${servers[$key]}"
        echo $((i++)) "-" ${s[0]}
        k+=($key)
    done
    echo ""
    echo " ===================================="
    echo ""

    
    read svr
    if [[ $svr =~ ^[-+]?[0-9]+$ ]]
    then
        echo "Enter Command to send"        
        read commandtosend
        if [[ "$svr" == "0" ]]; then
            echo "Do all"
            for key in "${!servers[@]}"
            do
                Send_Commands "$key" "$commandtosend"
            done            
        else
        Send_Commands "${k[$((svr-1))]}" "$commandtosend"
        fi
        _start
    elif [[ $svr == *","* ]]; then
        IFS=',' read -r -a sv <<< "$svr"    
        for (( server_c = 0 ; $server_c < ${#sv[@]} ; server_c++ ))
        {
            Send_Commands "${k[$((sv[$server_c]-1))]}" "$commandtosend"
        }         
    else
        _start
    fi       
    
    
}


if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root" 
    if command -v sudo &> /dev/null
    then
         exec sudo "$0" "$@"
    else
        su
    fi
fi

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root" 
    exit
fi




Save_config()
{
    if [[ "${#servers[@]}" == "0" ]]; then
        echo -e "\n\t${red} !!! You don't have any host machines set to save !!!${reset}" 
        _start
    fi
    echo "${red}"
    echo "!!!!!!!!!!! WARNING !!!!!!!!!!!"
    printf "\nThis will save the passwords with the servers to .onshuremoteserver/config\n\n permissions root:root:rw----\n\n"
    echo ${reset}
    echo "Do you wish to proceed? (Y/n)"
    read answer
    if [ "$answer" == "n" ] || [ "$answer" == "N" ]
    then
        _start
    fi
    if [ ! -d .onshuremoteserver ]
    then
        mkdir .onshuremoteserver
        touch .onshuremoteserver/config
        chmod 600 .onshuremoteserver/config
    else
        dt=$(date +"%F-%H-%M-%S")
        if [ -f .onshuremoteserver/config ]; then
        mv .onshuremoteserver/config .onshuremoteserver/config-$dt
        touch .onshuremoteserver/config
        echo -e "A backup of the last config file has been saved to .onshuremoteserver/config-$dt\n"
        else
            touch .onshuremoteserver/config
        fi
    fi
    for key in "${!servers[@]}"
    do
        echo "${servers[$key]}" >> .onshuremoteserver/config
    done  
    echo "File saved as .onshuremoteserver/config"
    _start
}

Load_config()
{
    file=".onshuremoteserver/config"
    while IFS= read line
    do
        IFS=',' read -r -a s <<< "${line}"
        serv="${s[0]},${s[1]},${s[2]},${s[3]},${s[4]},${s[5]}"
        servers["$s"]=$serv
    done <"$file"
    _start
}

Upload_File()
{
    echo "Sending file to $1"
    IFS=',' read -r -a c <<< "${servers[$1]}"
    cmd=${2/\"/\"}
    su ${c[1]} -c "scp -P ${c[5]} $2 ${c[0]}:$3"
}

Upload_Files()
{
    printf "Upload a file to the server/s\n\nChoose the server/s to send the file. You can separate the servers with a ,\n\nExample: 3,4,5 or 0 for ALL Servers\n"
    i=1
    echo " ===================================="
    echo ""
    echo "0 - ALL"
    for key in "${!servers[@]}"
    do
    
#       serv="$server[0],$serveruser[1],$userpw[2],$rootpw[3],$KEY[4],$serverport[5]"
        IFS=',' read -r -a s <<< "${servers[$key]}"
        echo $((i++)) "-" ${s[0]}
        k+=($key)
    done
    echo ""
    echo " ===================================="
    echo ""

    
    read svr
    if [[ $svr =~ ^[-+]?[0-9]+$ ]]
    then
        echo "Enter path of file to send"        
        read filetosend
        echo -e "Enter path of the file to be saved on the remote host/s. \nIf no path specified, the file name will be sufficient and saved in the users directory"        
        read filetosend_remote
        if [[ "$svr" == "0" ]]; then
            echo "Sending to all"
            for key in "${!servers[@]}"
            do
                Upload_File "$key" "$filetosend"
            done            
        else
        Upload_File "${k[$((svr-1))]}" "$filetosend"
        fi
        _start
    elif [[ $svr == *","* ]]; then
        IFS=',' read -r -a sv <<< "$svr"    
        for (( server_c = 0 ; $server_c < ${#sv[@]} ; server_c++ ))
        {
            Upload_File "${k[$((sv[$server_c]-1))]}" "$filetosend" "$filetosend_remote"
        }         
    else
        _start
    fi   
}


Send_Script_to_Server()
{
    echo "Sending script to $1"
    IFS=',' read -r -a c <<< "${servers[$1]}"
    cmd=${2/\"/\"}
    su ${c[1]} -c "ssh -o ConnectTimeout=5 ${c[0]} 'echo \"${c[2]}\" | sudo -Sv && bash -s' < $2"
}
Send_Script()
{
    printf "Run a script on the server/s\n\n"
    i=1
    echo " ===================================="
    echo ""
    echo "0 - ALL"
    for key in "${!servers[@]}"
    do
    
#       serv="$server[0],$serveruser[1],$userpw[2],$rootpw[3],$KEY[4],$serverport[5]"
        IFS=',' read -r -a s <<< "${servers[$key]}"
        echo $((i++)) "-" ${s[0]}
        k+=($key)
    done
    echo ""
    echo " ===================================="
    echo ""

    
    read svr
    if [[ $svr =~ ^[-+]?[0-9]+$ ]]
    then
        echo "Enter path of script to run"        
        read scripttosend
        if [[ "$svr" == "0" ]]; then
            echo "Sending to all"
            for key in "${!servers[@]}"
            do
                Send_Script_to_Server "$key" "$scripttosend"
            done            
        else
        Send_Script_to_Server "${k[$((svr-1))]}" "$scripttosend"
        fi
        _start
    elif [[ $svr == *","* ]]; then
        IFS=',' read -r -a sv <<< "$svr"    
        for (( server_c = 0 ; $server_c < ${#sv[@]} ; server_c++ ))
        {
            Send_Script_to_Server "${k[$((sv[$server_c]-1))]}" "$scripttosend"
        }         
    else
        _start
    fi           
}


_start()
{
    printf "\n\n+++++++++++++++++++++++++++++++++++++++++\n\nChoose from the menu which you want to deploy\n\n"
    cat << EOF
    1 - Add servers
    2 - Remove server
    3 - Show servers
    4 - Send commands
    5 - Load configuration
    6 - Save configuration
    7 - Send Script    
    8 - Set/Reset Keys to remote host
    9 - Upload File/s to server/s
    10 - Quit
EOF

    read startscript
printf "\n\n+++++++++++++++++++++++++++++++++++++++++\n\n"
    case $startscript in
        1)
            Select_Server
            ;;
        2)
            Remove_Server
            ;;
        3)
            Show_Servers
            ;;            
        4)
            Send_Command
            ;;
        5)
            Load_config
            ;;
        6)
            Save_config
            ;;
        7)
            Send_Script
            ;;            
        8)
            Set_Keys_SRV
            ;;    
        9)
            Upload_Files
            ;;                
        "")
            _start
            ;;
        *)
                echo "Do you want to delete all the saved config files and known hosts from the computer? (y/N)"
                read answer
                if [ "$answer" == "y" ] || [ "$answer" == "Y" ]
                then
                    rm .onshuremoteserver/*
                    for key in "${!servers[@]}"
                    do
                    
                #       serv="$server[0],$serveruser[1],$userpw[2],$rootpw[3],$KEY[4],$serverport[5]"
                        IFS=',' read -r -a s <<< "${servers[$key]}"
                        echo $((i++)) "-" ${s[0]}
                        k+=($key)
                        user_home=$(bash -c "cd ~$(printf %q $s[1]) && pwd")
                        su $s[1] -c "ssh-keygen -f \"$user_home/.ssh/known_hosts\" -R \"$s[0]\""
                    done
                fi            
            exit
            ;;
    esac
}
_start
