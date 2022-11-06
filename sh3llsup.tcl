# http://pastebin.ca/raw/675733
# This work is licensed under a Creative Commons Attribution-Share Alike 3.0 License
# http://creativecommons.org/licenses/by-sa/3.0/
# savvas @ Undernet, AfterX, Freenode

# You need need http.tcl, in tcl 8.4 it's in: /usr/lib/tcl8.4/http2.5/http.tcl
# Or get it from here: http://pastebin.ca/raw/675732
# add it in eggdrop.conf, for example: source scripts/http.tcl
package require http

bind pub - "!uptimes" cmd_up

set mchan "##hn"
global sh3llsup
#disabled time in minutes
set disabled_time "1"
set sh3lls {"Eclipse" "Vortex" "Dasher" "Shark" "Orbit" "Astro" "Cortex" "Echo" "Edge" "Grid" "Matrix" "Orion" "Stealth" "Storm" "Viper" "Thunder"}
set sh3llsup "0 0"

proc iget {url} {
	set token [::http::geturl $url -timeout 5000]
	if {[string match "*DOCTYPE*" [::http::data $token]]} {
		set status "error"
		set data "reading data"
	} else {
		set data [::http::data $token]
		set status [::http::status $token]
	}
	::http::cleanup $token
	return "$status $data"
}
proc reset_timer {} {
	global sh3llsup
	set sh3llsup "0 0"
}

proc cmd_up {nick host handle chan txt} {
	global mchan sh3llsup sh3lls disabled_time
	if {$chan != $mchan} {return}
	if {$txt == ""} {
		putquick "PRIVMSG $mchan :Men ise garos, vale je poio server na elegksw, p.x. !uptimes [lrange $sh3lls 0 end]"
		return
	} elseif {$txt != "*"} {
		set sh3lls "$txt"
	}
	if {[lindex $sh3llsup 0] > 0 || [lindex $sh3llsup 1] != 0} {
		putquick "PRIVMSG $mchan :E pomeine re $nick, en j'en siklin. Kartera $disabled_time lepto/a!"
		return
	}
	set timerID [timer $disabled_time reset_timer]
	putquick "PRIVMSG $mchan :Sinaoumente ta info"
	set sh3llsup "1 $timerID"
	set sh3llsskip 0
	foreach i $sh3lls {
		set s [iget "http://[string tolower $i].sh3lls.net/uptime.txt"]
		regexp {up (.+)} $s match r1
		if {[lindex $s 0] == "ok"} {
			putserv "PRIVMSG $mchan : ${i} up: ${r1}"
		} else {
			putserv "PRIVMSG $mchan : ${i} ERROR: $s"
		}
	}
	set sh3lls {"Eclipse" "Vortex" "Dasher" "Shark" "Orbit" "Astro" "Cortex" "Echo" "Edge" "Grid" "Matrix" "Orion" "Stealth" "Storm" "Viper" "Thunder"}
	#putlogdev d * "!uptimes request: ${nick}!$host"
}

putlog "sh3lls.net uptime 0.9 by savvas loaded"

