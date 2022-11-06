# common ban list bot for eggdrop
# (c) savvas @ Undernet,AfterX,Freenode,Nightstar
# version 1.0

# The idea of the script is to put the bot in a lot of channels similar (i.e. geographically,topic etc.) to yours
# and stop the spam from being repeated/spread in your channel.
#
# *** NOTE: Ignored from checking: channel's +o or +v, bot's +f
#
# Example: If you want to protect #london, and you see the spammer joins #uk and spams there first, you:
# 1) .+chan #uk
# 2) .+chan #london
# 3) .chanset #uk +commonban
# 4) .chanset #london +commonban
# *** NOTE: You actually don't need this step, but if you're going to protect other channels as well, it's good to have :)
# 5) .chansave
#
# The script catches spam and outputs it in a channel (set in commonban_chan) as follows:
# a) CHANNEL MESSAGE:
#    nick!user@host MSG!#uk regex_0 caught: #example - join #example join #example
# *** NOTE: regex_0 <-- returns the number of the regex string in commonban_relist (0 is the first)
# *** NOTE: - join #example join #example <-- after the - follows the full text.
# 
# b) PRIVATE MESSAGE:
#    nick!user@host MSG regex_0 caught: #example - join #example join #example
# *** NOTE: In private events there's no !#channel.
#
# c) NOTICE: NOTCCHANOP
#    - Private: nick!user@host NOTC regex_0 caught: #example - join #example join #example
#    - Channel: nick!user@host NOTCCHAN!#uk item_3 caught: www.example.com - www.example.com :D join and register!
#    - Channel Operator: nick!user@host NOTCCHANOP!#uk regex_0 caught: #example - join #example join #example
#
# You can fully protect your channel by adding a ban command directly,
# or by scripting/coding in your client to catch the damn text line :)
# For irssi client using trigger.pl script, this is a quick example for Undernet:
# /trigger a -publics -masks 'CBAN*!*@CBAN.users.undernet.org' -channels 'Undernet/#commonban_chan' -nocase -regexp '^\S*!\S*@(\S*)\s(MSG|NOTC\S*)!(#\S+)\s(\S+)\s(\S+\s\S+)' -command '^msg X ban #london *!*@$1 1 75 $2:$4 - This is a NO SPAM channel. Go away.'

# Channel commands:
# I've added !cban as a command:
#   !cban on - Enables the commonban (on channel events) check
#   !cban off - Disables the commonban (on channel events) check
#   !cban channels - Outputs the channels with/without commonban
#   !cban cycle [all|#channel1[,#channel2[,#channel3]]] - Cycle (Part/Join channels)
#   !cban - Gives status and the current list of regex strings

# Released under the GPL

## Set these variables:
# time in minutes to ban for
set commonban_bantime 30

# The channel to output the matching text
set commonban_chan "##hn"

# This status applies for the default on channel events (!cban on or !cban off),
# If it's "on" here, and you do .rehash, the script will be activated.
set commonban_status "on"

# Should it keep a log? (on/off) - Log filename
set commonban_log "on"
set commonban_log_file "logs/commonban_script.log"

