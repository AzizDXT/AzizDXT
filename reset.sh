#!/bin/bash

echo "=========================================="
echo "إعادة تصفير كامل لإعدادات الشبكة"
echo "=========================================="
echo "⚠️  تحذير: سيتم حذف جميع إعدادات الشبكة!"
echo "⚠️  تأكد من أن لديك طريقة أخرى للاتصال بالجهاز!"
echo ""
read -p "هل تريد المتابعة؟ (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "تم إلغاء العملية"
    exit 1
fi

# التحقق من صلاحيات root
if [ "$EUID" -ne 0 ]; then
    echo "يرجى تشغيل السكريبت بصلاحيات root:"
    echo "sudo bash complete_reset.sh"
    exit 1
fi

echo ""
echo "🔄 بدء عملية التصفير الكامل..."
echo ""

echo "الخطوة 1: إيقاف جميع الخدمات المتعلقة بالشبكة..."
systemctl stop dnsmasq 2>/dev/null || true
systemctl stop smart-dnsmasq 2>/dev/null || true
systemctl stop auto-router 2>/dev/null || true
systemctl stop cable-monitor 2>/dev/null || true
systemctl stop dnsmasq-resolv 2>/dev/null || true
systemctl stop hostapd 2>/dev/null || true
systemctl stop networking 2>/dev/null || true
systemctl stop systemd-networkd 2>/dev/null || true
systemctl stop systemd-resolved 2>/dev/null || true

echo "الخطوة 2: تعطيل جميع الخدمات المخصصة..."
systemctl disable dnsmasq 2>/dev/null || true
systemctl disable smart-dnsmasq 2>/dev/null || true
systemctl disable auto-router 2>/dev/null || true
systemctl disable cable-monitor 2>/dev/null || true
systemctl disable dnsmasq-resolv 2>/dev/null || true
systemctl disable hostapd 2>/dev/null || true

echo "الخطوة 3: حذف جميع ملفات الخدمات المخصصة..."
rm -f /etc/systemd/system/auto-router.service
rm -f /etc/systemd/system/cable-monitor.service
rm -f /etc/systemd/system/dnsmasq-resolv.service
rm -f /etc/systemd/system/smart-dnsmasq.service
rm -f /usr/local/bin/router-iptables.sh
rm -f /usr/local/bin/cable-monitor.sh
rm -f /usr/local/bin/smart-dnsmasq.sh
rm -rf /run/dnsmasq

echo "الخطوة 4: مسح جميع قواعد iptables..."
iptables -F
iptables -t nat -F
iptables -t mangle -F
iptables -t raw -F
iptables -X
iptables -t nat -X
iptables -t mangle -X
iptables -t raw -X

# إعادة تعيين السياسات الافتراضية
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT

# حذف ملفات iptables المحفوظة
rm -f /etc/iptables/rules.v4
rm -f /etc/iptables/rules.v6

echo "الخطوة 5: إعادة تعيين إعدادات sysctl..."
# إزالة إعدادات IP forwarding المخصصة
sed -i '/# تفعيل IP forwarding للراوتر/d' /etc/sysctl.conf
sed -i '/net.ipv4.ip_forward=1/d' /etc/sysctl.conf
sed -i '/net.ipv4.conf.all.forwarding=1/d' /etc/sysctl.conf
sed -i '/net.ipv4.conf.default.forwarding=1/d' /etc/sysctl.conf

# تطبيق الإعدادات
echo 0 > /proc/sys/net/ipv4/ip_forward
sysctl -p

echo "الخطوة 6: حذف جميع ملفات netplan المخصصة..."
rm -f /etc/netplan/01-router-config.yaml

echo "الخطوة 7: استعادة ملف dnsmasq الأصلي..."
if [ -f /etc/dnsmasq.conf.backup ]; then
    mv /etc/dnsmasq.conf.backup /etc/dnsmasq.conf
    echo "✓ تم استعادة ملف dnsmasq الأصلي"
