#!/bin/sh

SRC="src/main.c src/dict_util.c src/data/os.c src/data/cpu.c src/rpc.c"
STDFLAGS="-Iinclude -Wall"
OUTPUT="dcfetch"

CC="cc"
OS=$(uname)
TARGET="$1"

if [ "$TARGET" = "" ]; then
	if [ $OS = "Linux" ]; then
		SRC="$SRC src/audio/linux.c"
	elif [ $OS = "Darwin" ]; then
		STDFLAGS="$STDFLAGS -framework Foundation -F /System/Library/PrivateFrameworks -weak_framework MediaRemote"
		SRC="$SRC src/audio/macos.m"
	else
		SRC="$SRC src/audio/unsupported.c"
	fi

	set -x

	$CC $SRC $STDFLAGS -o $OUTPUT
elif [ "$TARGET" = "install" ]; then
	set -x
		
	mkdir -p /usr/local/bin
	chmod +x $OUTPUT
	cp -f $OUTPUT /usr/local/bin
fi
