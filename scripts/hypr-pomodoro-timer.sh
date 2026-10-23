#!/bin/bash
# Minimal Suspend Pomodoro for MangoWM

WORK_MINS=${1:-25}
SKIP_REMINDER_MINS=3
ROFI_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/mango/rofi/config.rasi"

while true; do
    # 1. Work Phase
    sleep $(( WORK_MINS * 60 ))
    
    while true; do
        # 2. Break Prompt
        notify-send -a "Pomodoro Timer" "Take a break."
        sleep 5
        CHOICE=$(echo -e "Yes\nSkip\nNo" | rofi -dmenu \
            -p "Pomodoro Timer: break?" \
            -config "$ROFI_CONFIG" \
        )
        if [[ "$CHOICE" == "Yes" ]]; then
            # Launch screen lock
            bash "${XDG_CONFIG_HOME:-$HOME/.config}/mango/scripts/LockScreen.sh" &
            sleep 2
            
            # Put the system to sleep
            systemctl suspend
            
            # --- SCRIPT PAUSES HERE ---
            notify-send -u low -a "Pomodoro Timer" "Welcome Back"
            break # Exit break loop and start new work phase
        elif [[ "$CHOICE" == "Skip" ]]; then
            # Remind to take a break after a short delay
            notify-send -u low -a "Pomodoro Timer" "Break skipped. Reminder in ${SKIP_REMINDER_MINS} min."
            sleep $(( SKIP_REMINDER_MINS * 60 ))
        else
            # Quit the pomodoro timer
            notify-send -u low -a "Pomodoro Timer" "Pomodoro stopped."
            exit 0
        fi
    done
done
