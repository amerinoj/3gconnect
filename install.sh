#!/bin/bash +x
set -e
#set -x
# This script has been tested with the "2017-11-29-raspbian-stretch-lite.img" image.
#check root privileges
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi
###############
echo "Checking if 3gconnect.service is running..."
if [ "`systemctl is-active 3gconnect.service`" == "active" ]; then
  echo  "Stop service .."
  systemctl stop 3gconnect.service
  systemctl disable 3gconnect.service
fi
#################################
echo "Installing dependencies..."
apt-get update
apt-get --yes --force-yes install git wvdial modemmanager
echo "done."

# Add 3gconnect user if not exist already

# Download 3gconnect to /opt (or update if already present)
echo
cd /opt
if [ -d 3gconnect ]; then
  echo "Updating 3gconnect..."
  cd 3gconnect && git pull && git checkout ${1:master}
else
  echo "Downloading 3gconnect..."
  git clone https://github.com/amerinoj/3gconnect.git
  cd 3gconnect && git checkout ${1:master}
fi
echo "done."  

# Prepare default config
if  test -f /etc/wvdial.conf ; then
    mv -n /etc/wvdial.conf /etc/wvdial.conf.orig
fi


if  test -f /etc/wvdial.conf ; then
    rm /etc/wvdial.conf
fi
ln -sfn /opt/3gconnect/wvdial.conf /etc/wvdial.conf


#Menu
opt=""
while [[ $opt != "End" ]]; do
	clear
        echo
	echo '####################  Menu Config options  ####################'
	PS3='Config options: '
	options=("Config 3gconnect" "End")
	select opt in "${options[@]}"
	do
	   case $opt in
		"Config 3gconnect")

                        listusb=$(mmcli -L   |   tr [] _ )
                        oldIFS=$IFS
                        IFS=$'\n'
                        choices=($listusb)
                        IFS=$oldIFS
                        PS3="Select your usb 3g dongle: "
                        select answer in "${choices[@]}"; do
                          for item in "${choices[@]}"; do
                            if [[ $item == $answer ]]; then
                               break 2;
                            fi
                          done
                        done
                        
                        id_dongle=$( echo $answer  | cut -d"_" -f1 | rev | cut -d"/" -f1)
                        tty=$(mmcli -m$id_dongle | grep -oh "\w*tty\w*"* | head -n 1)
                        echo
                        echo -e "Using : " $tty

                        echo "PRESS INTRO TO USE DEFAULT VALUES"
                        read -p "Apn : " apn
                        read -p "Username : " user
                        read -p "Password : " pass
                        read -p "Phone Number : " phone
                        read -p "Baud rate : " baud
                        
                        if [[ $tty != "" ]] ; then  \
                         sed -i '/Modem =/c\Modem = /dev/'$tty'' \
                          /opt/3gconnect/wvdial.conf ; fi 

                        if [[ $apn != "" ]] ; then  \
                         sed -i '/Init4 =/c\Init4 = AT+CGDCONT=1,"IP","'$apn'","",0,0' \
                          /opt/3gconnect/wvdial.conf ; fi

                        if [[ $user != "" ]] ; then  \
                         sed -i '/Username =/c\Username = '$user'' \
                          /opt/3gconnect/wvdial.conf  ; fi

                        if [[ $pass != "" ]] ; then  \
                         sed -i '/Password =/c\Password = '$pass'' \
                          /opt/3gconnect/wvdial.conf  ; fi

                        if [[ $phone != "" ]] ; then  \
                         sed -i '/Phone =/c\Phone = '$phone'' \
                          /opt/3gconnect/wvdial.conf ; fi

                        if [[ $baud != "" ]] ; then  \
                         sed -i '/Baud =/c\Baud = '$baud'' \
                          /opt/3gconnect/wvdial.conf ; fi

                         if ! [[ $(cat /etc/ppp/peers/wvdial) =~ "defaultroute" ]] ; then
                           
                           echo "defaultroute" >> /etc/ppp/peers/wvdial
                           echo "replacedefaultroute" >> /etc/ppp/peers/wvdial
                         fi

                      
                         

                    break
                    ;;

		"End")
		    break
		    ;;
		*) echo "invalid option $REPLY";;
	    esac
	done

done


# Install and start  daemon
echo
echo "Registering and starting 3g-connect with systemd..."

ln -sfn /opt/3gconnect/3gconnect.service /etc/systemd/system/3gconnect.service  

systemctl daemon-reload  
systemctl enable 3gconnect.service   
systemctl start 3gconnect.service   
systemctl status 3gconnect.service   --full --no-pager  
echo "done."

