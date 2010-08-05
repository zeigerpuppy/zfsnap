#!/bin/sh

# "THE BEER-WARE LICENSE":
# <aldis@bsdroot.lv> wrote this file. As long as you retain this notice you
# can do whatever you want with this stuff. If we meet some day, and you think
# this stuff is worth it, you can buy me a beer in return Aldis Berjoza

# http://wiki.bsdroot.lv/zfsnap
# http://aldis.git.bsdroot.lv/zfSnap/

VERSION=1.2.1

s2time() {
	# convert seconds to human readable time
	xtime=$*

	years=`expr $xtime / 31536000`
	xtime=`expr $xtime % 31536000`
	[ ${years:-0} -gt 0 ] && years="${years}y" || years=""

	months=`expr $xtime / 2592000`
	xtime=`expr $xtime % 2592000`
	[ ${months:-0} -gt 0 ] && months="${months}m" || months=""

	days=`expr $xtime / 86400`
	xtime=`expr $xtime % 86400`
	[ ${days:-0} -gt 0 ] && days="${days}d" || days=""

	hours=`expr $xtime / 3600`
	xtime=`expr $xtime % 3600`
	[ ${hours:-0} -gt 0 ] && hours="${hours}h" || hours=""

	minutes=`expr $xtime / 60`
	[ ${minutes:-0} -gt 0 ] && minutes="${minutes}M" || minutes=""

	seconds=`expr $xtime % 60`
	[ ${seconds:-0} -gt 0 ] && seconds="${seconds}s" || seconds=""

	echo "${years}${months}${days}${hours}${minutes}${seconds}"
}

time2s() {
	# convert human readable time to seconds
	echo "$1" | sed -e 's/y/*31536000+/' -e 's/m/*2592000+/' -e 's/w/*604800+/' -e 's/d/*86400+/' -e 's/h/*3600+/' -e 's/M/*60+/' -e 's/s//' -e 's/\+$//' | bc -l
}

help() {
	cat << EOF
${0##*/} v${VERSION} by Aldis Berjoza <aldis@bsdroot.lv>

Syntax:
${0##*/} [ generic options ] [[ -a ttl ] [ -r|-R ] z/fs1 ... ] ...

GENERIC OPTIONS:
  -d       = delete old snapshots
  -v       = verbose output
  -n       = show actions that would be performed (don't make/delete snapshots)

OPTIONS:
  -a ttl   = set how long snapshot should be kept
  -r       = create recursive snapshots for all zfs file systems that fallow
             this switch
  -R       = create non-recursive snapshots for all zfs file systems that
             fallow this switch

MORE INFO:
  http://wiki.bsdroot.lv/zfsnap

EOF
	exit
}

[ $# = 0 ] && help
[ "$1" = '-h' -o $1 = "--help" ] && help

tfrmt='%Y-%m-%d_%T'
htime_pattern='([0-9]+y)?([0-9]+m)?([0-9]+w)?([0-9]+d)?([0-9]+h)?([0-9]+M)?([0-9]+[s]?)?'
date_pattern='20[0-9][0-9]-[01][0-9]-[0-3][0-9]_[0-2][0-9]:[0-5][0-9]:[0-5][0-9]'
age='1m'	# default max snapshot age
delete_snapshots=0
verbose=0
dry_run=0

while [ "$1" = '-d' -o "$1" = '-v' -o "$1" = '-n' ]; do
	[ "$1" = "-d" ] && delete_snapshots=1 && shift
	[ "$1" = "-v" ] && verbose=1 && shift
	[ "$1" = "-n" ] && dry_run=1 && shift
done

[ $dry_run -eq 1 ] && zfs_list=`zfs list -H | awk '{print $1}'`
ntime=`date "+$tfrmt"`
while [ "$1" ]; do
	while [ "$1" = '-r' -o "$1" = '-R' -o "$1" = '-a' ]; do
		[ "$1" = '-r' ] && zopt='-r' && shift
		[ "$1" = '-R' ] && zopt='' && shift
		[ "$1" = '-a' ] && age="$2" && shift 2 && echo "$age" | grep -q -E -e "^[0-9]+$" && age=`s2time $age`
	done

	# create snapshots
	if [ $1 ]; then
		zfs_snapshot="zfs snapshot $zopt $1@${ntime}--${age}"
		if [ $dry_run -eq 0 ]; then
			[ $verbose -eq 1 ] && echo -n "zfs snapshot $zopt $1@${ntime}--${age}	... "
			$zfs_snapshot > /dev/stderr \
				&& { [ $verbose -eq 1 ] && echo 'DONE'; } \
				|| { [ $verbose -eq 1 ] && echo 'FAIL'; }
		else
			echo "$zfs_snapshot"
			good_fs=0
			for i in $zfs_list; do
				[ "$i" = "$1" ] && { good_fs=1; break; }
			done
			[ $good_fs -eq 0 ] && echo "ERR: looks like zfs filesystem '$1' doesn't exist" > /dev/stderr
		fi
		shift
	fi
done

rm_snapshots=""
# delete snapshots
if [ "$delete_snapshots" -eq 1 ]; then
	zfs_snapshots=`zfs list -H -t snapshot | awk '{print $1}' | grep -E -e "^.*@${date_pattern}--${htime_pattern}$" | sort -r`
	for i in `printf '%s\n' $zfs_snapshots | sed -e "s/^.*@//" |  sort -u`; do
		dtime=$(time2s `echo $i | sed -E -e "s/^${date_pattern}--//"`)
		[ `expr $(date +%s) - $dtime` -gt $(date -j -f "$tfrmt" $(echo "$i" | sed -E -e "s/--${htime_pattern}$//") +%s) ] && rm_snapshot_pattern="$rm_snapshot_pattern $i"
	done

	if [ "$rm_snapshot_pattern" != '' ]; then
		rm_snapshots=$(printf '%s\n' $zfs_snapshots | grep -E -e `echo $rm_snapshot_pattern | sed -e 's/ /|/g'`)
		while [ "$rm_snapshots" != "" ]; do
			rm_this_snapshot=`echo "$rm_snapshots" | head -n 1`

			zfs_destroy="zfs destroy -r $rm_this_snapshot"
			if [ $dry_run -eq 0 ]; then
				[ $verbose -eq 1 ] && echo -n "zfs destroy $i	... "
				$zfs_destroy > /dev/stderr \
					&& { [ $verbose -eq 1 ] && echo 'DONE'; } \
					|| { [ $verbose -eq 1 ] && echo 'FAIL'; }
			else
				echo "$zfs_destroy"
			fi

			rm_snapshots=$(printf "%s\n" $rm_snapshots | sed -E -e "s#`echo $rm_this_snapshot | sed -e 's#@#(/.+)?@#'`##g" | sort -r -u)
		done
	fi
fi
exit 0