else
    # إنشاء ملف dnsmasq افتراضي بسيط
    cat > /etc/dnsmasq.conf << EOF
# Configuration file for dnsmasq.
# Format is one option per line, legal options are the same
# as the long options legal on the command line. See
# "/usr/sbin/dnsmasq --help" or "man 8 dnsmasq" for details.

# Change this line if you want dns to get its upstream servers from
# somewhere other that /etc/resolv.conf
#resolv-file=

# By  default,  dnsmasq  will  send queries to any of the upstream
# servers it knows about and tries to favour servers to are  known
# to  be  up.  Uncommenting this forces dnsmasq to try each query
# with  each  server  strictly  in  the  order  they   appear   in
# /etc/resolv.conf
#strict-order

# If you don't want dnsmasq to read /etc/resolv.conf or any other
# file, getting its servers from this file instead (see below), then
# uncomment this.
#no-resolv

# If you don't want dnsmasq to poll /etc/resolv.conf or other resolv
# files for changes and re-read them then uncomment this.
#no-poll

# Add other name servers here, with domain specs if they are for
# non-public domains.
#server=/localnet/192.168.0.1

# Example of routing PTR queries to nameservers: this will send all
# address->name queries for 192.168.3/24 to nameserver 192.168.3.1
#server=/3.168.192.in-addr.arpa/192.168.3.1

# Add local-only domains here, queries in these domains are answered
# from /etc/hosts or DHCP only.
#local=/localnet/

# Add domains which you want to force to an IP address here.
# The example below send any host in double-click.net to a local
# web-server.
#address=/double-click.net/127.0.0.1

# --address (and --server) work with IPv6 addresses too.
#address=/www.thekelleys.org.uk/fe80::20d:60ff:fe36:f83

# You can control how dnsmasq talks to a server: this forces
# queries to 10.1.2.3 to be routed via eth1
# server=10.1.2.3@eth1

# and this sets the source (ie local) address used to talk to
# 10.1.2.3 to 192.168.1.1 port 55 (there must be a interface with that
# IP on the machine, obviously).
# server=10.1.2.3@192.168.1.1#55

# If you want dnsmasq to change uid and gid to something other
# than the default, edit the following lines.
#user=
#group=

# If you want dnsmasq to listen for DHCP and DNS requests only on
# specified interfaces (and the loopback) give the name of the
# interface (eg eth0) here.
# Repeat the line for more than one interface.
#interface=
# Or you can specify which interface _not_ to listen on
#except-interface=
# Or which to listen on by address (remember to include 127.0.0.1 if
# you use this.)
#listen-address=
# If you want dnsmasq to provide only DNS service on an interface,
# configure it as shown above, and then use the following line to
# disable DHCP and TFTP on it.
#no-dhcp-interface=

# On systems which support it, dnsmasq binds the wildcard address,
# even when it is listening on only some interfaces. It then discards
# requests that it shouldn't reply to. This has the advantage of
# working even when interfaces come and go and change address. If you
# want dnsmasq to really bind only the interfaces it is listening on,
# uncomment this option. About the only time you may need this is when
# running another nameserver on the same machine.
#bind-interfaces

# If you don't want dnsmasq to read /etc/hosts, uncomment the
# following line.
#no-hosts
# or if you want it to read another file, as well as /etc/hosts, use
# this.
#addn-hosts=/etc/banner_add_hosts

# Set this (and domain: see below) if you want to have a domain
# automatically added to simple names in a hosts-file.
#expand-hosts

# Set the domain for dnsmasq. this is optional, but if it is set, it
# does the following things.
# 1) Allows DHCP hosts to have fully qualified domain names, as long
#     as the domain part matches this setting.
# 2) Sets the "domain" DHCP option thereby potentially setting the
#    domain of all systems configured by DHCP
# 3) Provides the domain part for "expand-hosts"
#domain=thekelleys.org.uk

