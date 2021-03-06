#!/bin/sh

switch_ip=192.168.50.38
switch_netmask=255.0.0.0
gateway_ip=192.168.50.1
controller_ip=192.168.50.71
controller_port=6633
local_ip=127.0.0.1
local_port=6632

ofs_dir="/mnt/ofl-sw-driver"
interfaces="eth1,eth2,eth3,eth4"
ofdatapath_options="--no-slicing"
ofprotocol_options="--inactivity-probe=90"

#--datapath-id must be exactly 12 hex digits
id_num=`echo $switch_ip | awk -F '.' '{print $4}'`
if [ $id_num -lt 10 ]; then
    datapath_id=00000000000$id_num
    mac_d1=00
    mac_d2=0$id_num
elif [ $id_num -lt 100 ]; then
    datapath_id=0000000000$id_num
    mac_d1=00
    mac_d2=$id_num
elif [ $id_num -lt 200 ]; then
    datapath_id=0000000000$id_num
    mac_d1=01
    mac_d2=`echo $id_num | cut -c 2-3`
else
    datapath_id=000000000$id_num
    mac_d1=02
    mac_d2=`echo $id_num | cut -c 2-3`
fi

echo "Networking Initial, Please wait..."
# Due to driver issue, networking interfaces should be set up, then down at first.
ifconfig eth1 up
ifconfig eth2 up
ifconfig eth3 up
ifconfig eth4 up
sleep 1

ifconfig eth4 down
ifconfig eth3 down
ifconfig eth2 down
ifconfig eth1 down
ifconfig eth0 down

ifconfig eth0 hw ether 00:0a:35:$mac_d1:$mac_d2:00
ifconfig eth1 hw ether 00:0a:35:$mac_d1:$mac_d2:01
ifconfig eth2 hw ether 00:0a:35:$mac_d1:$mac_d2:02
ifconfig eth3 hw ether 00:0a:35:$mac_d1:$mac_d2:03
ifconfig eth4 hw ether 00:0a:35:$mac_d1:$mac_d2:04
sleep 1

ifconfig eth0 $switch_ip netmask $switch_netmask up
ifconfig eth1 up
ifconfig eth2 up
ifconfig eth3 up
ifconfig eth4 up
ifconfig lo up
sleep 1

ret=`route | grep "default" | awk '{print $1}'`
if [ ! $ret ]; then
    route add default gw $gateway_ip
fi

echo "Network Interfaces Initial Done"

if [ ! -d $ofs_dir ]; then
    echo "ERROR: Please copy ofs binaries to the directory \"$ofs_dir\""
    exit
fi

echo "Entering ofs directory \"$ofs_dir\"..."
cd $ofs_dir

echo "Starting configuring udatapath..."
# ./ofdatapath --datapath-id=000000000001 --interfaces=$interfaces ptcp:$local_port $ofdatapath_options 1>tmpdp.log 2>&1 &
./ofdatapath --datapath-id=000000000005 --interfaces=$interfaces ptcp:$local_port $ofdatapath_options &
sleep 3
ret=`ps | grep "ofdatapath" | awk '{print $6}'`
if [ ! $ret ]; then
    echo "ERROR: Excuting ofdatapath failed, please check..."
    exit
fi

sleep 3


echo "Starting configuring secure channel..."
./ofprotocol tcp:$local_ip:$local_port tcp:$controller_ip:$controller_port $ofprotocol_options &
sleep 3
ret=`ps | grep "ofprotocol" | awk '{print $6}'`
if [ ! $ret ]; then
    echo "ERROR: Excuting ofprotocol failed, please check..."
    exit
fi

echo "configuring software flow table: default to controller"
./dpctl tcp:$local_ip:$local_port flow-mod cmd=add,table=0,prio=3 apply:output=ctrl:2200


echo "Openflow Switch Configured Succeessfully"

