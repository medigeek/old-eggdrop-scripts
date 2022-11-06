# This work is licensed under a Creative Commons Attribution-Share Alike 3.0 License
# http://creativecommons.org/licenses/by-sa/3.0/
# savvas @ Undernet, Freenode
# http://www.hellnetworks.com

# Detects bad words/swearing and bans/kicks the person with a specific ban lifetime.
# Add a channel to protect: .chanset #channel +badwords

# General Status:
set bwordsstatus "on"

# Ignore/Protect operators (+o) and voiced persons (+v)?
set bwordsignore "ov"

# The lists
set bwordslist {
	"*putsomethinghere*"
}
set bwordslistre {
	{(\ygam(?:[hi][aesow]|[wo](?!u?s\y)))}
	{(\ypo?uts[aoe])}
	{(\ykavl[aioe])}
	{(\yar[hx]idia?)}
	{(\yp[o0]?utan)}
	{(\yvill?[aoi])}
	{(vill?[aoi](?:us)?\y)}
	{(po?utt?[oia](?!ut))}
	{(\yskat[aoi])}
	{(\ymo?[uy]nn?i\y)}
	{(\yassh[o0]le\y)}
	{(\yb[1i]tch\y)}
	{(\ydic?khead\y)}
	{(\ysh[1i]thead\y)}
	{(\yfag(?:get)?s?\y)}
	{(\yf[ua]c?k(?:er)?s?\y)}
	{(\ysuc?k(?:er)?s?\y)}
	{(\ygam[ih](?:th|8)[oweih]\y)}
	{(\yk[0o]ts[1i]r(?:[0oi]|a(?!s\y)))}
	{(\ypipp?a)}
	{(\yfamo?u\s?t[ao])}
	{(\yk[ow]lo)}
	{(\ypenis\y)}
	{(\ygay\y)}
	{(\yrape\y)}
	{(\ybadwa\y)}
	{(\yphudi\y)}
	{(\yfudi\y)}
	{(\ylun\y)}
	{(\ygand(?:u|oo)\y)}
	{(\ypussy\y)}
	{(\yboobs\y)}
	{(\ychood\y)}
	{(\ysux\y)}
	{(\ybastard\y)}
	{(\ycock\y)}
	{(\ycunt\y)}
	{(\yommak\y)}
	{(\yshit\y)}
	{(\ypus?sy\y)}
	{(\ywhore\y)}
	{(\yslut\y)}

}

# Ban time (minutes)
set bwordstime 2

# Ban type
# 0: *!*@host
# 1: *!user@host
# 2: nick!*@host
# 3: nick!user@*
# 4: nick!user@host
set bwordsbtype 0

# Don't edit from this point
# --------------------------

# Setting flag
setudef flag badwords
bind pubm - * checkbadwords

proc checkbadwords {nick userhost handle channel text} {
	global bwordsstatus bwordsignore bwordslist bwordslistre bwordstime botnick bwordsbtype
	if {$bwordsstatus == "off" || ![channel get $channel badwords]} {
		return
	}
	if {[isop $nick $channel] && [string match *o* $bwordsignore]} {
		return
	}
	if {[isvoice $nick $channel] && [string match *v* $bwordsignore]} {
		return
	}
	if {[matchattr $handle fov|fov $channel]} {
		return
	}

	set bwli 0
	set bwordsfound 0
	foreach item $bwordslistre {
		if {[regexp -nocase $item $text bwordsmatch bwordssub1]} {
			set bwordsmask [bwords_cmdbantype $nick $userhost]
			newchanban $channel $bwordsmask $botnick "\[BWre${bwli}\] Swearing is not allowed - $bwordstime minute(s)" $bwordstime
			putkick $channel $nick "\[BWre${bwli}\] Swearing is not allowed - $bwordstime minute(s)"
			set bwordsfound 1
			break
		}
		incr bwli
	}
	set bwli 0
	#if regex didn't match...
	if {!$bwordsfound} {
		foreach item $bwordslist {
			if {[string match $item $text]} {
				set bwordsmask [bwords_cmdbantype $nick $userhost]
				newchanban $channel $bwordsmask $botnick "\[BWwc${bwli}\] Swearing is not allowed - $bwordstime minute(s)" $bwordstime
				putkick $channel $nick "\[BWwc${bwli}\] Swearing is not allowed - $bwordstime minute(s)"
				break
			}
			incr bwli
		}
	}
}

proc bwords_cmdbantype {nick userhost} {
	global bwordsbtype
	regexp "(.+)@(.+)" $userhost matches user host
	switch $bwordsbtype {
		0 {return "*!*@$host"}
		1 {return "*!$user@$host"}
		2 {return "$nick!*@$host"}
		3 {return "$nick!$user@*"}
		4 {return "$nick!$user@$host"}
		default {return "*!*@$host"}
	}
}

#sectomin $baddcctime
#proc sectomin {seconds} {
#	set mins [expr {$seconds / 60}]
#	set secs [expr {$seconds % 60}]
#	set data1 ""
#	set data2 ""
#	set mintxtpl "mins"
#	set mintxt "min"
#	set sectxtpl "secs"
#	set sectxt "sec"
#	if {$secs == 0} {
#		if {$mins == 1} then {set data1 $mintxt} elseif {$mins > 1} then {set data1 $mintxtpl}
#		return "$mins$data1"
#	} else {
#		if {$mins == 0} {set mins ""} elseif {$mins == 1} then {set data1 $mintxt} elseif {$mins > 1} then {set data1 $mintxtpl}
#		if {$secs == 1} then {set data2 $sectxt} elseif {$secs > 1} then {set data2 $sectxtpl}
#		return "$mins$data1$secs$data2"
#	}
#}

putlog "BadWords 0.9 (with regular expressions) by savvas - www.hellnetworks.com"
