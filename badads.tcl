# This work is licensed under a Creative Commons Attribution-Share Alike 3.0 License
# http://creativecommons.org/licenses/by-sa/3.0/
# savvas @ Undernet, Freenode
# http://www.hellnetworks.com

# Detects advertised channels/links the person with a specific ban lifetime.
# Add a channel to protect: .chanset #channel +badads

# General Status:
set badsstatus "on"

# Ignore/Protect operators (+o) and voiced persons (+v)?
set badsignore "ov"

# The lists
set badslist {
	"*put_something_here_with_wildcard_only*"
}
set badslistre {
	{(#(?!(?:nicosia|cyprus|larna[ck]a|limassol|pa(?:ph|f)os|omonoia|cy30\+)(?:\040|$))[^\040]+)}
	{((?:join|ela(?:te)?)(?=.*(?:kanali|channel)))}
	{((?:irc|(?:f|ht)tps?)://[^\s]+)}
	{(\y(?:www\d*\.)[^\s]+\.(?:[a-zA-Z]{2}|name|org|info|edu|biz|com|net|pro|gov|mil|aero|int)(?:[:/][^\s]+)?\y)}
	{(\y(?:\d{1,3}\.){3}\d{1,3}(?:[:/][^\s]+)?\y)}
	{(\y[^\s\.\043]{3,}\.(?:[^\s\.]{2,3}\.)?(?:[a-zA-Z]{2}|name|org|info|edu|biz|com|net|pro|gov|mil|aero|int)(?:[:/][^\s]+)?\y)}
}

# Ban time (minutes)
set badstime 2

# Ban type
# 0: *!*@host
# 1: *!user@host
# 2: nick!*@host
# 3: nick!user@*
# 4: nick!user@host
set badsbtype 0

# Don't edit from this point
# --------------------------

# Setting flag
setudef flag badads
bind pubm - * checkbadads

proc checkbadads {nick userhost handle channel text} {
	global badsstatus badsignore badslist badslistre badstime botnick badsbtype
	if {$badsstatus == "off" || ![channel get $channel badads]} {
		return
	}
	if {[isop $nick $channel] && [string match *o* $badsignore]} {
		return
	}
	if {[isvoice $nick $channel] && [string match *v* $badsignore]} {
		return
	}
	if {[matchattr $handle fov|fov $channel]} {
		return
	}

	set bwli 0
	set badsfound 0
	foreach item $badslistre {
		if {[regexp -nocase $item $text badsmatch badssub1]} {
			set badsmask [bads_cmdbantype $nick $userhost]
			newchanban $channel $badsmask $botnick "\[BAre${bwli}\] Advertising is not allowed - $badstime minute(s)" $badstime
			putkick $channel $nick "\[BAre${bwli}\] Advertising is not allowed - $badstime minute(s)"
			set badsfound 1
			break
		}
		incr bwli
	}
	set bwli 0
	#if regex didn't match...
	if {!$badsfound} {
		foreach item $badslist {
			if {[string match $item $text]} {
				set badsmask [bads_cmdbantype $nick $userhost]
				newchanban $channel $badsmask $botnick "\[BAwc${bwli}\] Advertising is not allowed - $badstime minute(s)" $badstime
				putkick $channel $nick "\[BAwc${bwli}\] Advertising is not allowed - $badstime minute(s)"
				break
			}
			incr bwli
		}
	}
}

proc bads_cmdbantype {nick userhost} {
	global badsbtype
	regexp "(.+)@(.+)" $userhost matches user host
	switch $badsbtype {
		0 {return "*!*@$host"}
		1 {return "*!$user@$host"}
		2 {return "$nick!*@$host"}
		3 {return "$nick!$user@*"}
		4 {return "$nick!$user@$host"}
		default {return "*!*@$host"}
	}
}

putlog "BadAdvertising 0.9 (with regular expressions) by savvas - www.hellnetworks.com"
