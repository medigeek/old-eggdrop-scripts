#Copyright (c) 2008 Savvas Radevic

#RANDOM KEY:
# UPDATE `accounts` SET `id` = LEFT(SHA1(UUID()), 10) WHERE 1
#package require Tcl 8.2
#package require uuid
#
#package require sha1
#string toupper [string range [::sha1::sha1 [::uuid::uuid generate]] 0 9]
#package require crc32
#regsub -all {\d} [::crc::crc32 -format %X [::uuid::uuid generate]] ""
#::crc::crc32 -format %X [::uuid::uuid generate]
#

# TODO TODO TODO: group users with a UGID

package require Tcl 8.4
package require mysqltcl
package require uuid
package require crc16

set acctdbcommand "!account"
set accthost "db.savvas.radevic.com"
set acctuser "botuser"
set acctpass "changeme"
set acctdb "hellnetworks"
set accttable "shellaccts"
set acctdbusers "sfakias.users.undernet.org"

set acctoutput "##hn"

set acctviewprivate "0"
set acctviewsshlike "1"
set acctviewloginonly "0"

#DO NOT EDIT BELOW, UNLESS YOU'RE FAMILIAR WITH TCL
bind pub o $acctdbcommand acctdbcmddo

set acctdbdelidlist {}
set acctdbhandle ""

proc acctdbcmddo {nick userhost handle channel text} {
	global acctoutput
	if {$channel != $acctoutput} {
		return
	}
	if {![acctdbusercheck $userhost]} {
		putserv "PRIVMSG $acctoutput :AccountDB: ERROR: You're not allowed to use this."
		return
	}
	switch "[lindex $text 0]" {
		"disconnect" {
			global acctdbhandle
			if {$acctdbhandle == ""} {
				putserv "PRIVMSG $acctoutput :AccountDB: Connection already closed."
				return
			}
			acctdisconnect
			putserv "PRIVMSG $acctoutput :AccountDB: Closed connection to database."
		}
		"connect" {
			global acctdbhandle
			if {$acctdbhandle != ""} {
				putserv "PRIVMSG $acctoutput :AccountDB: Connection already open."
				return
			}
			acctconnect
			putserv "PRIVMSG $acctoutput :AccountDB: Opened connection to database."
		}
		"add" {
			acctconnect
			set acctaddargs "[lrange $text 1 end]"
			if {$acctaddargs != ""} {
				acctinsertdo $acctaddargs
			} else {
				putserv "PRIVMSG $acctoutput :AccountDB: Available ADD commands: add -s server -u username -p password -bncs bncnick1 bncnick2 -bots bot1 bot2 bot3 -client nickname!identd@hostname.com -pmethod 0|1|2|3|4 (0=Unknown, 1=Credit card, 2=Paypal, 3=Bank 4=Other) -plasts 2009-02-18"
			}
		}
		"group" {
			switch -- "[lindex $text 1]" {
				"-generate" {
					putserv "PRIVMSG $acctoutput :AccountDB: TEST: Unique Group ID (UGID) - [acctUIDgenerate]"
				}
				default { putserv "PRIVMSG $acctoutput :AccountDB: group -generate" }
			}
		}
		"show" {
			acctconnect
			acctshowdo $nick "[lindex $text 1]" "[lrange $text 2 end]"
		}
		"search" {
			acctconnect
			acctsearchdo "[lrange $text 1 end]"
		}
		"delete" {
			acctconnect
			acctdeletedo "[lindex $text 1]" "[lrange $text 2 end]"
		}
		"reset" {
			acctconnect
			acctresetdo "[lindex $text 1]" "[lrange $text 2 end]"
		}
		default {
			acctconnect
			putserv "PRIVMSG $acctoutput :AccountDB: Available commands: connect, disconnect, add, add -id, show -id|-info|-overdue, search, delete -id|-yes"
		}
	}
}

#Check if users are allowed to run the commands
proc acctdbusercheck {userhost} {
	global acctdbusers
	regexp {@(.+)} $userhost matches host
	foreach i $acctdbusers {
		if {$i == $host} {return "1"}
	}
	return "0"
}
## Separate values from options
# set value [acctminiargsparser options|values $input]
# null = info::nodata
# error = error::dataoroptions
proc acctminiargsparser {type text} {
	set acctoptstart [lsearch $text -*]
	if {$acctoptstart == 0} {
		return "error::dataoroptions"
	}
	switch $type {
		"options" {
			if {$acctoptstart == "-1"} {
				set acctargopts "info::nodata"
			} else {
				set acctargopts [lrange $text $acctoptstart end]
				return $acctargopts
			}
		}
		"values" {
			if {$acctoptstart == "-1"} {
				set acctargvalues [lrange $text 0 end]
			} else {
				set acctargvalues [lrange $text 0 [expr {$acctoptstart - 1}]]
				set acctargvalues [split $acctargvalues ", "]
				return $acctargvalues
			}
		}
		default {
		}
	}
}
##Separate -minicmds and their params
proc acctparserwparam {indexcmd text} {
	set start [expr {$indexcmd + 1}]
	set ende [lsearch [lrange $text $start end] -*]
	if {$ende == -1} {
		return "[lrange $text $start end]"
	} else {
		incr ende -1
		return "[lrange $text $start [expr {$start+$ende}]]"
	}
}
##Separate search -minicmds, -regex|-regexp and their params
# type is LIKE or REGEXP
proc acctparserwregex {indexcmd text} {
	set start [expr {$indexcmd + 1}]
	if {[regexp {^-regexp$} [lindex $text $start]]} {
		set accttype "REGEXP"
		#jump to the item after -regexp
		incr start 1
	} else {
		set accttype "LIKE"
	}
	set ende [lsearch [lrange $text $start end] -*]
	if {$ende == -1} {
		set acctdata "[lrange $text $start end]"
	} else {
		incr ende -1
		set acctdata "[lrange $text $start [expr {$start+$ende}]]"
	}
	return "$accttype $acctdata"
}

