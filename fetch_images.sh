#!/bin/bash

boards=( "snickerdoodle" "snickerdoodle_black" "snickerdoodle_prime_le" "snickerdoodle_one" )

wget https://krtkl.com/uploads/images.md5

for board in "${boards[@]}"; do
	if ! [ -e "$board.img" ] || ! [ md5sum --ignore-missing --status -c images.md5 ]; then
		wget https://krtkl.com/uploads/$board.img.zip
		unzip -o $board.img.zip
	fi
done