# Finished 3gconnect install
echo
echo "3gconnect has been installed."




opt=""

clear
echo
echo '####################  Routing Config options  ####################'
echo 'do you want configure routing parameters NAT and firewall rules?'
PS3='Config options: '
options=("Yes" "No")
select opt in "${options[@]}"
do
    case $opt in
           "Yes")
                 echo "Installing iptables-persistent"
                 apt --yes install ufw

                  lanif=""
                  wanif=""
                  Res=""
                  while [[ $Res != "End" ]]; do
                      echo
                      echo '####################  Select interface  ####################'
                      opt_iface="Select Wan interface,Select Lan interfaces,End"
                      oldIFS=$IFS
                      IFS=$','
                      choices=($opt_iface)
                      IFS=$oldIFS
                      PS3="Select a  option: "
                      select answer in "${choices[@]}"; do
                         for item in "${choices[@]}"; do
                            if [[ $item == $answer ]]; then
                                break 2;
                            fi
                         done
                      done
                      Res=$answer

                      if [[ $answer == "Select Wan interface" ]]; then

                        wanif=""                        
                        while [[ $answer != "End" ]]; do 
                         listcard=$(ifconfig  | grep flags  | cut -d":" -f1 | grep -v lo )
                         oldIFS=$IFS
                         IFS=$'\n'
                         choices=($listcard)
                         choices+=('Refresh interfaces')
                         choices+=('End')    
                         IFS=$oldIFS  
                         PS3="Select the wan interface ppp[x]: "
                         select answer in "${choices[@]}"; do
                           for item in "${choices[@]}"; do               
                              if [[ $item == $answer ]]; then
                                 break 2;
                              fi
                           done
                         done 
                         if [[ $answer != "End" &&  $answer != "Refresh interfaces" ]]; then
                              wanif=$answer

                         fi
                         echo "Selected interface:"$wanif
                        done
                     fi


                    if [[ $answer == "Select Lan interfaces" ]]; then

                       lanif=""
                        while [[ $answer != "End" ]]; do 
                          listcard=$(ifconfig  | grep flags  | cut -d":" -f1 | grep -v lo )
                          oldIFS=$IFS
                          IFS=$'\n'  
                          choices=($listcard)
                          choices+=('Refresh interfaces')
                          choices+=('End')                  
                          IFS=$oldIFS  
                          PS3="Select the LAN interfaces: "
                          select answer in "${choices[@]}"; do
                             for item in "${choices[@]}"; do               
                                if [[ $item == $answer ]]; then
                                   break 2;
                                fi
                             done
                          done 
                          if [[ $answer != "End" &&  $answer != "Refresh interfaces" ]]; then
                             lanif+=$answer","
                          fi
                          echo "Selected interfaces:" $lanif
                        done
                     fi   

                 done
		    echo "Stop ufw"
                    ufw disable
		    
		    echo "Kernel forward Enable"
		    sed -i '/net.ipv4.ip_forward/c\'net.ipv4.ip_forward=1'' /etc/sysctl.conf
                    echo -e "Ip forward enable..."
		    
		    
		    chown root:pi /lib
		    sed -i '/IPV6=yes/c\IPV6=no' /etc/default/ufw
		    
		    echo "DEFAULT : Deny incomming , Allow outgoing , Allow forward"
                    ufw default deny incoming
                    ufw default allow outgoing
                    ufw default allow FORWARD

		    echo "Allow DNS"
                    ufw allow dns
		    
                    echo "Permit incomming from $lanif to any "
                    oldIFS=$IFS
                    IFS=$','     
                    int_iface=($lanif)
                    IFS=$oldIFS   
                    for item in "${int_iface[@]}"; do
                         ufw allow in on $item to any
                    done

                     # Rules installed
                     echo
                     echo "FW Rules has been installed."

                     nat="# Put after the last comment
                     *nat
                     :POSTROUTING ACCEPT [0:0]
                     #NAT ALL NETWORK TO WAN  
                     -A POSTROUTING  -o $wanif -j MASQUERADE
                     COMMIT
                     #END NAT
                     # End before '*filter'"
                     echo "--------------------------------------------"
                     echo "Edit the file  /etc/ufw/before.rules and add"
		     echo "############################################"
                     echo "$nat"
                     echo "############################################"


                    break
                    ;;

                "No")

                    break
                    ;;
                *) echo "invalid option $REPLY";;
            esac
        done


# Finished
echo
echo "Finished"