## SEARCH
proc acctsearchdo {text} {
	global acctdbhandle accttable acctoutput
	if {[llength $text] < 1} {
		putserv "PRIVMSG $acctoutput :AccountDB: try search -all \[-regexp\] <string> or search -s|-u|-p|-client|-bots|-bncs|-pmethod|-plasts \[-regexp\] <string>"
		return
	}
	foreach i {allall server user pass bots bncs client pmethod plasts} { set acctinfo$i ""}
	foreach i {server user pass bots bncs client pmethod plasts} { set accttype$i ""}
	set acctargsall {}

	#Parsing search parameters
	set acctargallall [lsearch $text "-all"]
	set acctargalltest [string index "$text" 0]
	if {$acctargalltest != "-" && $acctargallall == -1} {
		#putserv "PRIVMSG $acctoutput :AccountDB: INFO: Not using any parameters, searching -all"
		set acctargalltest "default"
	}
	if {$acctargalltest == "default" || $acctargallall > -1} {
		if {$acctargalltest == "default"} {set acctargallall -1}
		set acctinfoallall [acctparserwregex $acctargallall $text]
		set accttypeallall [lindex $acctinfoallall 0]
		set acctinfoallall [lrange $acctinfoallall 1 end]
		if {[llength $acctinfoallall] != 1} {
			putserv "PRIVMSG $acctoutput :AccountDB: ERROR: search -all takes ONE parameter"
			return
		}
		lappend acctargsall "`server`" "`username`" "`password`" "`bots`" "`bncs`" "`clientwhois`" "`paymentmethod`" "`paymentlasts`"
		foreach i {server user pass bots bncs client pmethod plasts} { set acctinfo$i "$acctinfoallall"}
		foreach i {server user pass bots bncs client pmethod plasts} { set accttype$i "LIKE"}
		if {$acctargalltest == "default"} {set acctargallall 0}
	}

	set acctargserver [lsearch $text "-s"]
	if {$acctargserver > -1} {
		if {$acctargallall > -1} {
			putserv "PRIVMSG $acctoutput :AccountDB: ERROR: search -all cannot be used with other -parameters (except -regexp)"
			return
		}
		set acctinfoserver [acctparserwregex $acctargserver $text]
		set accttypeserver [lindex $acctinfoserver 0]
		set acctinfoserver [lrange $acctinfoserver 1 end]
		if {[llength $acctinfoserver] != 1} {
			putserv "PRIVMSG $acctoutput :AccountDB: ERROR: search -s takes ONE parameter"
			return
		}
		lappend acctargsall "`server`"
	}
	set acctarguser [lsearch $text "-u"]
	if {$acctarguser > -1} {
		if {$acctargallall > -1} {
			putserv "PRIVMSG $acctoutput :AccountDB: ERROR: search -all cannot be used with other -parameters (except -regexp)"
			return
		}
		set acctinfouser [acctparserwregex $acctarguser $text]
		set accttypeuser [lindex $acctinfouser 0]
		set acctinfouser [lrange $acctinfouser 1 end]
		if {[llength $acctinfouser] != 1} {
			putserv "PRIVMSG $acctoutput :AccountDB: ERROR: search -u takes ONE parameter"
			return
		}
		lappend acctargsall "`username`"
	}
	set acctargpass [lsearch $text "-p"]
	if {$acctargpass > -1} {
		if {$acctargallall > -1} {
			putserv "PRIVMSG $acctoutput :AccountDB: ERROR: search -all cannot be used with other -parameters (except -regexp)"
			return
		}
		set acctinfopass [acctparserwregex $acctargpass $text]
		set accttypepass [lindex $acctinfopass 0]
		set acctinfopass [lrange $acctinfopass 1 end]
		if {[llength $acctinfopass] != 1} {
			putserv "PRIVMSG $acctoutput :AccountDB: ERROR: search -p takes ONE parameter"
			return
		}
		lappend acctargsall "`password`"
	}
	set acctargbots [lsearch $text "-bots"]
	if {$acctargbots > -1} {
		if {$acctargallall > -1} {
			putserv "PRIVMSG $acctoutput :AccountDB: ERROR: search -all cannot be used with other -parameters (except -regexp)"
			return
		}
		set acctinfobots [acctparserwregex $acctargbots $text]
		set accttypebots [lindex $acctinfobots 0]
		set acctinfobots [lrange $acctinfobots 1 end]
		if {[llength $acctinfobots] != 1} {
			putserv "PRIVMSG $acctoutput :AccountDB: ERROR: search -p takes ONE parameter"
			return
		}
		lappend acctargsall "`bots`"
	}
	set acctargbncs [lsearch $text "-bncs"]
	if {$acctargbncs > -1} {
		if {$acctargallall > -1} {
			putserv "PRIVMSG $acctoutput :AccountDB: ERROR: search -all cannot be used with other -parameters (except -regexp)"
			return
		}
		set acctinfobncs [acctparserwregex $acctargbncs $text]
		set accttypebncs [lindex $acctinfobncs 0]
		set acctinfobncs [lrange $acctinfobncs 1 end]
		if {[llength $acctinfobncs] != 1} {
			putserv "PRIVMSG $acctoutput :AccountDB: ERROR: search -p takes ONE parameter"
			return
		}
		lappend acctargsall "`bncs`"
	}
	set acctargclient [lsearch $text "-client"]
	if {$acctargclient > -1} {
		if {$acctargallall > -1} {
			putserv "PRIVMSG $acctoutput :AccountDB: ERROR: search -all cannot be used with other -parameters (except -regexp)"
			return
		}
		set acctinfoclient [acctparserwregex $acctargclient $text]
		set accttypeclient [lindex $acctinfoclient 0]
		set acctinfoclient [lrange $acctinfoclient 1 end]
		if {[llength $acctinfoclient] != 1} {
			putserv "PRIVMSG $acctoutput :AccountDB: ERROR: search -client takes ONE parameter"
			return
		}
		lappend acctargsall "`clientwhois`"
	}
	set acctargpmethod [lsearch $text "-pmethod"]
	if {$acctargpmethod > -1} {
		if {$acctargallall > -1} {
			putserv "PRIVMSG $acctoutput :AccountDB: ERROR: either search -all \[-regexp\] <string> or search -s|-u|-p|-bots|-bncs|-client|-pmethod|-plasts \[-regexp\] <string>"
			return
		}
		set acctinfopmethod [acctparserwregex $acctargpmethod $text]
		set accttypepmethod [lindex $acctinfopmethod 0]
		set acctinfopmethod [lrange $acctinfopmethod 1 end]
		if {![regexp {^[0-9]+$} $acctinfopmethod]} {
			putserv "PRIVMSG $acctoutput :AccountDB: ERROR: Use search -pmethod 0|1|2|3|4 - 0=Unknown, 1=Credit card, 2=Paypal, 3=Bank 4=Other"
			return
		}
		if {[llength $acctinfopmethod] != 1} {
			putserv "PRIVMSG $acctoutput :AccountDB: ERROR: search -pmethod takes ONE parameter"
			return
		}
		lappend acctargsall "`paymentmethod`"
	}
	set acctargplasts [lsearch $text "-plasts"]
	if {$acctargplasts > -1} {
		if {$acctargallall > -1} {
			putserv "PRIVMSG $acctoutput :AccountDB: ERROR: search -all cannot be used with other -parameters (except -regexp)"
			return
		}
		set acctinfoplasts [acctparserwregex $acctargplasts $text]
		set accttypeplasts [lindex $acctinfoplasts 0]
		set acctinfoplasts [lrange $acctinfoplasts 1 end]
		if {[llength $acctinfoplasts] != 1} {
			putserv "PRIVMSG $acctoutput :AccountDB: ERROR: search -plasts takes ONE parameter"
			return
		}
		if {[regexp {^[0-9]{4}-[0-9]{2}-[0-9]{2}$} $acctinfoplasts]} {
			lappend acctargsall "`paymentlasts`"
		} else {
			putserv "PRIVMSG $acctoutput :AccountDB: search -plasts requires a date YYYY-MM-DD, e.g. 1492-12-31"
			return
		}
	}
	if {[llength $acctargsall] == 0} {
		putserv "PRIVMSG $acctoutput :AccountDB: ERROR: Something went wrong (-parameters not existing?)"
		return
	}

	#DATA PROCESSING
	#make the string '%%'
	foreach i {server user pass bots bncs client pmethod plasts} { set acctqtype$i ""}
	if {$accttypeserver == "LIKE"} { set acctqtypeserver "%" }
	if {$accttypeuser == "LIKE"} { set acctqtypeuser "%" }
	if {$accttypepass == "LIKE"} { set acctqtypepass "%" }
	if {$accttypebots == "LIKE"} { set acctqtypebots "%" }
	if {$accttypebncs == "LIKE"} { set acctqtypebncs "%" }
	if {$accttypeclient == "LIKE"} { set acctqtypeclient "%" }
	if {$accttypepmethod == "LIKE"} { set acctqtypepmethod "%" }
	if {$accttypeplasts == "LIKE"} { set acctqtypeplasts "%" }
	#change to info
	regsub "`server`" [lrange $acctargsall 0 end] "'$acctqtypeserver$acctinfoserver$acctqtypeserver'" acctinfostr
	regsub "`username`" $acctinfostr "'$acctqtypeuser$acctinfouser$acctqtypeuser'" acctinfostr
	regsub "`password`" $acctinfostr "'$acctqtypepass$acctinfopass$acctqtypepass'" acctinfostr
	regsub "`bots`" $acctinfostr "'$acctqtypebots$acctinfobots$acctqtypebots'" acctinfostr
	regsub "`bncs`" $acctinfostr "'$acctqtypebncs$acctinfobncs$acctqtypebncs'" acctinfostr
	regsub "`clientwhois`" $acctinfostr "'$acctqtypeclient$acctinfoclient$acctqtypeclient'" acctinfostr
	regsub "`paymentmethod`" $acctinfostr "'$acctqtypepmethod$acctinfopmethod$acctqtypepmethod'" acctinfostr
	regsub "`paymentlasts`" $acctinfostr "'$acctqtypeplasts$acctinfoplasts$acctqtypeplasts'" acctinfostr

	set x 0
	foreach i $acctargsall {
		switch $i {
			"`server`" {set acctsearchtype $accttypeserver}
			"`username`" {set acctsearchtype $accttypeuser}
			"`password`" {set acctsearchtype $accttypepass}
			"`bots`" {set acctsearchtype $accttypebots}
			"`bncs`" {set acctsearchtype $accttypebncs}
			"`clientwhois`" {set acctsearchtype $accttypeclient}
			"`paymentmethod`" {set acctsearchtype $accttypepmethod}
			"`paymentlasts`" {set acctsearchtype $accttypeplasts}
		}
		lappend acctsearchstr "$i $acctsearchtype [lindex $acctinfostr $x]"
		putlog " $i $acctsearchtype [lindex $acctinfostr $x] "
		incr x
	}

	if {$acctargallall > -1} {
		#if using -all, use OR
		regsub -all {\}\s\{} [lrange $acctsearchstr 0 end] " OR " acctsearchstr
		regsub -all {\}|\{} [lrange $acctsearchstr 0 end] "" acctsearchstr
	} else {
		#if not using -all, use AND
		regsub -all {\}\s\{} [lrange $acctsearchstr 0 end] " AND " acctsearchstr
		regsub -all {\}|\{} [lrange $acctsearchstr 0 end] "" acctsearchstr
	}

	set acctmysqlsrch [::mysql::sel $acctdbhandle "SELECT `id` FROM `$accttable` WHERE ($acctsearchstr)" -flatlist]
	if {$acctmysqlsrch != ""} {
		putserv "PRIVMSG $acctoutput :AccountDB: Matched accounts with ID: $acctmysqlsrch"
	} else {
		putserv "PRIVMSG $acctoutput :AccountDB: Something went wrong, or no matches."
	}
}
## RESET / ALTER
proc acctresetdo {minicmd miniargs} {
	global acctdbhandle acctoutput accttable
	switch -- $minicmd {
		"-id" {
			set acctcountall [::mysql::sel $acctdbhandle "SELECT COUNT(`id`) FROM `$accttable`" -flatlist]
			set acctreset [::mysql::exec $acctdbhandle "ALTER TABLE `$accttable` DROP `id`"]
			set acctreset2 [::mysql::exec $acctdbhandle "ALTER TABLE `$accttable` ADD `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY FIRST"]
			if {$acctreset == $acctcountall && $acctreset2 == $acctcountall} {
				putserv "PRIVMSG $acctoutput :AccountDB: Successfully reset IDs, $acctreset/$acctcountall accounts affected."
			} else {
				putserv "PRIVMSG $acctoutput :AccountDB: ERROR: Something went wrong. $acctreset/$acctcountall and $acctreset2/$acctcountall affected."
			}
		}
		default {
			putserv "PRIVMSG $acctoutput :AccountDB: Available commands: reset -id"
		}
	}
}
## GROUP UUID UNIQUE ID
proc acctUIDgenerate {} {
	#the letters
	regsub -all {\d} [::crc::crc16 -format %X [::uuid::uuid generate]] "" uuidstamp1
	while {[string length $uuidstamp1] != 3} {
		regsub -all {\d} [::crc::crc16 -format %X [::uuid::uuid generate]] "" uuidstamp1
	}
	#the number
	set uuidstamp2 [::crc::crc16 -format %u [::uuid::uuid generate]]
	while {$uuidstamp2 < 9999} {
		set uuidstamp2 [::crc::crc16 -format %u [::uuid::uuid generate]]
	}
	return "${uuidstamp1}-${uuidstamp2}"
}

