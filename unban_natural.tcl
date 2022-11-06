# This work is licensed under a Creative Commons Attribution-Share Alike 3.0 License
# http://creativecommons.org/licenses/by-sa/3.0/
# savvas @ Undernet, Freenode

bind mode - * chkunban

#cmd_blist is an advanced banmatcher, checks for global/channel bans and removes at match.
proc cmd_blist {channel victim} {
  set gblist {}
  set cblist {}
  #set the lists
  foreach i [banlist] {
    lappend gblist "[lindex $i 0]"
  }
  foreach i [banlist "$channel"] {
    lappend cblist "[lindex $i 0]"
  }
  set gblist2 $gblist
  set cblist2 $cblist
  #search the lists, victim is the pattern
  #global ban
  while {[lsearch $gblist $victim] >= 0} {
    set banindex [lsearch $gblist $victim]
    set gbanstatus killban [lindex $gblist $banindex]
    set gblist [lrange $gblist [incr $banindex] end]
  }
  #channel ban
  while {[lsearch $cblist $victim] >= 0} {
    set banindex [lsearch $cblist $victim]
    set cbanstatus killchanban $channel [lindex $cblist $banindex]
    set cblist [lrange $cblist [incr $banindex] end]
  }
  #to do: search the lists, banmask the pattern
  #foreach x gblist ... string match ?
  foreach x $gblist2 {
    if {[string match $x $victim] >= 0} {
      killban [string match $x $victim]
    }
  }
  foreach z $cblist2 {
    if {[string match $z $victim] >= 0} {
      killchanban $channel [string match $z $victim]
    }
  }
}

proc chkunban {nick uhost handle channel modechange victim} {
  if {![isop $nick $channel]} {
    return
  }
  if {$modechange == "-b"} {
    #cmd_blist $channel $victim
    #putlog "Unbannatural -- ${nick}!$uhost attempted ban removal $channel $victim"
    #old way, check if bans *!*user@host
    if {[matchban $victim $channel]} {
      set ub1 [killchanban $channel $victim]
      set ub2 [killban $victim]
      #1 = success, 0 = fail or not available
      putloglev d * "Unbannatural $channel $victim -- chanban: $ub1 global-ban: $ub2"
    }
  }
}

putlog "Unban_natural checking by savvas"
