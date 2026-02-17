# 2025-11-23 17:26:14 by RouterOS 7.20.4
# system id = D4cAz3p6F8G
#
/interface bridge
add name=bridge-vlans vlan-filtering=yes
add name=bridge1
/interface ethernet
set [ find default-name=ether1 ] comment="Internet Access" \
    disable-running-check=no name=WAN
set [ find default-name=ether2 ] disable-running-check=no
set [ find default-name=ether3 ] disable-running-check=no
/interface vlan
add comment=SERVER interface=bridge1 name=vlan10 vlan-id=10
add comment=BACKUP interface=bridge1 name=vlan20 vlan-id=20
add comment=ADMIN interface=bridge1 name=vlan30 vlan-id=30
add comment=INVITE interface=bridge1 name=vlan40 vlan-id=40
add comment=WIFI interface=bridge1 name=vlan50 vlan-id=50
add comment=VMS interface=bridge1 name=vlan60 vlan-id=60
/interface bridge port
add bridge=bridge-vlans interface=ether2
/interface bridge vlan
add bridge=bridge-vlans tagged=bridge-vlans,ether2 vlan-ids=10
add bridge=bridge-vlans tagged=bridge-vlans,ether2 vlan-ids=20
add bridge=bridge-vlans tagged=bridge-vlans,ether2 vlan-ids=30
add bridge=bridge-vlans tagged=bridge-vlans,ether2 vlan-ids=40
add bridge=bridge-vlans tagged=bridge-vlans,ether2 vlan-ids=50
add bridge=bridge-vlans tagged=bridge-vlans,ether2 vlan-ids=60
/ip address
add address=192.168.10.1/24 comment=SERVER interface=vlan10 network=\
    192.168.10.0
add address=192.168.20.1/24 comment=BACKUP interface=vlan20 network=\
    192.168.20.0
add address=192.168.30.1/24 comment=ADMIN interface=vlan30 network=\
    192.168.30.0
add address=192.168.40.1/24 comment=INVITE interface=vlan40 network=\
    192.168.40.0
add address=192.168.50.1/24 comment=WIFI interface=vlan50 network=\
    192.168.50.0
add address=192.168.60.1/24 comment=VMS interface=vlan60 network=192.168.60.0
/ip dhcp-client
add interface=WAN
add interface=ether3
/ip dhcp-relay
add dhcp-server=192.168.10.2 interface=vlan10 name=relay-vlan10
add dhcp-server=192.168.10.2 interface=vlan20 name=relay-vlan20
add dhcp-server=192.168.10.2 interface=vlan30 name=relay-vlan30
add dhcp-server=192.168.10.2 interface=vlan40 name=relay-vlan40
add dhcp-server=192.168.10.2 interface=vlan50 name=relay-vlan50
add dhcp-server=192.168.10.2 interface=vlan60 name=relay-vlan60
/ip dns
set allow-remote-requests=yes servers=192.168.10.2
/ip firewall filter
add action=accept chain=forward dst-port=53 protocol=udp
add action=accept chain=forward dst-port=53 protocol=tcp
/ip firewall nat
add action=masquerade chain=srcnat comment="Internet VLAN 30" out-interface=\
    WAN src-address=192.168.30.0/24
