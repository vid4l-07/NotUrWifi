#!/bin/bash
# Por Hugo Vidal 2024-2025
export TERM=xterm
trap ctrl_c INT
function ctrl_c(){
#	echo -e " Saliendo..."
	rm -r content 2>/dev/null
	modo="$(iw dev $moninterface info 2>/dev/null | awk '/type/ {print $2}')"
	if [[ "$modo" == "monitor" || "$modo" == "AP" ]]; then
		ifconfig $moninterface down >/dev/null 2>&1; sleep 1
		iwconfig $moninterface mode monitor >/dev/null 2>&1; sleep 1
		ifconfig $moninterface up >/dev/null 2>&1
		airmon-ng stop $moninterface > /dev/null 2>&1
		systemctl start wpa_supplicant NetworkManager > /dev/null 2>&1
	fi
	exit 0
}

function banner(){
#	echo -e "\n***********************************************"
#	echo -e "**                                           **"
#	echo -e "**    /\/0T|_|R\/\/1F1    (Por Hugo Vidal)   **"
#	echo -e "**                                           **"
#	echo -e "***********************************************"
echo -e "
____    ___   ______  __ __  ____   __    __  ____  _____  ____
|    \  /   \ |      ||  |  ||    \ |  |__|  ||    ||     ||    |
|  _  \/     \|      ||  |  ||  D  ||  |  |  | |  | |   __| |  |
|  |  ||  O  ||_    _||  |  ||    / |  |  |  | |  | |  |_   |  |\t(Hecho por Hugo Vidal)
|  |  ||     |  |  |  |  |  ||    \ |  |  |  | |  | |   _|  |  |
|  |  ||     |  |  |  |     ||  |  \ \      /  |  | |  |    |  |
|__|__| \___/   |__|   \____/|__|\_|  \_/\_/  |____||__|   |____|
"
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

	interfaz="asdcds"
    while !(grep $interfaz content/interfaces.txt >/dev/null 2>&1); do
		echo -ne "\nNombre de la interfaz a usar (Ej: wlan0): " && read -r interfaz
		if !(grep $interfaz content/interfaces.txt >/dev/null 2>&1); then
			echo -e "\nLa interfaz $interfaz no existe"
		fi
	done; sleep 1

	echo -e "\n. . . . Matando los procesos que puedan interferir"
	systemctl stop wpa_supplicant NetworkManager
	sleep 1
	echo -e ". . . . Poniendo la interfaz $interfaz en modo monitor\n"
	airmon-ng start $interfaz > /dev/null 2>&1
	sleep 0.5
	iw dev | awk '/Interface/ {iface=$2} /type monitor/ {print iface}' > ./content/interfaz
	moninterface=$(/bin/cat ./content/interfaz)
	echo -e "\nInterfaz $moninterface creada\n"
	sleep 1
}

################################    Inicio del programa    #############################

if [ "$(id -u)" -eq 0 ];then
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

mkdir content data 2>/dev/null
banner
mon_interfaz

if [ "$1" == "-a" ];then
	/bin/bash ./ap.sh

elif [ "$1" == "-p" ];then
	/bin/bash ./wifipass.sh
fi


