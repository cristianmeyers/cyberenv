# 2025-11-23 17:33:46 by RouterOS 7.20.4
# system id = lQ6BOUMhGuA
#
/interface bridge
add name=bridge-vlans vlan-filtering=yes
/interface ethernet
set [ find default-name=ether1 ] disable-running-check=no name=Trunk
set [ find default-name=ether2 ] disable-running-check=no
set [ find default-name=ether3 ] disable-running-check=no
/interface vlan
add comment=SERVER interface=bridge-vlans name=vlan10 vlan-id=10
add comment=BACKUP interface=bridge-vlans name=vlan20 vlan-id=20
add comment=ADMIN interface=bridge-vlans name=vlan30 vlan-id=30
add comment=INVITE interface=bridge-vlans name=vlan40 vlan-id=40
add comment=WIFI interface=bridge-vlans name=vlan50 vlan-id=50
add comment=VMs interface=bridge-vlans name=vlan60 vlan-id=60
/ip dhcp-client
add interface=Trunk
add interface=ether3