## DELETE
proc acctdeletedo {minicmd miniargs} {
	global acctdbhandle acctoutput accttable acctdbdelidlist
	switch -- $minicmd {
		"-id" {
			set acctdelkey [acctUIDgenerate]
			set acctdbdelidlist {}
			lappend acctdbdelidlist $acctdelkey
			set miniargs [split $miniargs ", "]
			if {[llength $miniargs] == 0 || $miniargs == "" || $miniargs == " "} {
				putserv "PRIVMSG $acctoutput :AccountDB: ERROR: delete -id takes numbers only, you haven't entered an ID."
				return
			}
			foreach mid $miniargs {
				if {[regexp {^[0-9]+$} $mid]} {
					lappend acctdbdelidlist $mid
				} else {
					putserv "PRIVMSG $acctoutput :AccountDB: ERROR: delete -id takes numbers only, invalid ID $mid"
					set acctdbdelidlist {}
					return
				}
			}
			putserv "PRIVMSG $acctoutput :AccountDB: To delete the IDs ([lrange $acctdbdelidlist 1 end]) use: delete -yes $acctdelkey"
		}
		"-yes" {
			if {$acctdbdelidlist == ""} {
				putserv "PRIVMSG $acctoutput :AccountDB: ERROR: Please use the delete -id first."
				return
			}
			if {[lindex $miniargs 0] == "" || [lindex $miniargs 0] != [lindex $acctdbdelidlist 0]} {
				putserv "PRIVMSG $acctoutput :AccountDB: ERROR: Wrong or no delete key."
				set acctdelkey [acctUIDgenerate]
				lset acctdbdelidlist 0 $acctdelkey
				putserv "PRIVMSG $acctoutput :AccountDB: To delete the IDs ([lrange $acctdbdelidlist 1 end]) use: delete -yes $acctdelkey"
				return
			}
			#Continue
			set acctdbid [lrange $acctdbdelidlist 1 end]
			regsub -all {\s} $acctdbid "," acctdbidlist
			set acctmysqlexec [::mysql::exec $acctdbhandle "DELETE FROM `$accttable` WHERE `id` IN ($acctdbidlist) LIMIT [llength $acctdbid]"]
			if {$acctmysqlexec == [llength $acctdbid]} {
				putserv "PRIVMSG $acctoutput :AccountDB: Deleted $acctmysqlexec/[llength $acctdbid] account(s)."
			} else {
				putserv "PRIVMSG $acctoutput :AccountDB: $acctmysqlexec/[llength $acctdbid] accounts affected - Maybe the other IDs don't exist?"
			}
			set acctdbdelidlist {}
		}
		default {
			putserv "PRIVMSG $acctoutput :AccountDB: try delete -id|-yes"
		}
	}
}

