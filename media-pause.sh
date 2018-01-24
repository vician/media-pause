#!/bin/bash

if [ $# -eq 0 ]; then
	control="toggle"
fi
if [ $# -ge 1 ]; then
	control=$1
fi
if [ $# -ge 2 ]; then
	player=$2
fi

players=("first" "gnome-mplayer" "vlc" "gradio" "spotify")

function get_custom_player {
	control=$1
	if [ -f "$HOME/.players" ]; then
		echo "loading $HOME/.players"
		source $HOME/.players # Load lists of players
	fi
	echo "players: ${players[*]}"
	for i_player in ${players[@]}; do
		if [ "$i_player" == "first" ] || [ "$i_player" == "auto" ]; then
			continue
		fi
		pgrep $i_player 1>/dev/null 2>/dev/null
		if [ $? -eq 0 ]; then
			custom_player="$i_player"
			echo "found $i_player!"
			break
		fi
	done

	if [ "$custom_player" == "first" ] || [ ! "$custom_player" ]; then
		echo "Cannot find player for $@1"
		notify-send "ERROR: Cannot find player for $@!"
		exit 0
	fi
	dbus $custom_player $control
}

function get_all_players {
	control=$1
	players=($(dbus-send --session --dest=org.freedesktop.DBus \
		--type=method_call --print-reply /org/freedesktop/DBus \
		org.freedesktop.DBus.ListNames | grep org.mpris.MediaPlayer2 |
	awk -F\" '{print $2}' | cut -d '.' -f4- | sort | sed ':a;N;$!ba;s/\n/ /g'))
	echo "players: [${#players[@]}] ${players[@]}"
	echo "control: $control"
	for player in ${players[@]}; do
		echo "- $player $control"
		dbus $player $control
	done
}

function get_first_player {
	control=$1
	players=($(dbus-send --session --dest=org.freedesktop.DBus \
		--type=method_call --print-reply /org/freedesktop/DBus \
		org.freedesktop.DBus.ListNames | grep org.mpris.MediaPlayer2 |
	awk -F\" '{print $2}' | cut -d '.' -f4- | sort | sed ':a;N;$!ba;s/\n/ /g'))
	echo "players: [${#players[@]}] ${players[@]}"
	echo "control: $control"
	for player in ${players[@]}; do
		echo "- $player $control"
		dbus $player $control
		exit 1
	done
}

function dbus {
	player=$1
	control=$2
	echo "dbus $player $control"
	PATHS="org.mpris.MediaPlayer2.$player /org/mpris/MediaPlayer2"
	DBUS_SEND="dbus-send --type=method_call --dest=$PATHS"
	RC="$DBUS_SEND org.mpris.MediaPlayer2.Player"
	if [ "$control" == "prev" ]; then
		echo "going previous song"
		$RC.Previous
	elif [ "$control" = "stop" ] || [ "$control" == "pause" ]; then
		echo "pausing"
		$RC.Pause
	elif [ "$control" == "play" ]; then
		echo "playing"
		$RC.Play
	elif [ "$control" == "toggle" ]; then
		echo "playpausing"
		$RC.PlayPause
	elif [ "$control" == "next" ]; then
		echo "going next song"
		$RC.Next
	elif [ "$control" == "random" ]; then
		echo "randoming"
		current=$(mdbus2 $PATHS org.freedesktop.DBus.Properties.Get org.mpris.MediaPlayer2.Player Shuffle)
		if [ "$current" = "( true)" ]; then
			other=false
		else
			other=true
		fi
		$DBUS_SEND org.freedesktop.DBus.Properties.Set string:org.mpris.MediaPlayer2.Player string:Shuffle variant:boolean:$other
	else
		notify-send "Command not found for player $player: $control"
		exit 1
	fi
}

if [ "$player" == "first" ]; then
	get_first_player $control
elif [ "$player" == "all" ]; then
	get_all_players $control
elif [ "$player" == "custom" ]; then
	get_custom_player $control
else
	dbus $player $control
fi

