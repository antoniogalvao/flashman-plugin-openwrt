#!/bin/sh

save_wifi_local_config() {
  uci commit wireless
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

  led_on /sys/class/leds/$(cat /tmp/sysinfo/board_name)\:green\:status
}

blink_leds() {
	local _do_restart=$1

  if [ $_do_restart -eq 0 ]
  then
    ledsoff=$(ls -d /sys/class/leds/*)
    for trigger_path in $ledsoff
    do
      echo "timer" > "$trigger_path"/trigger
    done
  fi
}
