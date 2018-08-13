#!/bin/sh

. /usr/share/functions.sh

do_restart=0

reset_leds () {
  for trigger_path in $(ls -d /sys/class/leds/*)       
  do                                                   
    echo "none" > "$trigger_path"/trigger              
    echo "0" > "$trigger_path"/brightness              
  done

  /etc/init.d/led restart >/dev/nul
  #reset lan ports if any
  for lan_led in /sys/class/leds/*lan*
  do
    if [ -f "$lan_led"/enable_hw_mode ]; then
      echo 1 > "$lan_led"/enable_hw_mode
    fi
  done

  #reset system led
  #TODO: blink on flashing firmware?
  case $(cat /tmp/sysinfo/board_name) in
    tl-wr840n-v5 | tl-wr840n-v6 | tl-wr849n-v5 | tl-wr849n-v6)
      echo "none" > /sys/class/leds/$(cat /tmp/sysinfo/board_name)\:orange\:power/trigger
      echo 0 > /sys/class/leds/$(cat /tmp/sysinfo/board_name)\:orange\:power/brightness
      systemled=/sys/class/leds/$(cat /tmp/sysinfo/board_name)\:green\:power

      echo "netdev" > $systemled/trigger
      echo "rx" > $systemled/mode
      echo "eth0.2" > $systemled/device_name
      ;;
    *)
      for system_led in /sys/class/leds/*system* /sys/class/leds/*power*
      do
        if [ -f "$system_led"/brightness ]; then
          if [ -f "$system_led"/max_brightness ]; then
            cat "$system_led"/max_brightness > "$system_led"/brightness
          else
            echo "255" > "$system_led"/brightness
          fi
        fi
      done
      ;;
  esac

  #wifi 2g
  case $(cat /tmp/sysinfo/board_name) in
    tl-wr840n-v4 | tl-wr849n-v4)
      echo "netdev" > $systemled/trigger
      echo "rx" > $systemled/mode
      echo "ra0" > $systemled/device_name
      ;;
    *)
      ;;
  esac

  #reset 5G if any
  if [ -f /sys/class/leds/ath9k-phy1/trigger ]; then
    echo "phy1tpt" > /sys/class/leds/ath9k-phy1/trigger
  fi

  #reset wan if any
  for wan_led in /sys/class/leds/*wan*
  do                                      
    if [ -f "$wan_led"/enable_hw_mode ]; then
      echo 1 > "$wan_led"/enable_hw_mode
    fi
  done
  do_restart=0
}

blink_leds () {
  if [ $do_restart -eq 0 ]                                                               
  then                                                                                   
    case $(cat /tmp/sysinfo/board_name) in                                               
      tl-wr840n-v5 | tl-wr840n-v6 | tl-wr849n-v5 | tl-wr849n-v6)                         
        echo "none" > /sys/class/leds/$(cat /tmp/sysinfo/board_name)\:green\:power/trigger
        echo 0 > /sys/class/leds/$(cat /tmp/sysinfo/board_name)\:green\:power/brightness  
        ledsoff=/sys/class/leds/$(cat /tmp/sysinfo/board_name)\:orange\:power             
        ;;                                                                                
      *)                                                                                  
        ledsoff=$(ls -d /sys/class/leds/*)                                                
        ;;                                                                                
    esac                                                                                  
                                                                                          
    for trigger_path in $ledsoff                                                          
    do                                                                                    
      echo "timer" > "$trigger_path"/trigger                                              
    done                                                                                  
  fi
}

reset_leds
while true
do
  wan_itf_name=$(uci get network.wan.ifname)
  if [ -f /sys/class/net/$wan_itf_name/carrier ]
  then
    is_cable_conn=$(cat /sys/class/net/$wan_itf_name/carrier)

    if [ $is_cable_conn -eq 1 ]
    then
      # We have layer 2 connectivity, now check external access
      if [ ! "$(check_connectivity_internet)" -eq 0 ]
      then
        # No external access
        if [ $do_restart -ne 1 ]
        then
          log "CHECK_WAN" "No external access..."
          blink_leds
          do_restart=1
        fi 
      else
        # The device has external access. Cancel notifications
        if [ $do_restart -ne 0 ]
        then
          log "CHECK_WAN" "External access restored..."
          reset_leds
        fi
      fi
    else
      # Cable is not connected
      if [ $do_restart -ne 2 ]
      then
        log "CHECK_WAN" "Cable not connected..."
        blink_leds
        do_restart=2
      fi 
    fi
  else
    # WAN interface not created yet
    if [ $do_restart -ne 3 ]
    then
      log "CHECK_WAN" "No WAN interface..."
      blink_leds
      do_restart=3
    fi 
  fi
  sleep 2
done
