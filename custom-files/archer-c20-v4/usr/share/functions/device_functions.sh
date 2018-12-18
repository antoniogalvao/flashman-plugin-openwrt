#!/bin/sh

save_wifi_local_config() {
  uci commit wireless
  /usr/bin/uci2dat -d radio0 -f /etc/wireless/mt7628/mt7628.dat > /dev/null
  /usr/bin/uci2dat -d radio1 -f /etc/Wireless/iNIC/iNIC_ap.dat > /dev/null
}

led_on() {
  if [ -f "$1"/brightness ]
  then
    if [ -f "$1"/max_brightness ]
    then
      cat "$1"/max_brightness > "$1"/brightness
    else
      echo "255" > "$1"/brightness
    fi
  fi
}

led_off() {
  if [ -f "$1"/trigger ]
  then
    echo "none" > "$1"/trigger
    echo "0" > "$1"/brightness
  fi
}

reset_leds() {
  for trigger_path in $(ls -d /sys/class/leds/*)
  do
    led_off "$trigger_path"
  done

  /etc/init.d/led restart > /dev/null

  led_on /sys/class/leds/$(cat /tmp/sysinfo/board_name)\:green\:power
  # bug on archer's lan led
  echo "0" > \
    /sys/class/leds/$(cat /tmp/sysinfo/board_name)\:green\:lan/port_mask
  echo "0x1e" > \
    /sys/class/leds/$(cat /tmp/sysinfo/board_name)\:green\:lan/port_mask
}

blink_leds() {
	local _do_restart=$1

  if [ $_do_restart -eq 0 ]
  then
    led_off /sys/class/leds/$(cat /tmp/sysinfo/board_name)\:green\:power
    # we cant turn on orange and blue at same time in this model
    ledsoff=$(ls -d /sys/class/leds/*green*)

    for trigger_path in $ledsoff
    do
      echo "timer" > "$trigger_path"/trigger
    done
  fi
}

get_mac() {
  local _mac_address_tag=""

  if [ ! -z "$(awk '{ print toupper($1) }' /sys/class/net/eth0/address)" ]
  then
    _mac_address_tag=$(awk '{ print toupper($1) }' /sys/class/net/eth0/address)
  fi

  echo "$_mac_address_tag"
}
