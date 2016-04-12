#!/bin/bash
### BEGIN INIT INFO
# Provides: archive.sh
# Required-Start: $local_fs $syslog
# Required-Stop: $local_fs $syslog
# Default-Start: 2 3 4 5
# Default-Stop: 0
# Short-Description: Archives directories with their content at shutdown.
### END INIT INFO

. /lib/lsb/init-functions

stop () {
	CONFIG="/etc/archive/archive.conf"
	UPDATEMODE=false
	VERBOSE=false
	
	isEmpty () {
		#Excluding every commented out line with an extended regex.
		if [ $(grep -E "^[^#]*$1" $CONFIG | cut -f2 -d" ") == "$1" ]; then
			echo "true"
		fi
	}
	
	#Check if we have a non-empty ArchiveFolder config param, and if yes, make that the target directory.
	if [[ $(grep -E "^[^#]*ArchiveFolder" $CONFIG) && ! $(isEmpty "ArchiveFolder") ]]; then
		TARGET=$(grep -E "^[^#]*ArchiveFolder" $CONFIG | cut -f2 -d" ")
	#Check if we have non-empty ArchiveDisk and MountPoint paramteres.
	elif [[ $(grep -E "^[^#]*ArchiveDisk" $CONFIG) && ! $(isEmpty "ArchiveDisk") && $(grep -E "^[^#]*MountPoint" $CONFIG) && ! $(isEmpty "MountPoint") ]]; then
		TARGET=$(grep -E "^[^#]*MountPoint" $CONFIG | cut -f2 -d" ")
		DISK=$(grep -E "^[^#]*ArchiveDisk" $CONFIG | cut -f2 -d" ")
		#If our target directory does not exist, create it, then mount it up.
		if [ ! -d "$TARGET" ]
			then
				mkdir "$TARGET"
		fi
		#Check if the mount point is free, or mounted correctly before proceeding.
		if mountpoint -q -- $TARGET; then
			if [ $(mount | grep $TARGET | cut -f1 -d" ") != "$DISK" ]; then
				echo "Archiving process is halted as MountPoint is already used by a different device."
				exit 1
			fi
		fi
		mount "$DISK" "$TARGET" 2> /dev/null
	else
		echo "Archiving process is halted due to bad configuration."
		exit 1
	fi
	
	#If archive disk is mounted as read only, remount it with proper permissions.
	if mount | grep -E "$TARGET.*ro"; then
		mount -o remount,rw $TARGET
	fi
	
	#Set flags based on config file.
	#TODO: implement verbose mode.
	if [[ $(grep -E "^[^#]*UpdateMode" $CONFIG | cut -f2 -d" ") == "On" ]]; then
		UPDATEMODE=true
	fi
	if [[ $(grep -E "^[^#]*VerboseMode" $CONFIG | cut -f2 -d" ") == "On" ]]; then
		VERBOSE=true
	fi
	
	#Iterate through every map in the config file. Seperate the paths with AWK, as cut takes only a single char delimiter. Maybe using : as a delimiter
	#would be better.
	echo "Creating archives."
	for map in $(grep -E -- "^[^#]*->" $CONFIG); do
		FROM=$(echo $map | awk 'BEGIN {FS = "->"}; {print $1}')
		TO=$(echo $map | awk 'BEGIN {FS = "->"}; {print $2}')
		#Handle old records correctly, otherwise the whole system will be archived.
		if [ -d "$FROM" ]; then
			cd $FROM
			if [ ! -d "$TARGET$TO" ]; then
				mkdir "$TARGET$TO"
			fi
			for dir in $(ls -d */); do
				#If UpdateMode is On, check the archives if they need to be updated, and act accordingly.
				#TODO: Check if we have enough space on the target device.
				if [[ -e "$TARGET$TO/${dir%%/}.tar.gz" && $UPDATEMODE == true ]]; then
					#Sync the output of tar -lv and ls -l, and diff them. ls -l: feed from find for absolute path -> format time stamp -> cut no. of links ->
					#change "owner group" to "owner/group" -> remove pretty print whitespaces -> sort the list. tar -vf: remove directories (size mismatch) ->
					#remove pretty print whitespaces -> sort the list.
					if [[ $(diff <(find $dir -type f -exec ls -l --time-style="+%Y-%m-%d %H:%M" {} \; | cut -f1,3- -d" " | sed "s/ /\//2" | sed "s/ \+/ /g" | sort) <(tar -ztvf "$TARGET$TO/${dir%%/}.tar.gz" | grep -v "^d" | sed "s/ \+/ /g" | sort)) ]]; then
						#Store temp files in the shared memory tmpfs. Free memory in the end.
						gzip -dkc "$TARGET$TO/${dir%%/}.tar.gz" > "/dev/shm/${dir%%/}.tar"
						#If we do not have files in the archive, which are deleted in the FS, choose the easy way.
						if tar -df "/dev/shm/${dir%%/}.tar" -C .; then
							tar -uf "/dev/shm/${dir%%/}.tar" "$dir"
						#Else, recreate the whole archive.
						else
							rm "/dev/shm/${dir%%/}.tar"
							tar -cvf "/dev/shm/${dir%%/}.tar" "$dir"
						fi
						gzip -c "/dev/shm/${dir%%/}.tar" > "$TARGET$TO/${dir%%/}.tar.gz"
						rm "/dev/shm/${dir%%/}.tar"
					fi
				#Else, just create the archive.
				elif [[ ! -e "$TARGET$TO/${dir%%/}.tar.gz" ]]; then
					tar -czf "$TARGET$TO/${dir%%/}.tar.gz" "$dir"
				fi
			done
		fi
	done
	
	echo "Archiving process finished."
	
	#For increased portability sync, and unmount.
	sync
	umount "$TARGET" 2> /dev/null
    exit 0
}

case "$1" in
    start)
        exit 0
    ;;
    stop)
        log_daemon_msg "Creating archives"
	    stop
        log_end_msg $0
        exit 0
	;;
    *)
	    echo "Usage: $0 stop" >&2
	    exit 1
	;;
esac