## SHOW
proc acctshowdo {nick minicmd miniargs} {
	global acctdbhandle acctoutput accttable
	switch -- $minicmd {
		"-id" {
			set miniopts [acctminiargsparser "options" $miniargs]
			if {$miniopts == "error::dataoroptions"} {
				putserv "PRIVMSG $acctoutput :AccountDB: ERROR: No data/values provided OR put options at the end (after data)."
				return
			}
			set miniargs [acctminiargsparser "values" $miniargs]
			foreach miniargsid $miniargs {
				if {![regexp {^[0-9]+$} $miniargsid]} {
					putserv "PRIVMSG $acctoutput :AccountDB: ERROR: delete -id takes numeric index only."
					return
				}
			}
			foreach i {private sshlike loginonly} {set acctmod$i 0}
			if {$miniopts == "info::nodata"} {
				global acctviewprivate acctviewsshlike acctviewloginonly
				set acctmodprivate $acctviewprivate
				set acctmodsshlike $acctviewsshlike
				set acctmodloginonly $acctviewloginonly
			} else {
				set acctoptprivate [lsearch $miniopts "-private"]
				if {$acctoptprivate > -1} {set acctmodprivate 1}
				set acctoptsshlike [lsearch $miniopts "-sshlike"]
				if {$acctoptsshlike > -1} {set acctmodsshlike 1}
				set acctoptloginonly [lsearch $miniopts "-loginonly"]
				if {$acctoptloginonly > -1} {set acctmodloginonly 1}
			}
			lappend acctoptsall $acctmodprivate $acctmodsshlike $acctmodloginonly

			if {[llength $miniargs] == 1} {
				if {[regexp {^[0-9]+$} $miniargs]} {
					acctquerydo $nick "oneline" "-flatlist" $acctoptsall "SELECT * FROM `$accttable` WHERE `id` = $miniargs"
				} else {
					putserv "PRIVMSG $acctoutput :AccountDB: show -id takes numeric index only, e.g. show -id 1,2,3 or show -id 1 2 3"
					return
				}
			} else {
				if {[regexp {^([0-9]+\s?)+$} "$miniargs"]} {
					regsub -all {\s} $miniargs "," miniidlist
					acctquerydo $nick "multiline" "-list" $acctoptsall "SELECT * FROM `$accttable` WHERE `id` IN ($miniidlist)"
				} else {
					putserv "PRIVMSG $acctoutput :AccountDB: show -id takes numeric index only, e.g. show -id 1,2,3 or show -id 1 2 3"
					return
				}
			}
		}
		"-info" {
			set acctmysqlsel [::mysql::sel $acctdbhandle "SELECT COUNT(`id`) FROM `$accttable`" -flatlist]
			set acctmysqllast [::mysql::sel $acctdbhandle "SELECT `id` FROM `$accttable` ORDER BY `$accttable`.`id` DESC LIMIT 1" -flatlist]
			putserv "PRIVMSG $acctoutput :AccountDB: Accounts: $acctmysqlsel Last account ID: $acctmysqllast"
		}
		"-overdue" {
			set curdatestr [clock format [clock seconds] -format "%Y-%m" -gmt 1]
			set curdate [clock format [clock seconds] -format "%Y-%m-%d" -gmt 1]
			set acctmysqloverdue [::mysql::sel $acctdbhandle "SELECT `id`,`paymentlasts` FROM `$accttable` WHERE (DATEDIFF(`paymentlasts`,'$curdate') < 32 AND `paymentlasts` != '0000-00-00') ORDER BY `paymentlasts` ASC" -list]
			set acctmysqlsel [::mysql::sel $acctdbhandle "SELECT COUNT(`id`) FROM `$accttable`" -flatlist]
			#{93 2008-02-03}
			regsub -all {([0-9]+\s[0-9]{4}-[0-9]{2}-[0-9]{2})} "[lrange $acctmysqloverdue 0 end]" "#\\1," acctinfooverdue
			#Fix the last comma
			regsub -all {,\}$|\{|\}} $acctinfooverdue "" acctinfooverdue
			putserv "PRIVMSG $acctoutput :AccountDB: Overdue accounts (+ 31 days in advance) [llength $acctmysqloverdue]/$acctmysqlsel: $acctinfooverdue"
		}
		default {
			putserv "PRIVMSG $acctoutput :AccountDB: Unknown command, try show -id, show -info, show -search, show -overdue"
		}
	}
}
proc acctquerydo {nick type options viewopts query} {
	global acctdbhandle acctoutput
	if {$type == "oneline"} {
	#ONE LINE PROCESSING
		set acctinfofull [::mysql::sel $acctdbhandle $query $options]
		if {$acctinfofull == ""} {
			putserv "PRIVMSG $acctoutput :AccountDB: ERROR: No matches found."
			return
		}
		acctqueryreport $nick $viewopts $acctinfofull
	} elseif {$type == "multiline"} {
	#MULTILINE PROCESSING
		set acctinfolist [::mysql::sel $acctdbhandle $query $options]
		foreach row $acctinfolist {
			if {$row == ""} {
				putserv "PRIVMSG $acctoutput :AccountDB: ERROR: No matches found."
				return
			}
			acctqueryreport $nick $viewopts $row
}
	} else {
		putserv "PRIVMSG $acctoutput :AccountDB: Unknown query type."
		return
	}
}
proc acctqueryreport {nick options acctinfofull} {
	global acctdbhandle acctoutput
	set acctinfoindex "[lindex $acctinfofull 0]"
	set acctinfoserver "[lindex $acctinfofull 1]"
	set acctinfouser "[lindex $acctinfofull 2]"
	set acctinfopass "[lindex $acctinfofull 3]"
	set acctinfobotlist "[lindex $acctinfofull 4]"
	regsub -all {,} $acctinfobotlist " " acctinfobotlist
	set acctinfobnclist "[lindex $acctinfofull 5]"
	regsub -all {,} $acctinfobnclist " " acctinfobnclist
	set acctinfoclwhois "[lindex $acctinfofull 6]"
	if {"[lindex $acctinfofull 8]" == "0000-00-00"} {set acctinfoplasts "N/A"} else {set acctinfoplasts "[lindex $acctinfofull 8]"}
	switch "[lindex $acctinfofull 7]" {
		1 {set acctinfopmethod "Credit card"}
		2 {set acctinfopmethod "Paypal"}
		3 {set acctinfopmethod "Bank"}
		4 {set acctinfopmethod "Other"}
		default {set acctinfopmethod "N/A"}
	}

	set viewprivate [lindex $options 0]
	set viewsshlike [lindex $options 1]
	set viewloginonly [lindex $options 2]
	if {$viewprivate} {set acctoutdest $nick} else {set acctoutdest $acctoutput}
	putserv "PRIVMSG $acctoutdest :AccountDB: Account ID #$acctinfoindex"
	if {$viewsshlike} {
		putserv "PRIVMSG $acctoutdest :   Login: ssh ${acctinfouser}@${acctinfoserver} Password: $acctinfopass"
	} else {
		putserv "PRIVMSG $acctoutdest :   Server: $acctinfoserver Username: $acctinfouser Password: $acctinfopass"
	}
	if {!$viewloginonly} {
		putserv "PRIVMSG $acctoutdest :   Bots([llength $acctinfobotlist]): [lrange $acctinfobotlist 0 end] BNCs([llength $acctinfobnclist]): [lrange $acctinfobnclist 0 end]"
		putserv "PRIVMSG $acctoutdest :   Client: $acctinfoclwhois"
		putserv "PRIVMSG $acctoutdest :   Paid through: $acctinfopmethod Payment lasts until: $acctinfoplasts"
	}
}