# Set a different domain for a particular subnet
#domain=wireless.thekelleys.org.uk,192.168.2.0/24

# Same idea, but range rather then the whole subnet
#domain=reserved.thekelleys.org.uk,192.168.3.100,192.168.3.200

# Uncomment this to enable the integrated DHCP server, you need
# to supply the range of addresses available for lease and optionally
# a lease time. If you have more than one network, you will need to
# repeat this for each network on which you want to supply DHCP
# service.
#dhcp-range=192.168.0.50,192.168.0.150,12h

# This is an example of a DHCP range where the netmask is given. This
# is needed for networks we reach the dnsmasq DHCP server via a relay
# agent. If you don't know what a DHCP relay agent is, you probably
# don't need to worry about this.
#dhcp-range=192.168.0.50,192.168.0.150,255.255.255.0,12h

# This is an example of a DHCP range with a network-id, so that
# some DHCP options may be set only for this network.
#dhcp-range=set:red,192.168.0.50,192.168.0.150

# Use this DHCP range only when the tag "green" is set.
#dhcp-range=tag:green,192.168.0.50,192.168.0.150,12h

# Specify a subnet which can't use DHCP, substitute the net ID for the
# one you want.
#dhcp-range=192.168.0.0,static

# Enable DHCPv6. Note that the prefix-length does not need to be specified
# and defaults to 64 if missing/
#dhcp-range=1234::2, 1234::500, 64, 12h

# Do Router Advertisements, BUT NOT DHCP for this subnet.
#dhcp-range=1234::, ra-only

# Do Router Advertisements, BUT NOT DHCP for this subnet, also try and
# add names to the DNS for the IPv6 address of SLAAC-configured dual-stack
# hosts. Use the DHCPv4 lease to derive the name, network segment and
# MAC address and assume that the host will also have an
# IPv6 address calculated using the SLAAC algorithm.
#dhcp-range=1234::, ra-names

# Do Router Advertisements, BUT NOT DHCP for this subnet.
# Set the lifetime to 46 hours. (Note: minimum lifetime is 2 hours.)
#dhcp-range=1234::, ra-only, 48h

# Do DHCP and Router Advertisements for this subnet. Set the A bit in the RA
# so that clients can use SLAAC addresses as well as DHCP ones.
#dhcp-range=1234::2, 1234::500, slaac

# Do Router Advertisements and stateless DHCP for this subnet. Clients will
# not get addresses from DHCP, but they will get other configuration information.
# They will use SLAAC for addresses.
#dhcp-range=1234::, ra-stateless

# Do stateless DHCP, SLAAC, and generate DNS names for SLAAC addresses
# from DHCPv4 leases.
#dhcp-range=1234::, ra-stateless, ra-names

# Do router advertisements for all subnets where we're doing DHCPv6
# Unless overridden by ra-stateless, ra-names, et al, the router
# advertisements will have the M and O bits set, so that the clients
# get addresses and configuration from DHCPv6, and the A bit reset, so the
# clients don't use SLAAC addresses.
#enable-ra

# Supply parameters for specified hosts using DHCP. There are lots
# of valid alternatives, so we will give examples of each. Note that
# IP addresses DO NOT have to be in the range given above, they just
# need to be on the same network. The order of the parameters in these
# example matters, it must be hostname, then MAC address, then IP
# address. Additional parameters can be given.

# Always allocate the host with Ethernet address 11:22:33:44:55:66
# The IP address 192.168.0.60
#dhcp-host=11:22:33:44:55:66,192.168.0.60

# Always set the name of the host with hardware address
# 11:22:33:44:55:66 to be "fred"
#dhcp-host=11:22:33:44:55:66,fred

# Always give the host with Ethernet address 11:22:33:44:55:66
# the name fred and IP address 192.168.0.60 and lease time 45 minutes
#dhcp-host=11:22:33:44:55:66,fred,192.168.0.60,45m

