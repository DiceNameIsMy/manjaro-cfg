#!/bin/bash

notify-send "Dictation Started" "Dictation Started"

YDOTOOL_SOCKET="/tmp/.ydotool_socket" nerd-dictation begin --simulate-input-tool=YDOTOOL
