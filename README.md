A simple USB 3G dongle connection for the Raspberry Pi 3.                        

The install script use dnsmasq and hostap to configure the hotspot
The script will no configured  routing, NAT or forwarding ip traffic 
## Installation

Quick Installation for Raspbian:

```bash
sudo -i
bash <(curl -s https://raw.githubusercontent.com/amerinoj/3gconnect/master/install.sh)     
```
                                                                                   
## Config

The basics values are asking in the install script.
If you need customizer more parameters, edit wvdial.conf and modify the default values

## End install
To enable the nat rule the file /etc/ufw/before.rules should be edit.
Add the next rule after the last comment # and before the filter* statement
The ppp0 is a example replaced with your wan network name

Example:
```
# Don't delete these required lines, otherwise there will be errors
*nat
:POSTROUTING ACCEPT [0:0]
#NAT ALL NETWORK TO WAN  
-A POSTROUTING  -o ppp0 -j MASQUERADE
COMMIT
#END NAT

*filter
```
After edit the file enable ufw
```
ufw enable
```
