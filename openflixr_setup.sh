#!/bin/bash

TODAY=$(date)
echo "-----------------------------------------------------"
echo "Date:          ${TODAY}"
echo "-----------------------------------------------------"
THISUSER=$(whoami)
    if [ $THISUSER != 'root' ]
        then
            echo 'You must use sudo to run this script, sorry!'
           exit 1
    fi

#Variables
OPENFLIXIR_UID=$(id -u $OPENFLIXIR_USERNAME)
OPENFLIXIR_GID=$(id -u $OPENFLIXIR_USERNAME)
PUBLIC_IP=$(dig @ns1-1.akamaitech.net ANY whoami.akamai.net +short)
LOCAL_IP=$(ifconfig eth0 | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*')

OPENFLIXR_LOGFILE="/var/log/updateof.log"
OPENFLIXR_SETUP_LOGFILE="/var/log/openflixr_setup.log"
OPENFLIXR_SETUP_PATH="/home/openflixr/openflixr_setup/"
OPENFLIXR_SETUP_CONFIG_FILE="openflixr_setup.config"
OPENFLIXR_SETUP_CONFIG="${OPENFLIXR_SETUP_PATH}${OPENFLIXR_SETUP_CONFIG_FILE}"
OPENFLIXR_SETUP_FUNCTIONS_FILE="functions.sh"
OPENFLIXR_SETUP_FUNCTIONS="${OPENFLIXR_SETUP_PATH}${OPENFLIXR_SETUP_FUNCTIONS_FILE}"
OPENFLIXR_FOLDERS=(downloads movies series music comics books)

FSTAB="/etc/fstab"
FSTAB_ORIGINAL="/etc/fstab.openflixrsetup.original"
FSTAB_BACKUP="/etc/fstab.openflixrsetup.bak"
OPENFLIXIR_CIFS_CREDENTIALS_FILE="/home/${OPENFLIXIR_USERNAME}/.credentials-openflixr"

typeset -A config # init array
config=( # set default values in config array
    [STEPS_CURRENT]=1
    [CHANGE_PASS]=""
    [NETWORK]=""
    [OPENFLIXR_IP]=""
    [OPENFLIXR_SUBNET]=""
    [OPENFLIXR_GATEWAY]=""
    [OPENFLIXR_DNS]=""
    [ACCESS]=""
    [LETSENCRYPT_DOMAIN]=""
    [LETSENCRYPT_EMAIL]=""
    [MOUNT_MANAGE]=""
    [HOST_NAME]=""
    [FSTAB_BACKUP]=0
    [FSTAB_MODIFIED]=0
)

for FOLDER in ${OPENFLIXR_FOLDERS[@]}; do
    config[MOUNT_TYPE[$FOLDER]]=""
done

#Helper methods
source $OPENFLIXR_SETUP_FUNCTIONS

echo "Initializing: Checking to see if this has been run before."
if [ ! -f $OPENFLIXR_SETUP_CONFIG ]; then
    echo "First time running or the configuration file has been deleted."
    mkdir -p $OPENFLIXR_SETUP_CONFIG_PATH
    touch $OPENFLIXR_SETUP_CONFIG
else
    echo "Config file found! Resuming from where we last left off."
    echo ""
    echo ""
fi

#Get variables from config file 
load_config $OPENFLIXR_SETUP_CONFIG


#From wizard
networkconfig=${config[NETWORK]}
ip=${config[OPENFLIXR_IP]}
subnet=${config[OPENFLIXR_SUBNET]}
gateway=${config[OPENFLIXR_GATEWAY]}
dns='127.0.0.1'
password=''
if [[ ${config[ACCESS]} = 'remote' ]]; then
    letsencrypt='on'
    domainname=${config[LETSENCRYPT_DOMAIN]}
    email=${config[LETSENCRYPT_EMAIL]}
else
    letsencrypt='off'
    domainname=''
    email=''
fi

oldpassword=$(crudini --get /usr/share/nginx/html/setup/config.ini password oldpassword)
if [ "$oldpassword" == '' ]
  then
    oldpassword='openflixr'
fi

#TODO Add these later
usenetdescription=''
usenetservername=''
usenetusername=''
usenetpassword=''
usenetport=''
usenetthreads=''
usenetssl=''
newznabprovider=''
newznaburl=''
newznabapi=''
tvshowdl='sickrage' #sickrage or sonarr
nzbdl='sabnzbd' #sabnzbd or nzbget
mopidy='enabled'
hass='enabled'
ntopng='enabled'
headphonesuser=''
headphonespass=''
anidbuser=''
anidbpass=''
spotuser=''
spotpass=''
imdb=''
comicvine=''



while [[ true ]]; do

case ${config[STEPS_CURRENT]} in
    0)
        echo ""
        echo "OOPS! Moving on"
        set_config "STEPS_CURRENT" $((${config[STEPS_CURRENT]}+1))
    ;;
    1)        
        echo ""
        echo "Step ${config[STEPS_CURRENT]}: Checking to make sure OpenFLIXR is ready."
        echo "This may take about 15 minutes depending on when you ran this script..."

        LOG_LINE=""
        while [[ ! $LOG_LINE = "Set Version" ]]; do
            tail -5 $OPENFLIXR_LOGFILE > $OPENFLIXR_SETUP_PATH"/tmp.log"
            while IFS='' read -r line || [[ -n "$line" ]]; do
                LOG_LINE="$line"
                if [[ $DEBUG -eq 1 ]]; then
                    echo "DEBUG RUN: $LOG_LINE"
                fi
                if [[ $LOG_LINE = "Set Version" ]]; then
                  break
                fi
            done < $OPENFLIXR_SETUP_PATH"/tmp.log"
            sleep 5s
        done
        rm $OPENFLIXR_SETUP_PATH"/tmp.log"
        echo "OpenFLIXR is ready! Let's GO!"
        set_config "STEPS_CURRENT" $((${config[STEPS_CURRENT]}+1))
    ;;
    2)
        echo ""
        echo "Step ${config[STEPS_CURRENT]}: Timezone Settings"
        
        dpkg-reconfigure tzdata
        
        set_config "STEPS_CURRENT" $((${config[STEPS_CURRENT]}+1))
    ;;
    3)
        echo ""
        echo "Step ${config[STEPS_CURRENT]}: Set new password"
        
        done=0
        while [[ ! $done = 1 ]]; do
            pass_change=$(whiptail --yesno --title "Change Password" "Do you want to change the default password for OpenFLIXR?" 10 40 3>&1 1>&2 2>&3)
            pass_change=$?
            
            if [[ $pass_change -eq 0 ]]; then
                config[CHANGE_PASS]="Y"
                valid=0
                while [[ ! $valid = 1 ]]; do
                    pass=$(whiptail --passwordbox --title "Set new password" "Enter password" 10 30 3>&1 1>&2 2>&3)
                    check_cancel $?;
                    cpass=$(whiptail --passwordbox --title "Set new password" "Confirm password" 10 30 3>&1 1>&2 2>&3)
                    check_cancel $?;
                    
                    if [[ $pass == $cpass ]]; then
                        password=$pass
                        valid=1
                        done=1
                    else
                        whiptail --ok-button "Try Again" --msgbox "Passwords do not match =( Try again." 10 30
                    fi
                done
            else
                config[CHANGE_PASS]="N"
                done=1
            fi
            set_config "CHANGE_PASS" $CHANGE_PASS
        done
        
        if [[ $STEPS_CONTINUE -gt 0 ]]; then
            set_config "STEPS_CURRENT" $STEPS_CONTINUE
        else
            set_config "STEPS_CURRENT" $((${config[STEPS_CURRENT]}+1))
        fi
    ;;
    4)
        echo ""
        echo "Step ${config[STEPS_CURRENT]}: Network Settings."
        
        done=0
        while [[ ! $done = 1 ]]; do
            networkconfig=$(whiptail --radiolist "Choose network configuration" 10 30 2\
                           dhcp "DHCP" on \
                           static "Static IP" off 3>&1 1>&2 2>&3)
            check_cancel $?;              
            set_config "NETWORK" $networkconfig
            
            if [[ $networkconfig = 'static' ]]; then
                echo "Configuring for Static IP"
                
                valid=0
                while [[ ! $valid = 1 ]]; do
                    ip=$(whiptail --inputbox --title "Network configuration" "IP Address" 10 30 3>&1 1>&2 2>&3)
                    check_cancel $?;
                    
                    if valid_ip $ip; then
                        set_config "OPENFLIXR_IP" $ip
                        valid=1
                    else
                        whiptail --ok-button "Try Again" --msgbox "Invalid IP Address" 10 30
                    fi
                done
                
                valid=0
                while [[ ! $valid = 1 ]]; do
                    subnet=$(whiptail --inputbox --title "Network configuration" "Subnet Mask" 10 30 3>&1 1>&2 2>&3)
                    check_cancel $?;
                    
                    if valid_ip $ip; then
                        set_config "OPENFLIXR_SUBNET" $subnet
                        valid=1
                    else
                        whiptail --ok-button "Try Again" --msgbox "Invalid IP Address" 10 30
                    fi
                done
                
                valid=0
                while [[ ! $valid = 1 ]]; do
                    gateway=$(whiptail --inputbox --title "Network configuration" "Gateway" 10 30 3>&1 1>&2 2>&3)
                    check_cancel $?;
                    
                    if valid_ip $ip; then
                        set_config "OPENFLIXR_GATEWAY" $gateway
                        valid=1
                    else
                        whiptail --ok-button "Try Again" --msgbox "Invalid IP Address" 10 30
                    fi
                done
                
                done=1
            fi
            
            if [[ $networkconfig = 'dhcp' ]]; then
                echo "Configuring for DHCP"
                done=1
            fi
            
            if [[ $networkconfig = '' ]]; then
                read -p "Something went wrong... Press enter to repeat this step or press ctrl+c to exit: " TEMP
            fi
        done
        
        set_config "STEPS_CURRENT" $((${config[STEPS_CURRENT]}+1))
    ;;
    5)
        echo ""
        echo "Step ${config[STEPS_CURRENT]}: Access settings"
        
        done=0
        while [[ ! $done = 1 ]]; do
            access=$(whiptail --radiolist "How do you want to access OpenFLIXR?" 10 30 2\
                           local "Local" on \
                           remote "Remote" off 3>&1 1>&2 2>&3)
            check_cancel $?;
            set_config "ACCESS" ${access}
            
            if [[ $access = 'local' ]]; then
                echo "Local access selected. Nothing else to do."
                done=1
            fi
            
            if [[ $access = 'remote' ]]; then
                echo "Configuring for Remote access."
                
                valid=0
                while [[ ! $valid = 1 ]]; do
                    domain=$(whiptail --inputbox --ok-button "Next" --title "STEP 1/ : Domain" "Enter your domain (required to obtain certificate). If you don't have one, register one and then enter it here." 10 50 ${config[LETSENCRYPT_DOMAIN]} 3>&1 1>&2 2>&3)
                    check_cancel $?;
                    set_config "LETSENCRYPT_DOMAIN" $domain
                    
                    #TODO: Validate domain
                    valid=1
                done
                
                whiptail --ok-button "Next" --msgbox "Add/Edit the A records for ${domain} and www.${domain} to point to ${PUBLIC_IP}" 10 50
                whiptail --ok-button "Next" --msgbox "Forward port 443 (only!) on your router to your local IP (${LOCAL_IP})" 10 50
                
                valid=0
                while [[ ! $valid = 1 ]]; do
                    email=$(whiptail --inputbox --title "STEP 1/ : Domain" "Enter your e-mail address (required for lost key recovery)." 10 50 ${config[LETSENCRYPT_EMAIL]} 3>&1 1>&2 2>&3)
                    check_cancel $?;
                    set_config "LETSENCRYPT_EMAIL" $email
                    
                    #TODO: Validate email
                    valid=1
                done
                
                
                done=1
            fi
            
            if [[ $access = '' ]]; then
                read -p "Something went wrong... Press enter to repeat this step or press ctrl+c to exit: " TEMP
            fi
        done
        
        set_config "STEPS_CURRENT" $((${config[STEPS_CURRENT]}+1))
    ;;
    6)
        echo ""
        echo "Step ${STEPS_CURRENT}: Folders"
        echo "Creating mount folders"
        for FOLDER in ${OPENFLIXR_FOLDERS[@]}; do
            if [[ $DEBUG -ne 1 ]]; then
                echo "Creating mount point /mnt/${FOLDER}/"
                sudo mkdir -p /mnt/${FOLDER}/
            else
                echo "Would have created /mnt/${FOLDER}/"
            fi
        done
        
        set_config "STEPS_CURRENT" $((${config[STEPS_CURRENT]}+1))
    ;;
    7)
        echo ""
        echo "Step ${STEPS_CURRENT}: Mount network shares"
        MOUNT_MANAGE="webmin"
        echo "Visit webmin to complete the setup of your folders. http://${LOCAL_IP}/webmin/"
        sed -i "s/MOUNT_MANAGE=.*/MOUNT_MANAGE=webmin /g" $OPENFLIXR_SETUP_CONFIG
        #done=0
        #while [[ ! $done = 1 ]]; do
        #    sharetype=$(whiptail --radiolist "Choose network share type" 10 30 2\
        #                   nfs "NFS" on \
        #                   cifs "CIFS/SMB" off 3>&1 1>&2 2>&3)
        #    check_cancel $?;
        #done

        set_config "STEPS_CURRENT" $((${config[STEPS_CURRENT]}+1))
    ;;
    8)
        echo ""
        echo "Step ${config[STEPS_CURRENT]}: Nginx fix"
        if [[ $DEBUG -ne 1 ]]; then
            sed -i "s/listen 443 ssl http2;/#listen 443 ssl http2; /g" /etc/nginx/sites-enabled/reverse
            echo "Done! Let's test to make sure nginx likes it..."
            nginx -t
        else
            echo "This would have commented out a line in /etc/nginx/sites-enabled/reverse"
        fi
        echo "If the above doesn't say 'syntax ok' and 'test is successful' please edit '/etc/nginx/sites-enabled/reverse' directly to correct any problems."
        
        set_config "STEPS_CURRENT" $((${config[STEPS_CURRENT]}+1))
    ;;
    *)
        echo ""
        echo ""
        echo "COMPLETED!!"
        echo "Checking data provided..."
        
        if [[ ${config[CHANGE_PASS]} = "Y" && $password = "" ]]; then
            echo "You selected to have the password changed but no password is set. Either something went wrong or this script was resumed (passwords aren't saved)."
            echo "We will return you to the password step now."
            ${config[STEPS_CURRENT]}=3
            STEPS_CONTINUE=9
        else
            echo "Nothing else left for us to do! Let's run the rest!"
            echo ""
            echo ""
            break
        fi
    ;;
esac

#UPDATE CONFIG FOR SCRIPT RESUME
set_config "STEPS_CURRENT" ${config[STEPS_CURRENT]}

done

preinitialized="yes"

setup_paths=(
    "/usr/share/nginx/html/setup/setup.sh"
    "/home/openflixr/openflixr_setup/setup.sh"
)
setup_repo_path="https://raw.githubusercontent.com/MagicalCodeMonkey/OpenFLIXR2.SetupScript/dev/setup.sh"

exit
#Find setup.sh and run it. 
for i in ${!setup_paths[@]}; do
    path=${setup_paths[$i]}
    if [ -f "$path" ]; then
        echo "Found script in $path"
        chmod +x $path
        source $path
        break
    elif [[ $path = ${setup_paths[-1]} ]]; then
        echo "Couldn't find setup.sh. Downloading from repo"
        wget -O $path $setup_repo_path
        chown openflixr:openflixr $path
        chmod +x $path
        source $path
        break
    fi    
done
