#!/bin/bash

BRIGHTNESS=-1
SPEED=()
GIF=
FONT="/usr/share/fonts/noto/NotoSans-ThinItalic.ttf"
IMG_PATH="/tmp/time.png"
CLOCK=
MON=

print_usage() {
	cat <<-EOF
		Wrong input! Available flags:
		-b brightness:0-100%
		-l liquid lcd mode
		-g gif lcd mode
		-s pump speed:0-100%,0-100C
		-c change .gif
		-t clock mode
		-m monitor mode
		-d load default profile
		-p load user profile
	EOF
}

set_lcd_mode() {
	[[ -z $GIF ]] && echo "GIF not set!" && exit 1
	liquidctl --match NZXT set lcd screen "$1" "$2"
}

get_sensor_data() {
	sensors -j | jq '(
		."amdgpu-pci-2800"."edge"."temp1_input",
		."z53-hid-3-9"."Coolant temp"."temp1_input", 
		."k10temp-pci-00c3"."Tctl"."temp1_input", 
		."amdgpu-pci-2800"."mem"."temp3_input", 
		."amdgpu-pci-2800"."junction"."temp2_input", 
		."corsairpsu-hid-3-d"."power +12v"."power2_input"
	)*10|round/10'
		
}

update_clock_image() {
	magick 	-size 320x320 gradient:black-black \
		-font ${FONT} \
		-tile gradient:blue-magenta \
		-gravity center \
		-pointsize 150 \
		-annotate +0-70 "$(date +%H)" \
		-pointsize 150 \
		-annotate +0+70 "$(date +%M)" "${IMG_PATH}"
	set_lcd_mode "static" "${IMG_PATH}"
}

update_sensors_image() {
	declare -a data
	readarray -t data < <(get_sensor_data)
	magick 	-size 320x320 gradient:black-black \
		-font ${FONT} \
		-tile gradient:blue-magenta \
		-gravity center \
		-pointsize 80 \
		-annotate +0-100     "$(date +%H:%M)" \
		-pointsize 50 \
		-annotate +0-45      "GPU:${data[0]}" \
		-pointsize 50 \
		-annotate +0+0   "Coolant:${data[1]}" \
		-pointsize 50 \
		-annotate +0+45      "CPU:${data[2]}" \
		-pointsize 30 \
		-annotate +0+80   "GPUMem:${data[3]}" \
		-pointsize 30 \
		-annotate +0+110  "GPUHot:${data[4]}" \
		-pointsize 20 \
		-annotate +0+135 "PSU12VR:${data[5]}W" "${IMG_PATH}"
	set_lcd_mode "static" "${IMG_PATH}"
}

refresh_display() {
	while true; do
		"$1"
		sleep "$2"
	done
}

liquidctl initialize all > /dev/null 2>&1

while getopts "b:lgs:c:tmdp" flag; do
	case "${flag}" in
		b) BRIGHTNESS="${OPTARG}" ;;
		l) set_lcd_mode "liquid" ;;
		g) set_lcd_mode "gif" "${GIF}" ;;
		s) SPEED+=("${OPTARG}") ;;
		c) GIF="${OPTARG}" ;; 
		t) CLOCK=1 ;; 
		m) MON=1 ;;
		d) BRIGHTNESS=50 SPEED=(20 40 23 50 30 70); set_lcd_mode "liquid"; break ;;
		p) BRIGHTNESS=0  SPEED=(35); set_lcd_mode "gif" "${GIF}"; break ;;
		*) print_usage; exit 0 ;;
	esac
done

[[ ${BRIGHTNESS} -ge 0 ]] && [[ ${BRIGHTNESS} -le 100 ]]  && \
	liquidctl --match NZXT set lcd screen brightness "${BRIGHTNESS}"

[[ ${#SPEED[@]} -gt 0 ]] && \
	(IFS=,; liquidctl --match NZXT set pump speed ${SPEED[*]})

[[ -n $CLOCK ]] && refresh_display "update_clock_image" "30"

[[ -n $MON ]] && refresh_display "update_sensors_image" ".5"