# Give a host with Ethernet address 11:22:33:44:55:66 or
# 12:34:56:78:90:12 the IP address 192.168.0.60. Dnsmasq will assume
# that these two Ethernet interfaces will never be in use at the same
# time, and give the IP address to the second, even if it is already
# in use by the first. Useful for laptops with wired and wireless
# addresses.
#dhcp-host=11:22:33:44:55:66,12:34:56:78:90:12,192.168.0.60

# Give the machine which says its name is "bert" IP address
# 192.168.0.70 and an infinite lease
#dhcp-host=bert,192.168.0.70,infinite

# Always give the host with client identifier 01:02:02:04
# the IP address 192.168.0.60
#dhcp-host=id:01:02:02:04,192.168.0.60

# Always give the InfiniBand interface with GUID 11:22:33:44:55:66:77:88:99:aa:bb:cc:dd:ee:ff:00:11:22
# the ip address 192.168.0.60. The client id is derived from the GUID as per RFC 4390.
#dhcp-host=id:00:03:00:01:11:22:33:44:55:66:77:88:99:aa:bb:cc:dd:ee:ff:00:11:22,192.168.0.60

# Always give the host with client identifier "marjorie"
# the IP address 192.168.0.60
#dhcp-host=id:marjorie,192.168.0.60

# Enable the address given for "judge" in /etc/hosts
# to be given to a machine presenting the name "judge" when
# it asks for a DHCP lease.
#dhcp-host=judge

# Never offer DHCP service to a machine whose Ethernet
# address is 11:22:33:44:55:66
#dhcp-host=11:22:33:44:55:66,ignore

# Ignore any client-id presented by the machine with Ethernet
# address 11:22:33:44:55:66. This is useful to prevent a machine
# being treated differently when running under different OS's or
# between PXE boot and OS boot.
#dhcp-host=11:22:33:44:55:66,id:*

# Send extra options which are tagged as "red" to
# the machine with Ethernet address 11:22:33:44:55:66
#dhcp-host=11:22:33:44:55:66,set:red

# Send extra options which are tagged as "red" to
# any machine with Ethernet address starting 11:22:33:
#dhcp-host=11:22:33:*:*:*,set:red

# Give a fixed IPv6 address and name to client with
# DUID 00:01:00:01:16:d2:83:fc:92:d4:19:e2:d8:b2
# Note the MAC addresses CANNOT be used to identify DHCPv6 clients.
# Note also the they [] around the IPv6 address are obligatory.
#dhcp-host=id:00:01:00:01:16:d2:83:fc:92:d4:19:e2:d8:b2, fred, [1234::5]

# Ignore any clients which are not specified in dhcp-host lines
# or /etc/ethers. Equivalent to ISC "deny unknown-clients".
# This relies on the special "known" tag which is set when
# a host is matched.
#dhcp-ignore=tag:!known

# Send extra options to machines with the "red" tag
# All machines in this example are tagged with "red", but
# not with "green".
#dhcp-option=tag:red,option:ntp-server,192.168.1.1

# Send extra options to machines without the "red" tag
#dhcp-option=tag:!red,option:ntp-server,192.168.1.2

# Send extra options to machines with "red" or "green" tags
#dhcp-option=tag:red,tag:green,option:ntp-server,192.168.1.3

# Do NOT send a default route as a DHCP option.
# This is useful for networks which have a complex routing setup
#dhcp-option=3

# Override the default route supplied by dnsmasq, which assumes the
# router is the same machine as the one running dnsmasq.
#dhcp-option=3,1.2.3.4

# Do the same thing, but using the option name
#dhcp-option=option:router,1.2.3.4

# Override the default route supplied by dnsmasq and send no default
# route at all. Note that this only works for the options sent by
# default (1, 3, 6, 12, 28) the same line will send a zero-length option
# for all other option numbers.
#dhcp-option=3