## INSERT/ADD CHANGE/UPDATE
proc acctinsertdo {text} {
	global acctdbhandle acctoutput accttable acctdb
	set acctargsall {}
	set acctargsallcount [llength $text]
	foreach i {ids server user pass bots bncs client pmethod plasts} { set acctinfo$i ""}

	#UPDATE OR INSERT?
	set acctargids [lsearch $text "-id"]
	if {$acctargids == -1} {set acctaddtype "INSERT"} else {
		set acctargidstart [expr {$acctargids + 1}]
		set acctargidsend [lsearch [lrange $text $acctargidstart end] -*]
		#ID list separated by , or space
		if {$acctargidsend == -1} {
			set acctinfoids [split [lrange $text $acctargidstart end] ", "]
		} else {
			incr acctargidsend -1
			set acctinfoids [split [lrange $text $acctargidstart [expr {$acctargidstart+$acctargidsend}]] ", "]
		}
		if {$acctinfoids == ""} {
			putserv "PRIVMSG $acctoutput :AccountDB: ERROR: Use add -id 1,2,3,4 or add -id 1 2 3 4"
			return
		}
		set acctinfoidsno [llength $acctinfoids]
		regsub -all {\s} "[lrange $acctinfoids 0 end]" "," acctinfoids
		set acctaddtype "UPDATE"
	}

	set acctargserver [lsearch $text "-s"]
	if {$acctargserver > -1} {
		set acctinfoserver [acctparserwparam $acctargserver $text]
		if {[llength $acctinfoserver] != 1} {
			putserv "PRIVMSG $acctoutput :AccountDB: ERROR: add -s takes ONE parameter"
			return
		}
		lappend acctargsall "`server`"
	} else {
		if {$acctargids == -1} {
			putserv "PRIVMSG $acctoutput :AccountDB: ERROR: Please add -s the.server.com -u username"
			return
		}
	}
	set acctarguser [lsearch $text "-u"]
	if {$acctarguser > -1} {
		set acctinfouser [acctparserwparam $acctarguser $text]
		if {[llength $acctinfouser] != 1} {
			putserv "PRIVMSG $acctoutput :AccountDB: ERROR: add -u takes ONE parameter"
			return
		}
		lappend acctargsall "`username`"
	} else {
		if {$acctargids == -1} {
			putserv "PRIVMSG $acctoutput :AccountDB: ERROR: Please add -s the.server.com -u username"
		return
		}
	}
	set acctargpass [lsearch $text "-p"]
	if {$acctargpass > -1} {
		set acctinfopass [acctparserwparam $acctargpass $text]
		if {[llength $acctinfopass] != 1} {
			putserv "PRIVMSG $acctoutput :AccountDB: ERROR: add -p takes ONE parameter"
			return
		}
		lappend acctargsall "`password`"
	}
	set acctargbots [lsearch $text "-bots"]
	if {$acctargbots > -1} {
		set acctargbotstart [expr {$acctargbots + 1}]
		set acctargbotsend [lsearch [lrange $text $acctargbotstart end] -*]
		#ID list separated by , or space
		if {$acctargbotsend == -1} {
			set acctinfobots [split [lrange $text $acctargbotstart end] ", "]
		} else {
			incr acctargbotsend -1
			set acctinfobots [split [lrange $text $acctargbotstart [expr {$acctargbotstart+$acctargbotsend}]] ", "]
		}
		regsub -all {\s} "[lrange $acctinfobots 0 end]" "," acctinfobots
		lappend acctargsall "`bots`"
	}
	set acctargbncs [lsearch $text "-bncs"]
	if {$acctargbncs > -1} {
		set acctargbncstart [expr {$acctargbncs + 1}]
		set acctargbncsend [lsearch [lrange $text $acctargbncstart end] -*]
		#ID list separated by , or space
		if {$acctargbncsend == -1} {
			set acctinfobncs [split [lrange $text $acctargbncstart end] ", "]
		} else {
			incr acctargbncsend -1
			set acctinfobncs [split [lrange $text $acctargbncstart [expr {$acctargbncstart+$acctargbncsend}]] ", "]
		}
		regsub -all {\s} "[lrange $acctinfobncs 0 end]" "," acctinfobncs
		lappend acctargsall "`bncs`"
	}
	set acctargclient [lsearch $text "-client"]
	if {$acctargclient > -1} {
		set acctinfoclient [acctparserwparam $acctargclient $text]
		if {[llength $acctinfoclient] != 1} {
			putserv "PRIVMSG $acctoutput :AccountDB: ERROR: add -client takes ONE parameter"
			return
		}
		lappend acctargsall "`clientwhois`"
	}
	set acctargpmethod [lsearch $text "-pmethod"]
	if {$acctargpmethod > -1} {
		set acctinfopmethod [acctparserwparam $acctargpmethod $text]
		if {![regexp {^[0-9]+$} $acctinfopmethod]} {
			putserv "PRIVMSG $acctoutput :AccountDB: ERROR: Use add -pmethod 0|1|2|3|4 - 0=Unknown, 1=Credit card, 2=Paypal, 3=Bank 4=Other"
			return
		}
		if {[llength $acctinfopmethod] != 1} {
			putserv "PRIVMSG $acctoutput :AccountDB: ERROR: add -pmethod takes ONE parameter"
			return
		}
		lappend acctargsall "`paymentmethod`"
	}
	set acctargplasts [lsearch $text "-plasts"]
	if {$acctargplasts > -1} {
		set acctinfoplasts [acctparserwparam $acctargplasts $text]
		if {[llength $acctinfoplasts] != 1} {
			putserv "PRIVMSG $acctoutput :AccountDB: ERROR: add -plasts takes ONE parameter"
			return
		}
		if {[regexp {^[0-9]{4}-[0-9]{2}-[0-9]{2}$} $acctinfoplasts]} {
			lappend acctargsall "`paymentlasts`"
		} else {
			putserv "PRIVMSG $acctoutput :AccountDB: add -plasts requires a date YYYY-MM-DD, e.g. 1492-12-31"
			return
		}
	}
	#DATA PROCESSING
	#change to info
	regsub "`server`" [lrange $acctargsall 0 end] "'$acctinfoserver'" acctinfostr
	regsub "`username`" $acctinfostr "'$acctinfouser'" acctinfostr
	regsub "`password`" $acctinfostr "'$acctinfopass'" acctinfostr
	regsub "`bots`" $acctinfostr "'$acctinfobots'" acctinfostr
	regsub "`bncs`" $acctinfostr "'$acctinfobncs'" acctinfostr
	regsub "`clientwhois`" $acctinfostr "'$acctinfoclient'" acctinfostr
	regsub "`paymentmethod`" $acctinfostr "'$acctinfopmethod'" acctinfostr
	regsub "`paymentlasts`" $acctinfostr "'$acctinfoplasts'" acctinfostr

	#-id? UPDATE or INSERT?
	if {$acctaddtype == "INSERT"} {
		#replace empty spaces with a comma
		regsub -all {\s} "[lrange $acctargsall 0 end]" "," acctargsstr
		regsub -all {\s} "$acctinfostr" "," acctinfostr
		set acctmysqlexec [::mysql::exec $acctdbhandle "INSERT INTO `$acctdb`.`$accttable` ($acctargsstr) VALUES ($acctinfostr)"]
		#putlog "::sql::INSERT INTO `$acctdb`.`$accttable` ($acctargsstr) VALUES ($acctinfostr)"
	} elseif {$acctaddtype == "UPDATE"} {
		set x 0
		foreach i $acctargsall {
			lappend acctupdatestr "$i=[lindex $acctinfostr $x]"
			incr x
		}
		regsub -all {\s} $acctupdatestr "," acctupdatestr
		#putlog "::sql::UPDATE `$acctdb`.`$accttable` SET $acctupdatestr WHERE `id` IN ($acctinfoids) LIMIT $acctinfoidsno"
		set acctmysqlexec [::mysql::exec $acctdbhandle "UPDATE `$acctdb`.`$accttable` SET $acctupdatestr WHERE `id` IN ($acctinfoids) LIMIT $acctinfoidsno"]
	}
	if {$acctmysqlexec == "1" && $acctaddtype == "INSERT"} {
		#set acctmysqllast [::mysql::sel $acctdbhandle "SELECT `id` FROM `$accttable` ORDER BY `$accttable`.`id` DESC LIMIT 1" -flatlist]
		set acctmysqllast [::mysql::insertid $acctdbhandle]
		putserv "PRIVMSG $acctoutput :AccountDB: Successfully added $acctinfouser@$acctinfoserver account ID #$acctmysqllast"
	} elseif {$acctmysqlexec > 0 && $acctaddtype == "UPDATE"} {
		putserv "PRIVMSG $acctoutput :AccountDB: Successfully changed IDs ($acctinfoids): $acctupdatestr"
	} else {
		putserv "PRIVMSG $acctoutput :AccountDB: ERROR: Something went wrong. MySQL replied: $acctmysqlexec rows affected."
	}
	#Commands:	-s		-u		-p		-bots		-bncs		-client		-pmethod	-plasts
	#Fields:	`server`	`username`	`password`	`bots`		`bncs`		`clientwhois`	`paymentmethod`	`paymentlasts`
	#acctargsall	acctargserver	acctarguser	acctargpass	acctargbots	acctargbncs	acctargclient	acctargpmethod	acctargplasts
	#Information:	acctinfoserver	acctinfouser	acctinfopass	acctinfobots	acctinfobncs	acctinfoclient	acctinfopmethod	acctinfoplasts
	#Additional:	-id,`id`,acctargids,acctinfoids
}

proc acctdisconnect {} {
	global acctdbhandle
	::mysql::close $acctdbhandle
	set acctdbhandle ""
}
proc acctconnect {} {
	global acctdbhandle accthost acctuser acctpass acctdb acctoutput
	if {$acctdbhandle != ""} {
		set acctdbactive [::mysql::ping $acctdbhandle]
		if {$acctdbactive} {
			#putserv "PRIVMSG $acctoutput :AccountDB: Reconnecting to the database."
		} else {
			putserv "PRIVMSG $acctoutput :AccountDB: ERROR: Could not reconnect to the database. Try again later."
			set acctdbhandle ""
			return
		}
	} else {
		if {[catch {set acctdbhandle [::mysql::connect -host $accthost -user $acctuser -password $acctpass -db $acctdb -encoding "utf-8"]} errmsg]} {
			putserv "PRIVMSG $acctoutput :AccountDB: Could not connect to the database. Try again later."
			return
		} else {
			putserv "PRIVMSG $acctoutput :AccountDB: Established connection to the database."
		}
	}
}


putlog "AccountDB by savvas loaded"
