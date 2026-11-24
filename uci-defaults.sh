#!/bin/sh
#
# SPDX-License-Identifier: BSD-2-Clause
#
# Copyright (c) 2026 Hans Rosenfeld
#

# Deactivate OpenWrt IP stack & DHCP for L2 passthru
uci del network.lan 2>/dev/null
uci del network.wwan 2>/dev/null
uci set network.eth=interface
uci set network.eth.device='eth0'
uci set network.eth.proto='none'
uci set network.wwan=interface
uci set network.wwan.proto='none'
uci set network.globals.packet_steering='1'
uci set dhcp.lan.ignore='1'

# Prepare Wifi Interface
# Wifi stays deactivated until at least one Wifi net is configured.
uci set wireless.radio0.disabled='0'
uci set wireless.default_radio0.device='radio0'
uci set wireless.default_radio0.network='wwan'
uci set wireless.default_radio0.mode='sta'
uci set wireless.default_radio0.disabled='1'

uci commit network
uci commit wireless
uci commit dhcp

# Create hotplug script to set up L2 passthru
mkdir -p /etc/hotplug.d/net
cat << 'EOF' > /etc/hotplug.d/net/99-tc-bridge
#!/bin/sh
if [ "$ACTION" = "add" -o "$ACTION" = "up" ]; then
    if [ "$INTERFACE" = "phy0-sta0" -o "$INTERFACE" = "eth0" ]; then
        ip addr flush dev eth0 2>/dev/null
        ip addr flush dev phy0-sta0 2>/dev/null

        ip link set eth0 up promisc on 2>/dev/null
        ip link set phy0-sta0 up promisc on 2>/dev/null

        iw dev phy0-sta0 set power_save off 2>/dev/null

        tc qdisc del dev eth0 ingress 2>/dev/null
        tc qdisc del dev phy0-sta0 ingress 2>/dev/null

        tc qdisc add dev eth0 handle ffff: ingress
        tc filter add dev eth0 parent ffff: protocol all matchall action mirred egress redirect dev phy0-sta0

        tc qdisc add dev phy0-sta0 handle ffff: ingress
        tc filter add dev phy0-sta0 parent ffff: protocol all matchall action mirred egress redirect dev eth0
    fi
fi
EOF
chmod +x /etc/hotplug.d/net/99-tc-bridge

# Set up Qemu Guest Agent
if [ -f /etc/config/qemu-ga ]; then
    uci set qemu-ga.global.enabled='1'
    uci set qemu-ga.global.method='virtio-serial'
    uci set qemu-ga.global.path='/dev/vport0p1'
    uci commit qemu-ga
fi
/etc/init.d/qemu-ga enable 2>/dev/null

exit 0
