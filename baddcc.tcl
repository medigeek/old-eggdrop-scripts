# This work is licensed under a Creative Commons Attribution-Share Alike 3.0 License
# http://creativecommons.org/licenses/by-sa/3.0/
# savvas @ Undernet, Freenode
# http://www.hellnetworks.com

# Detects advertised channels/links the person with a specific ban lifetime.
# Add a channel to protect: .chanset #channel +baddcc

# PRIVMSG #test :\001DCC SEND testfile 3232235778 1024 137\001

# General Status:
set baddccstatus "on"

# Ignore/Protect operators (+o) and voiced persons (+v)?
set baddccignore "ov"

# Ban time (minutes)
set baddcctime 2

# Ban type
# 0: *!*@host
# 1: *!user@host
# 2: nick!*@host
# 3: nick!user@*
# 4: nick!user@host
set baddccbtype 0

# Don't edit from this point
# --------------------------

# Setting flag
setudef flag baddcc
bind ctcp - "DCC" checkbaddcc

proc checkbaddcc {nick userhost handle {channel ""} keyword text} {
	global baddccstatus baddccignore baddcctime botnick baddccbtype
	if {[string index $channel 0] != "#"} {return}
	if {$baddccstatus == "off" || ![channel get $channel baddcc]} {return}
	if {[isop $nick $channel] && [string match *o* $baddccignore]} {return}
	if {[isvoice $nick $channel] && [string match *v* $baddccignore]} {return}
	if {[matchattr $handle fov|fov $channel]} {return}

	set baddccmask [baddcc_cmdbantype $nick $userhost]
	newchanban $channel $baddccmask $botnick "\[BD\] Public DCC is not allowed - $baddcctime minute(s)" $baddcctime
	putkick $channel $nick "\[BD\] Public DCC is not allowed - $baddcctime minute(s)"
}

proc baddcc_cmdbantype {nick userhost} {
	global baddccbtype
	regexp "(.+)@(.+)" $userhost matches user host
	switch $baddccbtype {
		0 {return "*!*@$host"}
		1 {return "*!$user@$host"}
		2 {return "$nick!*@$host"}
		3 {return "$nick!$user@*"}
		4 {return "$nick!$user@$host"}
		default {return "*!*@$host"}
	}
}

putlog "BadDCC 1.0.1 by savvas - www.hellnetworks.com"
