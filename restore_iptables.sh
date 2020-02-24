#!/bin/bash +x
set -e
#set -x
# This script restore the iptables
iptables-restore < /opt/3gconnect/iptables.rules
