#!/bin/bash

if [ $# -eq 0 ]; then
    echo "Rsync retry control
This script will restart a rsync command if an error occurs as rsync does not have a --retry parameter.
Usefull for long transfert where the connection can be lost.

Syntax:
    $( basename $0 ) [any rsync parameters] <source> <dest>

notice: no extra parameters are provided, even the --partial parameter must be set
"
    exit 1
fi

if ! command -v rsync >/dev/null; then echo "Error: rsync was not found in the path"; exit 1; fi

echo "rsync wrapper - start time: $(date '+%Y%m%d-%H%M%S')"
while :
do
    rsync "$@"
    if [ $? -eq 0 ]; then break; fi
    sleep 60
done

echo "rsync wrapper - end time: $(date '+%Y%m%d-%H%M%S')"
