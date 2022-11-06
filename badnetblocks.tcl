# Check bad netblocks (CIDR netmasks) against a user's IP address
# by savvas @ Undernet,Freenode - hellnetworks.com

# This work is licensed under CC-BY-SA: http://creativecommons.org/licenses/by-sa/3.0/
# This script is powered by IPDENY.COM IP database: http://www.ipdeny.com/ipblocks/
# This script requires tcllib (ip) and http
package require ip
package require Tcl 8.4
package require http

## TODO TODO TODO
#- allow to disable/enable .cy tld detection/match IPs only
#- allow to ignore nick!user@hostname


# Usage: .chanset #channel +badnetblocks
# Commands:
#   !bnb refresh (Refreshes the bad netblock list)
#   !bnb download tr (Downloads the turkey netblock list and refreshes the list)
#   !bnb remove ro (Removes the romanian netblock list and refreshes the list)

# SETTINGS - PLEASE EDIT
# You have to provide the site where it will download the files from and its suffix.
# If you would like to use a custom list:
#  - the filename must be lowercase
#  - the format of the filename should be, i.e. for Turkey tr.zone, for Greece gr.zone etc...
#  - the list should contain one netblock per line
# HINT: You can use your own custom list in zz.zone or xx.zone file
set bnblocks(zonesite) "http://www.ipdeny.com/ipblocks/data/countries/"
set bnblocks(zonefsuf) ".zone"

# Directory for zone files, from where the files downloaded or loaded
set bnblocks(dir) "scripts/badsuit/"

# Command prefix
set bnblocks(cmd) "!bnb"
# Backchannel, for commands
set bnblocks(chan) "##hn"

# Set the waiting time (in seconds) before downloading / updating 
# Warning! Don't set it too low, or you could get banned!
# Default: 10 seconds
set bnblocks(wait) "10"

# This setting allows you to enable (1) or disable (0) the detection of the tld ending in a hostname
# For example if john!moo@becker.co.uk joins, and you have the uk.zone file loaded,
# it will automatically detect the .uk suffix and match it without using dns lookup.
# Default is 1 (enabled), since this speeds up the detection
set bnblocks(tldhost) 1

# This is your list of ignored nick!user@host masks
# The script will bypass any mentioned masks
# Accepted wildcards: * (many characters) and ? (one character)
set bnblocks(ignhosts) {
	"*!*@*.users.undernet.org"
}


# DO NOT EDIT from this point on
# Fix trailing / character
set bnblocks(zonesite) [string trimright $bnblocks(zonesite) "/"]
set bnblocks(dir) [string trimright $bnblocks(dir) "/"]

# Timer-related
set bnblocks(disabledl) 0

#add our channel flag
setudef flag badnetblocks

#clear badnetblocks list
set bnblocks(list) {}
set bnblocks(zonetlds) {}

###### UPDATE ######
proc iget {url} {
	set token [::http::geturl $url]
	set d [::http::data $token]
	::http::cleanup $token
	return $d
}
# reset timer / enable download command
proc bnbresettimer {} {
	global bnblocks
	set bnblocks(disabledl) 0
}

#bnbupdatevar #channel
#bnbupdatevar log for putlog output
proc bnbupdatevar {channel} {
	global bnblocks
	set bnblocks(list) {}
	set bzonefiles [glob -nocomplain -directory "$bnblocks(dir)" "*.zone"]
	regsub -all {\.zone} "[glob -nocomplain -directory $bnblocks(dir) -tails *.zone]" "" bnblocks(zonetlds)
	if {$bzonefiles == ""} {
		if {$channel != "log"} {
			putserv "PRIVMSG $channel :Couldn't find any zone files, list currently holds 0 bad netblocks."
		} else {
			putlog "badnetblocks: couldn't find any zone files, list currently holds 0 bad netblocks."
		}
		return
	}
	foreach f $bzonefiles {
		#grab country tld from filename
		regexp {/([a-zA-Z]{2})\.zone} $f matches filetld
		set bzfID [open $f r]
		while {[gets $bzfID bzfline] >= 0} {
			if {$bzfline != ""} {lappend bnblocks(list) "$bzfline:$filetld"}
		}
		close $bzfID
	}
	if {$channel != "log"} {
		putserv "PRIVMSG $channel :Found [llength $bzonefiles] *.zone files, list currently holds [llength $bnblocks(list)] bad netblocks."
	} else {
		putlog "badnetblocks: found [llength $bzonefiles] *.zone files, list currently holds [llength $bnblocks(list)] bad netblocks."
	}
}
#bnbupdate "tr"
proc bnbupdate {filename channel} {
	global bnblocks
	if {$bnblocks(disabledl) == 1} {
		putquick "PRIVMSG $channel :BNB Please wait $bnblocks(wait) second(s)"
		putquick "PRIVMSG $channel :Consider going to the website $bnblocks(zonesite) and downloading all the zone files you require. Be sure to put them in the directory $bnblocks(dir)"
		return
	}
	set timerID [utimer $bnblocks(wait) bnbresettimer]
	set bnblocks(disabledl) 1
	global bnblocks
	set badfileID [open "$bnblocks(dir)/$filename.zone" w+ 0644]
	set badzonedata [iget "$bnblocks(zonesite)/$filename$bnblocks(zonefsuf)"]
	puts $badfileID "$badzonedata"
	close $badfileID
	putserv "PRIVMSG $channel :BNB Downloaded $filename$bnblocks(zonefsuf)"
	bnbupdatevar $channel
}