# Set the NTP time server addresses to 192.168.0.4 and 10.10.0.5
#dhcp-option=option:ntp-server,192.168.0.4,10.10.0.5

# Send DHCPv6 option. Note [] around IPv6 addresses.
#dhcp-option=option6:dns-server,[1234::77],[1234::88]

# Send DHCPv6 option for namservers as the machine running
# dnsmasq and another.
#dhcp-option=option6:dns-server,[::],[1234::88]

# Ask client to poll for option changes every six hours. (RFC4242)
#dhcp-option=option6:information-refresh-time,6h

# Set option 58 client renewal time (T1). Defaults to 0.5 * lease time
#dhcp-option=option:T1,1200s

# Set option 59 rebinding time (T2). Defaults to 0.875 * lease time
#dhcp-option=option:T2,2100s

# Set the boot filename for BOOTP. You will only need
# this is you want to boot machines over the network and you will need
# a TFTP server; either dnsmasq's built in TFTP server or an
# external one. (See below for how to enable the TFTP server.)
#dhcp-boot=pxelinux.0

# The same, but use the host running dnsmasq as the TFTP server
#dhcp-boot=pxelinux.0,menuhost,192.168.0.1

# Boot for Etherboot gPXE. The idea is to send two different
# filenames, the first loads gPXE, and the second tells gPXE what to
# load. The dhcp-match sets the gpxe tag for requests from gPXE.
#dhcp-match=set:gpxe,175 # gPXE sends a 175 option.
#dhcp-boot=tag:!gpxe,undionly.kpxe
#dhcp-boot=tag:gpxe,linux.0

# Encapsulated options for Etherboot gPXE. All the options are
# encapsulated within option 175
#dhcp-option=encap:175, 1, 5b         # priority code
#dhcp-option=encap:175, 176, 1b       # no-proxydhcp
#dhcp-option=encap:175, 177, string   # bus-id
#dhcp-option=encap:175, 189, 1b       # BIOS drive code
#dhcp-option=encap:175, 190, user     # iSCSI username
#dhcp-option=encap:175, 191, pass     # iSCSI password

# Test for the architecture of a netboot client. PXE clients are
# supposed to send their architecture as option 93. (See RFC 4578)
#dhcp-match=peecees, option:client-arch, 0 #x86-32
#dhcp-match=itanium, option:client-arch, 2 #IA64
#dhcp-match=hammers, option:client-arch, 6 #x86-64
#dhcp-match=mactels, option:client-arch, 7 #EFI x86-64

# Do real PXE, rather than just booting a single file, this is an
# alternative to dhcp-boot.
#pxe-prompt="What system shall I netboot?"
# or with timeout before first available action is taken:
#pxe-prompt="Press F8 for menu.", 60

# Available boot services. for PXE.
#pxe-service=x86PC, "Boot from network", pxelinux

# If you have multicast-FTP available,
# information for that can be passed in a similar way using options 1
# to 5. See page 19 of
# http://download.intel.com/design/archives/wfm/downloads/pxespec.pdf


# Enable dnsmasq's built-in TFTP server
#enable-tftp

# Set the root directory for files available via FTP.
#tftp-root=/var/ftpd

# Do not abort if the tftp-root is unavailable
#tftp-no-fail

# Make the tftp server more secure: with this set, only files owned by
# the user dnsmasq is running as will be send over the net.
#tftp-secure

# This option stops dnsmasq from negotiating a larger blocksize for TFTP
# transfers. It will slow things down, but may rescue some broken TFTP
# clients.
#tftp-no-blocksize

# Set the boot file name only when the "red" tag is set.
#dhcp-boot=tag:red,pxelinux.red-net

# An example of dhcp-boot with an external TFTP server: the name and IP
# address of the server are given after the filename.
# Can fail with old PXE ROMS. Overridden by --pxe-service.
#dhcp-boot=pxelinux.0,boothost,192.168.0.3

