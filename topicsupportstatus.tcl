# This work is licensed under a Creative Commons Attribution-Share Alike 3.0 License
# http://creativecommons.org/licenses/by-sa/3.0/
# savvas @ Undernet, Freenode
set tsstatuschannel "#hellnetworks"
set tsstatuschannel2 "##hn"

bind pub o "!away" cmd_supportaway
bind pub o "!offline" cmd_supportoffline
bind pub o "!online" cmd_supportonline

bind join m * topicsupportstatuson
bind sign m * topicsupportstatusoff
bind part m * topicsupportstatusoff

proc cmd_supportoffline {nick host handle channel txt} {
	global tsstatuschannel tsstatuschannel2
	if {$tsstatuschannel != $channel && $tsstatuschannel2 != $channel} {return}
	set ctopic [topic $tsstatuschannel]
	if {[regsub {SUPPORT: (?:AWAY|ONLINE)} $ctopic "SUPPORT: OFFLINE" ctopic2]} {
		putserv "TOPIC $tsstatuschannel :$ctopic2"
	}
}
proc cmd_supportonline {nick host handle channel txt} {
	global tsstatuschannel tsstatuschannel2
	if {$tsstatuschannel != $channel && $tsstatuschannel2 != $channel} {return}
	set ctopic [topic $tsstatuschannel]
	if {[regsub {SUPPORT: (?:OFFLINE|AWAY)} $ctopic "SUPPORT: ONLINE" ctopic2]} {
		putserv "TOPIC $tsstatuschannel :$ctopic2"
	}
}
proc cmd_supportaway {nick host handle channel txt} {
	global tsstatuschannel tsstatuschannel2
	if {$tsstatuschannel != $channel && $tsstatuschannel2 != $channel} {return}
	set ctopic [topic $tsstatuschannel]
	if {[regsub {SUPPORT: (?:OFFLINE|ONLINE)} $ctopic "SUPPORT: AWAY" ctopic2]} {
		putserv "TOPIC $tsstatuschannel :$ctopic2"
	}
}


proc topicsupportstatuson {nick uhost handle channel} {
	global tsstatuschannel
	if {$tsstatuschannel != $channel} {return}
	if {$handle == ""} {return}
	set ctopic [topic $tsstatuschannel]
	if {[regsub {SUPPORT: (?:OFFLINE|AWAY)} $ctopic "SUPPORT: AWAY" ctopic2]} {
		putserv "TOPIC $tsstatuschannel :$ctopic2"
	}
}
proc topicsupportstatusoff {nick uhost handle channel {reason ""}} {
	global tsstatuschannel
	if {$tsstatuschannel != $channel} {return}
	if {$handle == ""} {return}
	set ctopic [topic $tsstatuschannel]
	if {[regsub {SUPPORT: (?:ONLINE|AWAY)} $ctopic "SUPPORT: OFFLINE" ctopic2]} {
		putserv "TOPIC $tsstatuschannel :$ctopic2"
	}
}


putlog "Topic Support Status checking by savvas"
