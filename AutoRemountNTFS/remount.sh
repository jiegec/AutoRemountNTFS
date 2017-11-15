/sbin/umount $2
/bin/mkdir $2
/sbin/mount -t ntfs -o rw,auto,nobrowse $1 $2
/bin/ln -s -f $2 ~/Desktop