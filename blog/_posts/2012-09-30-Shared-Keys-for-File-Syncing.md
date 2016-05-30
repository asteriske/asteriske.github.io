---
layout: post_blog
---

I do my work on a few different machines at once, and in order to keep things reasonably sane I like to sync my client machines back to my share hosted on the department server. I do this with some simple rsync scripts, and to facilitate the connection I use shared SSH keys. For one reason or another I find myself recreating these a few times a year, and so to find the instructions I post them here. (Thanks to [Debian Administration] (http://www.debian-administration.org/articles/530) from whom I draw the info.)

I write this to connect my Debian/Ubuntu VMs to OS X Server, I suspect it will work for any \*NIX-to-\*NIX link.

On the local machine, generate keys

	mccarthy@StatsVM:~$ ssh-keygen
	Generating public/private rsa key pair.
	Enter file in which to save the key (/home/mccarthy/.ssh/id_rsa): 
	Enter passphrase (empty for no passphrase): 
	Enter same passphrase again: 
	Your identification has been saved in /home/mccarthy/.ssh/id_rsa.
	Your public key has been saved in /home/mccarthy/.ssh/id_rsa.pub.
	The key fingerprint is:
	11:a3:4d:11:22:56:c8:07:41:2c:91:13:b6:e5:10:ce mccarthy@StatsVM
	The key's randomart image is:
	+--[ RSA 2048]----+
	|  *OB=o *o       |
	| ++*+..= o       |
	|  Eo... o        |
	|         .       |
	|        S        |
	|                 |
	|                 |
	|                 |
	|                 |
	+-----------------+

There's a tradeoff here&ndash; for an automatic connection the passphrase should be set to blank ('enter' when prompted), however if someone obtains the key they then can connect as you do. A passphrase that only you know obviates the problem, but then the connection can't be unattended.

SSH typically comes with a utility called `ssh-copy-id` which adds the contents of the `id_rsa.pub` file you just generated to `~/.ssh/authorized_keys` on the server.

	mccarthy@StatsVM:~$ ssh-copy-id -i .ssh/id_rsa.pub pmccarthy@myfiles.stat.ucla.edu
	The authenticity of host 'myfiles.stat.ucla.edu (128.97.55.245)' can't be established.
	RSA key fingerprint is 36:69:9c:59:d5:16:a1:b0:da:21:2d:b1:50:34:4e:ed.
	Are you sure you want to continue connecting (yes/no)? yes
	Warning: Permanently added 'myfiles.stat.ucla.edu,128.97.55.245' (RSA) to the list of known hosts.
	Password:
	Now try logging into the machine, with "ssh 'pmccarthy@myfiles.stat.ucla.edu'", and check in:

	  ~/.ssh/authorized_keys

	to make sure we haven't added extra keys that you weren't expecting.

And so we test as it says: 

	mccarthy@StatsVM:~$ ssh pmccarthy@myfiles.stat.ucla.edu
	Last login: Wed Sep 26 22:48:18 2012 from 76.89.183.15
	[myfiles:~] pmccarthy% 

Success!

This will pave the way for my file-syncing script.
