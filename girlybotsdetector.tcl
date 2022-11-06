# This work is licensed under a Creative Commons Attribution-Share Alike 3.0 License
# http://creativecommons.org/licenses/by-sa/3.0/
# savvas @ Undernet, Freenode
# http://www.hellnetworks.com

# Detects girly bots that crawl on Undernet, kick/ban.
# Note: Ban is deprecated, most of these bots don't rejoin automatically. If the bots rejoin, uncomment (remove the # character) the "newchanban" line.
# Add a channel to protect: .chanset #channel +girlybots

#Kudos to Sanitarium for his great regex string
set girlybotsregex {^(Aldora|Alysia|Amorita|Anita|April|Ara|Aretina|Barbra|Becky|Bella|Bettina|Blenda|Briana|Bridget|Camille|Cara|Carla|Carmen|Chelsea|Chloe|Clarissa|Damita|Danielle|Daria|Diana|Donna|Dora|Doris|Ebony|Eden|Eliza|Emily|Erin|Erika|Eve|Evelyn|Faith|Gale|Gilda|Gloria|Haley|Helga|Holly|Ida|Idona|Iris|Isabel|Ivana|Ivory|Janet|Jewel|Joanna|Julie|Juliet|Kacey|Kali|Kara|Kassia|Katie|Katrina|Kyle|Lara|Laura|Linda|Lisa|Lola|Lolita|Lynn|Maia|Maria|Mary|Meggie|Melody|Milenia|Mimi|Myra|Nadia|Naomi|Natalie|Nicole|Nina|Nora|Nova|Olga|Olivia|Pamela|Peggy|Queen|Rae|Rachel|Raquel|Rita|Rosa|Ruby|Sharon|Silver|Tara|Ula|Uma|Valda|Valora|Vanessa|Vicky|Violet|Vivian|Wendy|Willa|Xandra|Xenia|Xylia|Zenia|Zilya|Zoe)([12][0-9])!~?[A-Za-z]+@}

# Setting flag
setudef flag girlybots

bind join - * girlybotsdetect
proc girlybotsdetect {nick userhost handle channel} {
	if {![channel get $channel girlybots]} {return}
	global botnick girlybotsregex
	regexp "(.+)@(.+)" $userhost matches user host
	if {[regexp $girlybotsregex "$nick!$userhost" match girlyp1 girlyp2]} {
		#newchanban $channel "*!*@$host" $botnick "girlybots: matched $nick!$userhost" 60
		putkick $channel $nick "Predefined spambot nickname"
	}
}

putlog "GirlyBotsDetector 0.9 by savvas - www.hellnetworks.com"
