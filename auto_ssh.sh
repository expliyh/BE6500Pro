#!/bin/sh

auto_ssh_dir="/data/auto_ssh"
host_key="/etc/dropbear/dropbear_rsa_host_key"
host_key_bk="${auto_ssh_dir}/dropbear_rsa_host_key"

unlock() {
    # Restore the host key.
    [ -f $host_key_bk ] && ln -sf $host_key_bk $host_key

    # Enable telnet, ssh, uart and boot_wait.
    [ "$(nvram get telnet_en)" = 0 ] && nvram set telnet_en=1 && nvram commit
    [ "$(nvram get ssh_en)" = 0 ] && nvram set ssh_en=1 && nvram commit
    [ "$(nvram get uart_en)" = 0 ] && nvram set uart_en=1 && nvram commit
    [ "$(nvram get boot_wait)" = "off" ]  && nvram set boot_wait=on && nvram commit

    [ "`uci -c /usr/share/xiaoqiang get xiaoqiang_version.version.CHANNEL`" != 'stable' ] && {
        uci -c /usr/share/xiaoqiang set xiaoqiang_version.version.CHANNEL='stable' 
        uci -c /usr/share/xiaoqiang commit xiaoqiang_version.version 2>/dev/null
    }

    channel=`/sbin/uci get /usr/share/xiaoqiang/xiaoqiang_version.version.CHANNEL`
    if [ "$channel" = "release" ]; then
        sed -i 's/channel=.*/channel="debug"/g' /etc/init.d/dropbear
    fi

    if [ -z "$(pidof dropbear)" -o -z "$(netstat -ntul | grep :22)" ]; then
        /etc/init.d/dropbear restart 2>/dev/null
        /etc/init.d/dropbear enable
    fi
}

wireless() {
    uci set network.eth1_4_30=interface
    uci set network.eth1_4_30.ifname='eth1.4.30'
    uci set network.eth1_4_30.force_link='1'
    
    uci set network.eth1_4_1145=interface
    uci set network.eth1_4_1145.ifname='eth1.4.1145'
    uci set network.eth1_4_1145.force_link='1'

    uci set network.lan.ifname='eth0.1 eth0.2 eth1.3 eth1.4.30'

    uci set network.guest_lan=interface
    uci set network.guest_lan.force_link='1'
    uci set network.guest_lan.type='bridge'
    uci set network.guest_lan.proto='static'
    uci set network.guest_lan.multicast_querier='0'
    uci set network.guest_lan.igmp_snooping='0'
    uci set network.guest_lan.ip6assign='64'
    uci set network.guest_lan.macaddr='a4:a9:30:88:9e:b8'
    uci set network.guest_lan.netmask='255.255.0.0'
    uci set network.guest_lan.gateway='10.0.0.1'
    uci set network.guest_lan.mtu='1500'
    uci set network.guest_lan.ifname='eth1.4.1145'
    uci set network.guest_lan.ipaddr='10.0.255.100'
    uci delete network.guest_lan.dns
    uci add_list network.guest_lan.dns='10.0.0.1'
    
    uci commit
    
    uci set wireless.guest_wifi=wifi-iface
    uci set wireless.guest_wifi.mode='ap'
    uci set wireless.guest_wifi.ifname='wl18'
    uci set wireless.guest_wifi.device='wifi0'
    uci set wireless.guest_wifi.ssid='Xiaomi_E068_GUEST'
    uci set wireless.guest_wifi.encryption='psk2+ccmp'
    uci set wireless.guest_wifi.key='12345678'
    uci set wireless.guest_wifi.sae_password='12345678'
    uci set wireless.guest_wifi.network='guest_lan'
    uci set wireless.guest_wifi.he_ul_ofdma='0'
    uci set wireless.guest_wifi.mscs='1'
    uci set wireless.guest_wifi.hlos_tidoverride='1'
    uci set wireless.guest_wifi.amsdu='2'
    uci set wireless.guest_wifi.wnm='1'
    uci set wireless.guest_wifi.rrm='1'
    uci set wireless.guest_wifi.disabled='0'
    uci set wireless.guest_wifi.bsd='1'
    uci set wireless.guest_wifi.sae='1'
    uci set wireless.guest_wifi.ieee80211w='1'
    
    uci set wireless.guest_wifi5=wifi-iface
    uci set wireless.guest_wifi5.mode='ap'
    uci set wireless.guest_wifi5.ifname='wl19'
    uci set wireless.guest_wifi5.device='wifi1'
    uci set wireless.guest_wifi5.ssid='Xiaomi_E068_GUEST'
    uci set wireless.guest_wifi5.encryption='psk2+ccmp'
    uci set wireless.guest_wifi5.key='12345678'
    uci set wireless.guest_wifi5.sae_password='12345678'
    uci set wireless.guest_wifi5.network='guest_lan'
    uci set wireless.guest_wifi5.he_ul_ofdma='0'
    uci set wireless.guest_wifi5.mscs='1'
    uci set wireless.guest_wifi5.hlos_tidoverride='1'
    uci set wireless.guest_wifi5.amsdu='2'
    uci set wireless.guest_wifi5.wnm='1'
    uci set wireless.guest_wifi5.rrm='1'
    uci set wireless.guest_wifi5.disabled='0'
    uci set wireless.guest_wifi5.bsd='1'
    uci set wireless.guest_wifi5.sae='1'
    uci set wireless.guest_wifi5.ieee80211w='1'

    uci commit

    /etc/init.d/network restart
}

install() {
    # unlock SSH.
    unlock

    # host key is empty, restart dropbear to generate the host key.
    [ -s $host_key ] || /etc/init.d/dropbear restart 2>/dev/null

    # Backup the host key.
    if [ ! -s $host_key_bk ]; then
        i=0
        while [ $i -le 30 ]
        do
            if [ -s $host_key ]; then
                cp -f $host_key $host_key_bk 2>/dev/null
                break
            fi
            let i++
            sleep 1s
        done
    fi

    # Add script to system autostart
    uci set firewall.auto_ssh=include
    uci set firewall.auto_ssh.type='script'
    uci set firewall.auto_ssh.path="${auto_ssh_dir}/auto_ssh.sh"
    uci set firewall.auto_ssh.enabled='1'
    uci commit firewall
    echo -e "\033[32m SSH unlock complete. \033[0m"
}

uninstall() {
    # Remove scripts from system autostart
    uci delete firewall.auto_ssh
    uci commit firewall
    echo -e "\033[33m SSH unlock has been removed. \033[0m"
}

main() {
    if [ -z "$1" ] && [ -f /tmp/ssh_set.lock ]; then
        return
    fi
    [ -z "$1" ] && unlock && wireless && touch /tmp/ssh_set.lock && return
    case "$1" in
    install)
        install
        ;;
    uninstall)
        uninstall
        ;;
    *)
        echo -e "\033[31m Unknown parameter: $1 \033[0m"
        return 1
        ;;
    esac
}

main "$@"