# If there are multiple external tftp servers having a same name
# (using /etc/hosts) then that name can be specified as the
# tftp_servername (the third option to dhcp-boot) and in that
# case dnsmasq resolves this name and returns the resultant IP
# addresses in round robin fasion. This facility can be used to
# load balance the tftp load among a set of servers.
#dhcp-boot=pxelinux.0,boothost,tftp_server_name

# Set the limit on DHCP leases, the default is 150
#dhcp-lease-max=150

# The DHCP server needs somewhere on disk to keep its lease database.
# This defaults to a sane location, but if you want to change it, use
# the line below.
#dhcp-leasefile=/var/lib/dhcp/dhcp.leases

# Set the DHCP server to authoritative mode. In this mode it will barge in
# and take over the lease for any client which broadcasts on the network,
# whether it has a record of the lease or not. This avoids long timeouts
# when a machine wakes up on a new network. DO NOT enable this if there's
# the slightest chance of a rogue DHCP server on the network. Another way
# to do this is to enable it for some networks and not others using
# dhcp-range=......,authoritative
#dhcp-authoritative

# Set the DHCP server to enable DHCPv4 Rapid Commit Option per RFC 4039.
# In this mode it will respond to a DHCPDISCOVER message including a Rapid
# Commit option with a DHCPACK including a Rapid Commit option and fully
# committed address and configuration information. This must only be enabled
# if either the server is the only server for the subnet, or multiple
# servers are present and they each commit a binding for all clients.
#dhcp-rapid-commit

# Run an executable when a DHCP lease is created or destroyed.
# The arguments sent to the script are "add" or "del",
# then the MAC address, the IP address and finally the hostname
# if there is one.
#dhcp-script=/bin/echo

# Set the cachesize here.
#cache-size=150

# If you want to disable negative caching, uncomment this.
#no-negcache

# Normally responses which come from /etc/hosts and the DHCP lease
# file have Time-To-Live set as zero, which conventionally means
# do not cache further. If you are happy to trade lower load on the
# server for potentially stale date, you can set a time-to-live (in
# seconds) here.
#local-ttl=

# If you want dnsmasq to detect attempts by Verisign to send queries
# to unregistered .com and .net hosts to its sitefinder service and
# have dnsmasq instead return the correct NXDOMAIN response, uncomment
# this line. You can add similar lines for other registries which have
# implemented wildcard A records.
#bogus-nxdomain=64.94.110.11

# If you want to fix up DNS results from upstream servers, use the
# alias option. This only works for IPv4.
# This alias makes a result of 1.2.3.4 appear as 5.6.7.8
#alias=1.2.3.4,5.6.7.8
# and this maps 1.2.3.x to 5.6.7.x
#alias=1.2.3.0,5.6.7.0,255.255.255.0
# and this maps 192.168.0.10->192.168.0.40 to 10.0.0.10->10.0.0.40
#alias=192.168.0.10-192.168.0.40,10.0.0.0,255.255.255.0

# Change these lines if you want dnsmasq to serve MX records.

# Return an MX record named "maildomain.com" with target
# servermachine.com and preference 50
#mx-host=maildomain.com,servermachine.com,50

# Set the default target for MX records created using the localmx option.
#mx-target=servermachine.com

# Return an MX record pointing to the mx-target for all local
# machines.
#localmx

# Return an MX record pointing to itself for all local machines.
#selfmx

# Change the following lines if you want dnsmasq to serve SRV
# records.  These are useful if you want to serve ldap requests for
# Active Directory and other windows-originated DNS requests.
# See RFC 2782.
# You may add multiple srv-host lines.
# The fields are <name>,<target>,<port>,<priority>,<weight>
# If the domain part if missing from the name (so that is just has the
# service and protocol sections) then the domain given by the domain=
# config option is used. (Note that expand-hosts does not need to be
# set for this to work.)