# The regex list for matching
# \043 = #, \040 = space
set commonban_relistc {
  {(#(?!(?:nicosia|cyprus|larna[ck]a|lemesos|limassol|pa(?:ph|f)os|omonoia|cy30\+)(?:\040|$))[^\040]+)}
  {((?:join|ela(?:te)?)(?=.*(?:kanali|channel)))}
}
set commonban_relist {
  {((?:irc|(?:f|ht)tps?)://[^\040]+)}
  {(?:^|\040)((?:www\d*\.)[^\040]+\.(?:[a-zA-Z]{2}|name|org|info|edu|biz|com|net|pro|gov|mil|aero|int)(?:[:/][^\040]+)?)(?:\040|$)}
  {(?:^|\040)((?:[0-9]{1,3}\.){3}[0-9]{1,3}(?:[:/][^\040]+)?)(?:\040|$)}
  {(?:^|\040)([^\040\.\043]{3,}\.(?:[^\040\.]{2,3}\.)?(?:[a-zA-Z]{2}|name|org|info|edu|biz|com|net|pro|gov|mil|aero|int)(?:[:/][^\040]+)?)(?:\040|$)}
}

## Code - Don't edit if you don't know what you're doing
#check the text
bind pubm - * commonban_check
bind msgm - * commonban_privmsg_check
bind notc - * commonban_notc_check
#bind sign - * commonban_quitmsg_check
#bind part - * commonban_partmsg_check
bind pub o "!cban" commonban_cmd_cban
#notification of ban/kick
#matchban <nick!user@host> [channel]
#botnick botname
bind kick - * commonban_reportk

#setting our flag
setudef flag commonban

################
#KICK REPORT   #
################
proc commonban_reportk { nick host handle channel target reason } {
  if {![channel get $channel commonban]} {
    return
  }
  if {![isbotnick $target]} {
    return
  }
  global commonban_chan
  putmsg $commonban_chan "CBAN-KICKED by $nick!$host $channel $reason" 
}

################
#PUBLIC MESSAGE#
################
proc commonban_check { nick host handle channel text } {
  #check if flag +commonban
  if {![channel get $channel commonban]} {
    return
  }

  #don't apply to friends, voices, ops
  if {[matchattr $handle fov|fov $channel]} {
    return
  }
  if {[isop $nick $channel]} {
    return
  }
  if {[isvoice $nick $channel]} {
    return
  }

  #and the journey begins...
  global commonban_relist
  global commonban_chan

  set commonban_i 0
  foreach item $commonban_relist {
    set commonban_result [regexp -nocase "$item" $text commonban_match commonban_sub1]
    regexp ".+@(.+)" $host matches commonban_host
    if {$commonban_result} {
      set commonban_date [clock format [clock seconds] -gmt 1 -format {%d-%b-%Y %H:%M:%SGMT}]
      putmsg $commonban_chan "CBAN $commonban_date $nick!$host MSG!$channel regex_$commonban_i"
      putmsg $commonban_chan "CBAN-MSG $text"
      commonban_append_log "$commonban_date $nick!$host MSG!$channel regex_$commonban_i caught: $commonban_sub1" "$text"
      #newchanban $channel "*!*@$commonban_host" "item_$commonban_i" "banned for: $commonban_sub1"
      #stop the processing, we don't need two matches if there is one already ;)
      break
    }
    incr commonban_i
  }
}

#################
#PRIVATE MESSAGE#
#################
proc commonban_privmsg_check { nick host handle text } {
  #and the second journey begins...
  global commonban_relist
  global commonban_chan
  set commonban_i 0
  foreach item $commonban_relist {
    set commonban_result [regexp -nocase "$item" $text commonban_match commonban_sub1]
    if {$commonban_result} {
      set commonban_date [clock format [clock seconds] -gmt 1 -format {%d-%b-%Y %H:%M:%SGMT}]
      putmsg $commonban_chan "CBAN $commonban_date $nick!$host MSG!PRIVATE regex_$commonban_i"
      putmsg $commonban_chan "CBAN-MSG $text"
      commonban_append_log "$commonban_date $nick!$host MSG!PRIVATE regex_$commonban_i caught: $commonban_sub1" "$text"
      #stop the processing, we don't need two matches if there is one already ;)
      break
    }
    incr commonban_i
  }
}

##############
#QUIT MESSAGE#
##############
proc commonban_quitmsg_check { nick host handle channel text } {
  #check if flag +commonban
  if {![channel get $channel commonban]} {
    return
  }

  #don't apply to friends, voices, ops
  if {[matchattr $handle fov|fov $channel]} {
    return
  }
  if {[isop $nick $channel]} {
    return
  }
  if {[isvoice $nick $channel]} {
    return
  }

  #and the journey begins...
  global commonban_relist
  global commonban_chan

  set commonban_i 0
  foreach item $commonban_relist {
    set commonban_result [regexp -nocase "$item" $text commonban_match commonban_sub1]
    regexp ".+@(.+)" $host matches commonban_host
    if {$commonban_result} {
      set commonban_quittext_pos [lsearch $text "Quit:"]
      if {$commonban_quittext_pos == 0} {
        set text [lreplace $text $commonban_quittext_pos $commonban_quittext_pos]
      }
      set commonban_date [clock format [clock seconds] -gmt 1 -format {%d-%b-%Y %H:%M:%SGMT}]
      putmsg $commonban_chan "CBAN $commonban_date $nick!$host QUIT!$channel regex_$commonban_i"
      putmsg $commonban_chan "CBAN-MSG $text"
      commonban_append_log "$commonban_date $nick!$host QUIT!$channel regex_$commonban_i caught: $commonban_sub1" "$text"
      #stop the processing, we don't need two matches if there is one already ;)
      break
    }
    incr commonban_i
  }
}

##############
#PART MESSAGE#
##############
proc commonban_partmsg_check { nick host handle channel text } {
  #check if flag +commonban
  if {![channel get $channel commonban]} {
    return
  }

  #don't apply to friends, voices, ops
  if {[matchattr $handle fov|fov $channel]} {
    return
  }
  if {[isop $nick $channel]} {
    return
  }
  if {[isvoice $nick $channel]} {
    return
  }

  #and the journey begins...
  global commonban_relist
  global commonban_chan

  set commonban_i 0
  foreach item $commonban_relist {
    set commonban_result [regexp -nocase "$item" $text commonban_match commonban_sub1]
    regexp ".+@(.+)" $host matches commonban_host
    if {$commonban_result} {
      set commonban_date [clock format [clock seconds] -gmt 1 -format {%d-%b-%Y %H:%M:%SGMT}]
      putmsg $commonban_chan "CBAN $commonban_date $nick!$host PART!$channel regex_$commonban_i"
      putmsg $commonban_chan "CBAN-MSG $text"
      commonban_append_log "$commonban_date $nick!$host PART!$channel regex_$commonban_i caught: $commonban_sub1" "$text"
      #stop the processing, we don't need two matches if there is one already ;)
      break
    }
    incr commonban_i
  }
}

########################
#CHANNEL/PRIVATE NOTICE#
########################
proc commonban_notc_check { nick host handle text dest } {
  #ignore mr. X
  if {"$nick!$host" == "X!cservice@undernet.org"} {
    return
  }

  #check if the dest is a channel, and if it has flag +commonban
  set commonban_bechan [string trimleft $dest "@"]
  set commonban_ischan [string index $commonban_bechan 0]
  if {$commonban_ischan == "#"} {
    if {![channel get $commonban_bechan commonban]} {
      return
    }
    if {[matchattr $handle fov|fov $commonban_bechan]} {
      return
    }
    if {[isop $nick $commonban_bechan]} {
      return
    }
    if {[isvoice $nick $commonban_bechan]} {
      return
    }
  }

  #and the third journey begins as well!
  switch [string index $dest 0] {
    "@" {
      set dest [string trimleft $dest "@"]
      set text [lrange $text 1 end]
      commonban_typenotc_check $nick $host "NOTCCHANOP" $dest $text
    }
    "#" {
      commonban_typenotc_check $nick $host "NOTCCHAN" $dest $text
    }
    default {
      commonban_typenotc_check $nick $host "NOTC" $dest $text
    }
  }
}
proc commonban_typenotc_check { nick host type dest text  } {
  global commonban_relist
  global commonban_chan
  set commonban_i 0
  foreach item $commonban_relist {
    set commonban_result [regexp -nocase "$item" $text commonban_match commonban_sub1]
    if {$commonban_result} {
      set commonban_date [clock format [clock seconds] -gmt 1 -format {%d-%b-%Y %H:%M:%SGMT}]
      #if it's a private notice:
      if {$type == "NOTC"} {
      putmsg $commonban_chan "CBAN $commonban_date $nick!$host $type regex_$commonban_i"
      putmsg $commonban_chan "CBAN-MSG $text"
      commonban_append_log "$commonban_date $nick!$host $type regex_$commonban_i caught: $commonban_sub1" "$text"
      } else {
      #or else (if it's a op/normal channel notice):
      putmsg $commonban_chan "CBAN $commonban_date $nick!$host $type!$dest regex_$commonban_i"
      putmsg $commonban_chan "CBAN-MSG $text"
      commonban_append_log "$commonban_date $nick!$host $type!$dest regex_$commonban_i caught: $commonban_sub1" "$text"
      }
      #stop the processing, we don't need two matches if there is one already ;)
      break
    }
    incr commonban_i
  }
}



#######################
#!cban command control#
#######################
proc commonban_cmd_cban { nick host handle channel text } {
  global commonban_chan
  if { $channel == $commonban_chan } {
    global commonban_status
    switch [lindex $text 0] {
      "on" {
        #enable
        set commonban_status "on"
        putmsg $commonban_chan "COMMONBAN Status (on channel events) is now: ON"
      }
      "off" {
        #disable
        set commonban_status "off"
        putmsg $commonban_chan "COMMONBAN Status (on channel events) is now: OFF"
      }
      "log" {
        global commonban_log commonban_log_file
        switch [lindex $text 1] {
          "on" {
            set commonban_log "on"
            putmsg $commonban_chan "COMMONBAN Log status is now: ON"
          }
          "off" {
            set commonban_log "off"
            putmsg $commonban_chan "COMMONBAN Log status is now: OFF"
          }
          "clear" {
            set commonban_logID [open $commonban_log_file w 0644]
            close $commonban_logID
            putmsg $commonban_chan "COMMONBAN Log cleared"
          }
        }
      }
      "add" {
        set commonban_cadd [lindex $text 1]
        set commonban_ischan [string index $commonban_cadd 0]
        if {$commonban_ischan != "#"} {
          putmsg $commonban_chan "COMMONBAN add error: need # in front of the channel name ;)"
          return
        }
        set commonban_clist [split $commonban_cadd ","]
        set commonban_clist_no {}
        set commonban_clist_yes {}
        foreach item $commonban_clist {
          if {[lsearch [channels] $item] >= 0 && ![channel get $item commonban]} {
            channel set $item +commonban
            lappend commonban_clist_yes $item
          } elseif {[lsearch [channels] $item] < 0}  {
            channel add $item +commonban
            lappend commonban_clist_yes $item
          } else {
            lappend commonban_clist_no $item
          }
        }
        if {[llength $commonban_clist_yes] > 0} {
          putmsg $commonban_chan "COMMONBAN add completed for: [lrange $commonban_clist_yes 0 end]"
        }
        if {[llength $commonban_clist_no] > 0} {
          putmsg $commonban_chan "COMMONBAN add error: already added with +commonban flag: [lrange $commonban_clist_no 0 end]"
        }
      }
      "remove" {
        if {[lindex $text 1] == "-r"} {
          set commonban_cremall 1
          set commonban_crem [lindex $text 2]
        } else {
          set commonban_cremall 0
          set commonban_crem [lindex $text 1]
        }
        set commonban_ischan [string index $commonban_crem 0]
        if {$commonban_ischan != "#"} {
          putmsg $commonban_chan "COMMONBAN remove error: need # in front of the channel name ;)"
          return
        }
        set commonban_clist [split $commonban_crem ","]
        set commonban_clist_no {}
        set commonban_clist_yes {}
        foreach item $commonban_clist {
          if {[lsearch [channels] $item] >= 0 && [channel get $item commonban] && $commonban_cremall == 0} {
            channel set $item -commonban
            lappend commonban_clist_yes $item
          } elseif {[lsearch [channels] $item] >= 0 && $commonban_cremall == 1}  {
            channel remove $item
            lappend commonban_clist_yes $item
          } else {
            lappend commonban_clist_no $item
          }
        }
        if {[llength $commonban_clist_no] > 0} {
          putmsg $commonban_chan "COMMONBAN remove error: already not existing: [lrange $commonban_clist_no 0 end]"
        }
        if {[llength $commonban_clist_yes] > 0} {
          putmsg $commonban_chan "COMMONBAN remove completed for: [lrange $commonban_clist_yes 0 end]"
        }
      }
      "channels" {
        #show channel info
        set commonban_clist [channels]
        #remove commonban main channel
        set commonban_chan_pos [lsearch $commonban_clist $commonban_chan]
        set commonban_clist [lreplace $commonban_clist $commonban_chan_pos $commonban_chan_pos]

        set commonban_clist_yes {}
        set commonban_clist_no {}
        set commonban_clist_in {}
        set commonban_clist_out {}
        foreach item $commonban_clist {
          if {[channel get $item commonban]} {
            lappend commonban_clist_yes $item
          } else {
            lappend commonban_clist_no $item
          }
          if {[botonchan $item]} {
            lappend commonban_clist_in $item
          } else {
            lappend commonban_clist_out $item
          }
        }
        lsort $commonban_clist_in
        lsort $commonban_clist_out
        lsort $commonban_clist_yes
        lsort $commonban_clist_no
        putmsg $commonban_chan "COMMONBAN Channels:"
        if {[llength $commonban_clist_in] > 0} {
        putmsg $commonban_chan "[llength $commonban_clist_in]/[llength $commonban_clist] on channel(s): [lrange $commonban_clist_in 0 end]"
        }
        if {[llength $commonban_clist_out] > 0} {
        putmsg $commonban_chan "[llength $commonban_clist_out]/[llength $commonban_clist] not on channel(s): [lrange $commonban_clist_out 0 end]"
        }
        if {[llength $commonban_clist_yes] > 0} {
        putmsg $commonban_chan "[llength $commonban_clist_yes]/[llength $commonban_clist] +commonban: [lrange $commonban_clist_yes 0 end]"
        }
        if {[llength $commonban_clist_no] > 0} {
        putmsg $commonban_chan "[llength $commonban_clist_no]/[llength $commonban_clist] -commonban: [lrange $commonban_clist_no 0 end]"
        }
      }
      "cycle" {
        #cycle channel(s)
        set commonban_ccycle [lindex $text 1]
        set commonban_ischan [string index $commonban_ccycle 0]
        if {$commonban_ccycle == "all"} {
          #will attempt to cycle all channels, but only the ones with +commonban will go through
          set commonban_clist [channels]
        } else {
          if {$commonban_ischan != "#"} {
            putmsg $commonban_chan "COMMONBAN cycle error: need # in front of the channel name ;)"
            return
          }
          set commonban_clist [split $commonban_ccycle ","]
        }
        #remove commonban main channel
        set commonban_chan_pos [lsearch $commonban_clist $commonban_chan]
        set commonban_clist [lreplace $commonban_clist $commonban_chan_pos $commonban_chan_pos]

        set commonban_ccycle_yes {}
        set commonban_ccycle_no {}
        set commonban_ccycle_noton {}
        foreach item $commonban_clist {
          if {[lsearch [channels] $item] >= 0 && [channel get $item commonban]} {
              #only the ones with +commonban will be cycled
              lappend commonban_ccycle_yes $item
          } else {
            lappend commonban_ccycle_no $item
          }
        }
        lsort commonban_ccycle_yes
        lsort commonban_ccycle_no
        #putmsg $commonban_chan "COMMONBAN cycle initiated for: [lrange $commonban_ccycle_yes 0 end]"
        if {[llength $commonban_ccycle_no] > 0} {
          putmsg $commonban_chan "COMMONBAN cycle error: no +commonban flag for: [lrange $commonban_ccycle_no 0 end]"
        }
        if {[llength $commonban_ccycle_yes] > 0} {
          foreach item $commonban_ccycle_yes {
            if {[botonchan $item]} {
              putserv "PART $item :moo cow"
            } else {
              lappend commonban_ccycle_noton $item
            }
            putserv "JOIN $item"
          }
          if {[llength $commonban_ccycle_noton] > 0} {
            putmsg $commonban_chan "COMMONBAN cycle error: not on channel(s): [lrange $commonban_ccycle_noton 0 end]"
          }
          putmsg $commonban_chan "COMMONBAN cycle completed for: [lrange $commonban_ccycle_yes 0 end]"
        }
      }
      "" {
        global commonban_relist
        putmsg $commonban_chan "COMMONBAN Status (on channel events) is [string toupper $commonban_status] - Current lists: [lrange $commonban_relist 0 end]"
      }
    }
  }
}

##############
#     LOG    #
##############

proc commonban_append_log {line1 line2} {
  global commonban_log commonban_log_file
  if {$commonban_log != "on"} {
    return
  }
  set fileID [open $commonban_log_file a+ 0644]
  puts $fileID "$line1"
  puts $fileID "$line2"
  close $fileID
}

putlog "commonban 1.1 by savvas loaded"
