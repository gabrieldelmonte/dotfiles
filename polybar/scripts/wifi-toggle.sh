#!/usr/bin/env bash
# Wi-Fi on/off (click the Wi-Fi icon in the bar; the network name opens nmtui).
# Same switch as GNOME's Wi-Fi toggle: NetworkManager's radio (a soft block).
if [ "$(nmcli radio wifi)" = enabled ]; then
    nmcli radio wifi off && notify-send -a Network -i network-wireless-offline "Wi-Fi off"
else
    nmcli radio wifi on && notify-send -a Network -i network-wireless "Wi-Fi on" "Reconnecting…"
fi
