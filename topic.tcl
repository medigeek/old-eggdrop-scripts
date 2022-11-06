## Set your channel here, this supports only one channel.
set topictrchan1 ""
set topictrchan2 "#hellnetworks"
set topictr1 ""
set topictr2 ""

########################################################
## DO NOT EDIT BELOW UNLESS YOU KNOW WHAT YOU'RE DOING##
########################################################
## BINDS
bind topc - * topictrsave

proc topictrsave {tpnick uhost hand channel topic} {
	global topictr1 topictr2 topictrchan1 topictrchan2
	if {$channel != $topictrchan1 && $channel != $topictrchan2} {return}	if {$channel == $topictrchan1} {set topictr1 "$topic"}
	if {$channel == $topictrchan2} {set topictr2 "$topic"}
}

bind time - "00 * * * *" everytwelvehours
proc everysixhours {m h d mo y} {
	if {[expr {$h % 12}] != 0} {return}
	global topictr1 topictr2 topictrchan1 topictrchan2
	if {$topictr1 != "" && $topictrchan1 != ""} {
		putserv "TOPIC $topictrchan1 :Resynching ..."
		putserv "TOPIC $topictrchan1 :$topictr1"
	}
	if {$topictr2 != "" && $topictrchan2 != ""} {
		putserv "TOPIC $topictrchan2 :Resynching ..."
		putserv "TOPIC $topictrchan2 :$topictr2"
	}
}

putlog "Topic by Shodane modified by iamdeath, remodified by savvas."
