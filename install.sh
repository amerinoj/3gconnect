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
  
                    break
                    ;;

		"End")
		    break
		    ;;
		*) echo "invalid option $REPLY";;
	    esac
	done

done


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
                    apt install iptables-persistent iptables

                    sed -i '/net.ipv4.ip_forward/c\'net.ipv4.ip_forward=1'' /etc/sysctl.conf
                    echo -e "Ip forward enable..."


                    listcard=$(ifconfig  | grep flags  | cut -d":" -f1 | grep -v lo )
                    oldIFS=$IFS
                    IFS=$'\n'
                    choices=($listcard)
                    IFS=$oldIFS
                    PS3="Select your WAN card or outgoin interface: "
                    select answer in "${choices[@]}"; do
                       for item in "${choices[@]}"; do
                          if [[ $item == $answer ]]; then
                              break 2;
                          fi
                       done
                    done
                    wanif=$answer

                    PS3="Select your LAN card or internal interface: "
                    select answer in "${choices[@]}"; do
                       for item in "${choices[@]}"; do
                          if [[ $item == $answer ]]; then
                               break 2;
                          fi
                       done
                    done
                    lanif=$answer

                    echo "Configuring Loopback interface"
                    iptables -A INPUT -i lo -j ACCEPT
                    iptables -A OUTPUT -o lo -j ACCEPT

                    echo "Drop invalid packets"
                    iptables -A INPUT -m conntrack --ctstate INVALID -j DROP

                    echo "Permit stablished connections:"
                    iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
                    iptables -A OUTPUT -m conntrack --ctstate ESTABLISHED -j ACCEPT

                    echo "Bloking all incomming traffic from:"$wanif 
                    iptables -A INPUT -i $wanif -j DROP

                    echo "Permtir forward from any to "$wanif
                    iptables -A FORWARD -i any -o $wanif -j ACCEPT

                    echo "Configuring Nat"
                    iptables -t nat -A  POSTROUTING -o $wanif -j MASQUERADE

                    echo "Saving rules"
                    iptables-save > /opt/3gconnect/iptables.rules

                    if ! grep -Fxq "#ExecStartPre="  /opt/3gconnect/3gconnect.service
                    then
                      echo "Added rules in startup saved in to 3gconnect.service "
                      sed -i 's/#ExecStartPre=/ExecStartPre=' /opt/3gconnect/3gconnect.service                       
                    fi

                    break
                    ;;

                "No")
                    break
                    ;;
                *) echo "invalid option $REPLY";;
            esac
        done



# Install and start  daemon
echo
echo "Registering and starting 3g-connect with systemd..."
if  test -f /etc/systemd/system/3gconnect.service ; then
    rm /etc/systemd/system/3gconnect.service
fi

ln -sfn /opt/3gconnect/3gconnect.service /etc/systemd/system/3gconnect.service  

systemctl daemon-reload  
systemctl enable 3gconnect.service   
systemctl start 3gconnect.service   
systemctl status 3gconnect.service   --full --no-pager  
echo "done."

# Finished
echo
echo "3gconnect has been installed."