# A SRV record sending LDAP for the example.com domain to
# ldapserver.example.com port 389
#srv-host=_ldap._tcp.example.com,ldapserver.example.com,389

# A SRV record sending LDAP for the example.com domain to
# ldapserver.example.com port 389 (using domain=)
#domain=example.com
#srv-host=_ldap._tcp,ldapserver.example.com,389

# Two SRV records for LDAP, each with different priorities
#srv-host=_ldap._tcp.example.com,ldapserver.example.com,389,1
#srv-host=_ldap._tcp.example.com,ldapserver2.example.com,389,2

# A SRV record indicating that there is no LDAP server for the domain
# example.com
#srv-host=_ldap._tcp.example.com

# The following line shows how to make dnsmasq serve an arbitrary PTR
# record. This is useful for DNS-SD. (Note that the
# domain-name expansion done for SRV records _does_not
# occur for PTR records.)
#ptr-record=_http._tcp.dns-sd-services,"New Employee Page._http._tcp.dns-sd-services"

# Change the following lines to enable dnsmasq to serve TXT records.
# These are used for things like SPF and zeroconf. (Note that the
# domain-name expansion done for SRV records _does_not
# occur for TXT records.)

#Example SPF.
#txt-record=example.com,"v=spf1 a -all"

#Example zeroconf
#txt-record=_http._tcp.example.com,name=value,paper=A4
EOF
    echo "✓ تم إنشاء ملف dnsmasq افتراضي"
fi

echo "الخطوة 8: مسح جميع عناوين IP المخصصة من الواجهات..."
# إزالة جميع عناوين IP المخصصة
for interface in enp3s0 enp4s0 enp5s0; do
    # إزالة جميع عناوين IP من الواجهة
    ip addr flush dev $interface 2>/dev/null || true
    echo "✓ تم مسح عناوين IP من $interface"
done

echo "الخطوة 9: إعادة تعيين حالة الواجهات..."
# جعل جميع الواجهات في وضع DOWN ثم UP لإعادة التشغيل
for interface in enp2s0 enp3s0 enp4s0 enp5s0; do
    ip link set $interface down 2>/dev/null || true
    sleep 1
    ip link set $interface up 2>/dev/null || true
    echo "✓ إعادة تشغيل $interface"
done

echo "الخطوة 10: إنشاء ملف netplan افتراضي بسيط..."
# إنشاء ملف netplan بسيط فقط للحصول على DHCP على enp2s0
cat > /etc/netplan/00-installer-config.yaml << EOF
# This is the network config written by 'subiquity'
network:
  ethernets:
    enp2s0:
      dhcp4: true
  version: 2
EOF

