#!/bin/bash

rootdir=/var/chroot
users="zhuqf"

function createDir() {
	mkdir $rootdir
	cd $rootdir
	mkdir {bin,dev,lib,lib64,etc,home}
	mknod dev/null c 1 3
	mknod dev/zero c 1 5

	mknod dev/random c 1 8
	mknod dev/urandom c 1 9
	mknod dev/tty c 5 0
	chown -R root.root $rootdir
	chmod -R 755 $rootdir
	chmod 0666 dev/{null,zero,tty}
}

function copyExcutable() {
#	files=`ldd /bin/bash | awk -F[=\>] '{print $1 $2 $3}' | awk '{if($3=="") {print $1} else {print $2} }'`

	commands="/bin/bash /bin/ls /bin/cp /bin/mkdir /bin/mv /bin/rm /bin/rmdir"
	libs1=`ldd $commands | awk '{ print $1 }' | grep "/lib" | sort | uniq`
	libs2=`ldd $commands | awk '{ print $3 }' | grep "/lib" | sort | uniq`


	for i in $commands; do
		echo "cp -af $i $rootdir/$i" 
		cp -pf $i $rootdir/$i
	done

	for i in $libs1; do
		echo "cp -af $i $rootdir/$i"
		cp -pf $i $rootdir/$i
	done

	for i in $libs2; do
		echo "cp -af $i $rootdir/$i"
		cp -pf $i $rootdir/$i
	done

}

function createChrootUser() {
	for u in $users; do
		cat >>/etc/ssh/sshd_config<<EOF
Match User $u
	ChrootDirectory $rootdir
EOF
		cp -r /etc/skel /var/chroot/home/$u
		chown -R $u /var/chroot/home/$u
		chmod -R 700 /var/chroot/home/$u
	done
	/etc/init.d/sshd restart
}

function syncPassword() {
	files="/etc/group /etc/passwd"
	users="root $users"
	for f in $files; do
		rm -f $rootdir$f
		touch $rootdir$f
		for u in $users; do
			grep "^$u" $f >> $rootdir$f
		done
	done
}

#usercheck=`groups zhuqf zhuqf | grep "No such user"`
#if [ ! $usercheck == "" ]; then 
#	echo "you need create the account(s) $users first"
#	exit()
#fi
(createDir)
(copyExcutable)
(createChrootUser)
(syncPassword)

