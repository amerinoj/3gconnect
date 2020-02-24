#!/bin/bash +x
set -e

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
apt-get --yes --force-yes install git wvdial
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
  git clone https://github.com/amerinoj/3gconnection.git
  cd 3gconnect && git checkout ${1:master}
fi
echo "done."  

# Prepare default config
mv -n /etc/wvdial.conf /etc/wvdial.conf.orig
ln -s /opt/3gconnect/wvdial.conf /etc/wvdial.conf


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

                        listusb=$(mmcli -L )
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
                        
                        
                        id_dongle=$( echo $answer  | cut -d"[" -f1 | rev | cut -d"/" -f1)
                        tty=$(mmcli -m$id_dongle | grep -oh "\w*tty\w*" *)
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
                          /opt/3gconnection/wvdial.conf ; fi 

                        if [[ $apn != "" ]] ; then  \
                         sed -i '/Init4 =/c\Init4 = AT+CGDCONT=1,"IP","'$apn'","",0,0' \
                          /opt/3gconnection/wvdial.conf ; fi

                        if [[ $user != "" ]] ; then  \
                         sed -i '/Username =/c\Username = '$user'' \
                          /opt/3gconnection/wvdial.conf  ; fi

                        if [[ $pass != "" ]] ; then  \
                         sed -i '/Password =/c\Password = '$pass'' \
                          /opt/3gconnection/wvdial.conf  ; fi

                        if [[ $phone != "" ]] ; then  \
                         sed -i '/Phone =/c\Phone = '$phone'' \
                          /opt/3gconnection/wvdial.conf ; fi

                        if [[ $baud != "" ]] ; then  \
                         sed -i '/Baud =/c\Baud = '$baud'' \
                          /opt/3gconnection/wvdial.conf ; fi
  
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
  ln /opt/3gconnection/3gconnect.service /etc/systemd/system/3gconnect.service
  systemctl daemon-reload
  systemctl enable 3gconnect.service 
  systemctl start 3gconnect.service 
  systemctl status 3gconnect.service   --full --no-pager
echo "done."

# Finished
echo
echo "3gconnect has been installed."