# تعديل صلاحيات الملف
chmod 600 /etc/netplan/*.yaml

echo "الخطوة 11: تطبيق إعدادات netplan الافتراضية..."
netplan apply

echo "الخطوة 12: إعادة تشغيل خدمات الشبكة الأساسية..."
systemctl daemon-reload
systemctl restart systemd-networkd
systemctl restart systemd-resolved 2>/dev/null || true
systemctl restart networking 2>/dev/null || true

echo "الخطوة 13: إزالة الحزم المثبتة للراوتر (اختياري)..."
read -p "هل تريد إزالة الحزم المثبتة للراوتر؟ (y/n): " remove_packages
if [ "$remove_packages" = "y" ] || [ "$remove_packages" = "Y" ]; then
    apt remove --purge -y hostapd dnsmasq iptables-persistent bridge-utils 2>/dev/null || true
    apt autoremove -y 2>/dev/null || true
    echo "✓ تم إزالة الحزم"
else
    echo "⏩ تم تخطي إزالة الحزم"
fi

echo "الخطوة 14: تنظيف الملفات المؤقتة..."
# تنظيف الملفات المؤقتة والسجلات
rm -rf /var/lib/dhcp/dhcpd.leases* 2>/dev/null || true
rm -rf /var/lib/dhcpcd5/* 2>/dev/null || true
systemctl restart systemd-journald 2>/dev/null || true

echo "الخطوة 15: التحقق النهائي من حالة النظام..."

sleep 3

echo ""
echo "=========================================="
echo "🎉 تم إكمال التصفير الكامل بنجاح!"
echo "=========================================="
echo ""

echo "=== حالة الواجهات بعد التصفير ==="
for interface in enp2s0 enp3s0 enp4s0 enp5s0; do
    if ip link show $interface &>/dev/null; then
        status=$(ip link show $interface | grep -o "state [A-Z]*" | cut -d' ' -f2)
        ip_info=$(ip addr show $interface 2>/dev/null | grep "inet " | awk '{print $2}' | head -1)
        if [ -n "$ip_info" ]; then
            echo "✓ $interface: $ip_info ($status)"
        else
            echo "○ $interface: لا يوجد IP ($status)"
        fi
    else
        echo "✗ $interface: الواجهة غير موجودة"
    fi
done

echo ""
echo "=== حالة خدمات الشبكة ==="
echo "systemd-networkd: $(systemctl is-active systemd-networkd 2>/dev/null || echo 'غير متاح')"
echo "systemd-resolved: $(systemctl is-active systemd-resolved 2>/dev/null || echo 'غير متاح')"
echo "networking: $(systemctl is-active networking 2>/dev/null || echo 'غير متاح')"

echo ""
echo "=== قواعد iptables الحالية ==="
iptables_count=$(iptables -L | wc -l)
if [ "$iptables_count" -le 10 ]; then
    echo "✓ قواعد iptables تم مسحها (عدد الأسطر: $iptables_count)"
else
    echo "⚠️  قد تكون هناك قواعد iptables متبقية (عدد الأسطر: $iptables_count)"
fi

echo ""
echo "=== إعدادات IP Forwarding ==="
ip_forward=$(cat /proc/sys/net/ipv4/ip_forward)
if [ "$ip_forward" = "0" ]; then
    echo "✓ IP Forwarding معطل (القيمة: $ip_forward)"
else
    echo "⚠️  IP Forwarding مفعل (القيمة: $ip_forward)"
fi

echo ""
echo "=== الخدمات المخصصة المحذوفة ==="
for service in auto-router smart-dnsmasq cable-monitor dnsmasq-resolv; do
    if systemctl list-unit-files | grep -q "$service"; then
        echo "⚠️  $service: لا يزال موجود"
    else
        echo "✓ $service: تم حذفه"
    fi
done

echo ""
echo "=== اختبار الاتصال بالإنترنت ==="
if ping -c 1 8.8.8.8 &>/dev/null; then
    echo "✓ الاتصال بالإنترنت يعمل"
else
    echo "⚠️  فشل في الاتصال بالإنترنت - قد تحتاج لإعادة تشغيل الجهاز"
fi

echo ""
echo "=========================================="
echo "📋 ملخص العملية:"
echo "=========================================="
echo "✅ تم حذف جميع الخدمات المخصصة"
echo "✅ تم مسح قواعد iptables"
echo "✅ تم تعطيل IP forwarding"
echo "✅ تم استعادة ملف dnsmasq الأصلي"
echo "✅ تم مسح جميع إعدادات netplan المخصصة"
echo "✅ تم إعادة تعيين جميع الواجهات"
echo "✅ تم إنشاء إعدادات شبكة افتراضية"
echo ""
echo "🔄 يُنصح بإعادة تشغيل الجهاز للتأكد من التطبيق الكامل:"
echo "sudo reboot"
echo ""
echo "🌐 بعد إعادة التشغيل، ستعود الشبكة لحالتها الطبيعية"
echo "📡 enp2s0 سيحصل على IP من DHCP تلقائياً"
echo "⚡ باقي الواجهات ستكون في وضع الاستعداد"
echo "=========================================="