#bnbremove "uk"
proc bnbremove {filename channel} {
	global bnblocks
	file delete "$bnblocks(dir)/$filename$bnblocks(zonefsuf)"
	putserv "PRIVMSG $channel :BNB Removed $filename$bnblocks(zonefsuf)"
	bnbupdatevar $channel
}

###### COMMAND ######
bind pub o $bnblocks(cmd) bnetblocks_cmd
proc bnetblocks_cmd {nick uhost handle channel text} {
	global bnblocks
	if {$channel != $bnblocks(chan)} {return}
	if {![matchattr $handle o|o $channel]} {return}
	switch [lindex $text 0] {
		"refresh" {
			bnbupdatevar $channel
		}
		"download" {
			if {[regexp {^([a-zA-Z]{2})$} [lindex $text 1] matches tld]} {
				bnbupdate $tld $channel
			}
		}
		"remove" {
			if {[regexp {^([a-zA-Z]{2})$} [lindex $text 1] matches tld]} {
				bnbremove $tld $channel
			}
		}
		default {
			putserv "PRIVMSG $channel :!bnb refresh|download|remove"
		}
	}
}


###### ON JOIN ######
bind join - * bnetblocks_join
proc bnetblocks_join {nick uhost handle channel} {
  global bnblocks
  #check if flag +badnetblocks
  if {![channel get $channel badnetblocks]} {return}
  #don't apply to friends, voices, ops
  if {[matchattr $handle fov|fov $channel]} {return}
  if {[isop $nick $channel]} {return}
  if {[isvoice $nick $channel]} {return}

  #get the actual host
  regexp "(.+)@(.+)" $uhost matches newuser newhost

  #ignore hosts
  foreach ignhost $bnblocks(ignhosts) {
    if {[string match $ignhost "$nick!$uhost"]} {return}
  }

  if {[regexp {[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}$} $newhost]} {
    # it's a numeric (ip) host, skip dns lookup, do cidrmatch
    cidrmatch $newhost $channel $nick $newuser $newhost
  } elseif {[regexp {\.([A-Za-z]{2})$} $newhost matches tld]} {
    # the hostname is a two-letter-ending tld domain, check against the list of tlds
    # cached by the filenames using bnbupdatevar
    bnetblocks_checktld $tld $channel $nick $newuser $newhost
  } else {
    putloglev d * "badnetblocks: doing dns lookup on $newhost to get IP"
    dnslookup $newhost bnetblocks_dns $channel $nick $newuser $newhost
  }
}

proc bnetblocks_dns {ip host status channel nick newuser newhost} {
  if {$status} {
    putloglev d * "badnetblocks: $host resolves to $ip"
    # do cidrmatch
    cidrmatch $ip $channel $nick $newuser $newhost
  } else {
    putloglev d * "badnetblocks: couldn't resolve $host - no further actions taken."
  }
}

# cidripcheck 192.168.0.0/16 10.0.0.2
proc cidripcheck {netmask ip} {
	set mask [ip::mask $netmask]
	if {$mask != ""} {set prefix [ip::prefix $ip/$mask]} else {set prefix $ip}
	string equal [ip::prefix $netmask] $prefix
}
# cidrmatch
proc cidrmatch {ip channel nick user host} {
	global bnblocks
	foreach item $bnblocks(list) {
		#separate country tld from ip netblock
		regexp {^(.+):(.+)$} $item matches iblock itld
		if {[cidripcheck $iblock $ip]} {
			putserv "PRIVMSG $bnblocks(chan) :BNB $channel $nick!$user@$host matched bad netblock $iblock tld $itld"
			#newchanban?
			#kick him?
			break
		}
	}
}
# bnetblocks_checktld cy #greece 1-1-1-1.cytanet.com.cy
proc bnetblocks_checktld {tld channel nick user host} {
	global bnblocks
	foreach x $bnblocks(zonetlds) {
		if {$tld == $x} {
			putserv "PRIVMSG $bnblocks(chan) :BNB $channel $nick!$user@$host matched bad tld $x"
			#newchanban?
			#kick him?
			break
		}
	}
}

putlog "BadNetblocks 0.96 (using ipdeny.com netblock db) by savvas"
# Refresh the netblock list
bnbupdatevar log
