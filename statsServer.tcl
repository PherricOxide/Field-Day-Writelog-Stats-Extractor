package require twapi
package require Tk

set asciiExportPath {C:/engineering/fieldDayStatsTool/asciiDump.txt}
set writelogProcessName {WriteL32.exe}

set labelTheme [list -relief raised -width 8 -font {-family {MS Sans Serif Bold} -size 12}]

proc GetBand frequency {
    if {$frequency >= 1.8 && $frequency <= 2.0} {
        return "160"
    } elseif {$frequency >= 3.5 && $frequency <= 4.0} {
        return "80"
    } elseif {$frequency >= 7.0 && $frequency <= 7.3} {
        return "40"
    } elseif {$frequency >= 14.0 && $frequency <= 14.35} {
        return "20"
    } elseif {$frequency >= 21.0 && $frequency <= 21.45} {
        return "15"
    } elseif {$frequency >= 28.0 && $frequency <= 29.7} {
        return "10"
    } elseif {$frequency >= 50.0 && $frequency <= 54.0} {
        return "6"
    } elseif {$frequency >= 144.0 && $frequency <= 148.0} {
        return "2"
    } else {
        return "0"
    }
}

proc ExportAscii {} {
    set processId [twapi::get_process_ids -name $::writelogProcessName]

    if {[llength $processId] != 1} {
        logit "ERROR: Unable to find process ID for write log! Leaving export"
        return -1
    }

    set windowHandle [twapi::find_windows -pids $processId -toplevel true -visible true]
    if {[llength $windowHandle] != 1} {
        logit "ERROR: Unable to find window handle for writelog! Leaving export"
        return -1
    }
    set windowHandle [lindex $windowHandle 0]
    
    
    file delete -force $::asciiExportPath

    # Pull up the writelog window
    twapi::maximize_window $windowHandle
    twapi::set_foreground_window $windowHandle
    after 500
   
    # Make sure ctrl + a is set as writelog shortcut for FileExportASCIICommaDelimited
    twapi::send_keys "^a"
    after 500

    # Type in the file path in the dialog box and hit enter
    twapi::send_keys [file nativename $::asciiExportPath]
    twapi::send_keys "~"
    
    twapi::minimize_window $windowHandle
    after 1000
}

proc parseAsciiExport {} {
    array unset ::bandModeCounts
    array unset ::operaterCounts
    array unset ::gotaOpCounts
    array unset ::operaterPointCounts
    # Clear past data
    foreach band $::ssbBands {set ::bandModeCounts($band) 0}
    foreach band $::codeBands {set ::bandModeCounts($band) 0}

    set fh [open $::asciiExportPath "r"]
    set data [split [read $fh] "\n"]
    close $fh

    set ::cwContacts 0
    set ::ssbContacts 0
    set ::totalContacts 0
    set ::totalGotaContacts 0
    set ::totalPoints 0

    set ::contactTimes [list]
    foreach line $data {
        if {$line == ""} {continue}
        set line [split $line ","]

        set contact [lindex $line 0]
        set date [lindex $line 1]
        set ctime [lindex $line 2]
        set mode [lindex $line 3]
        set frequ [lindex $line 4]
        set contactClass [lindex $line 5]
        set contactLocation [lindex $line 6]
        set points [lindex $line 7]
        set station [lindex $line 11]
        

        # Skip dupes and deleted contacts
        if {$points == 0} {continue;}
        
        # 06/25/11 18:02
        set secondsTime [clock scan "$date $ctime" -format "%m/%d/%y %H:%M"]
        if {$secondsTime != 0} {lappend ::contactTimes $secondsTime}

        incr ::totalPoints $points
        incr ::totalContacts 1
        
        if {$mode == "SSB"} {
            incr ::ssbContacts 1
        } elseif {$mode == "CW"} {
            incr ::codeContacts 1
        } else {
            logit "ERROR: Unkown QSO mode: $ mode"
        }

        if {$station == "N"} {
            incr ::totalGotaContacts
        }
        
        set op [lindex $line 9]

        set band [GetBand $frequ]
        if {$band == "0"} {
            logit "ERROR: Frequency was '$frequ'. Could not place in any band"
            continue
        }

        set key "$band $mode"
        set ::bandModeCounts($key) [expr $::bandModeCounts($key) + 1]
        
        if {[info exists ::operaterCounts($op)]} {
            set ::operaterCounts($op) [expr $::operaterCounts($op) + 1]
        } else {
            set ::operaterCounts($op) 1
        }
        
        if {$station == "N"} {
            if {[info exists ::gotaOpCounts($op)]} {
                set ::gotaOpCounts($op) [expr $::gotaOpCounts($op) + 1]
            } else {
                set ::gotaOpCounts($op) 1
            }
        }


        if {[info exists ::operaterPointCounts($op)]} {
            set ::operaterPointCounts($op) [expr $::operaterPointCounts($op) + $points]
        } else {
            set ::operaterPointCounts($op) $points
        }
    }

}

proc logit msg {
    puts $msg
}


proc DrawStats {} {
    global codeBandCountsWin
    global ssbBandCountsWin
    global opWin
    global gotaOpWin
    global contactSpeedWin
    global opPointWin
    global summaryWin

    global labelTheme

    destroy $codeBandCountsWin
    toplevel $codeBandCountsWin
    set i 0 
   
    set codeBandList [list]
    foreach band $::codeBands {lappend codeBandList [list $band $::bandModeCounts($band)]}
    set codeBandList [lsort -index 1 -decreasing -integer $codeBandList]
    foreach item $codeBandList {
        set band [lindex $item 0]
        label $codeBandCountsWin.$band -text "$band" {*}$labelTheme
        label $codeBandCountsWin.$band\count -text "[lindex $item 1]" {*}$labelTheme
        grid $codeBandCountsWin.$band -column 0 -row $i
        grid $codeBandCountsWin.$band\count -column 1 -row $i

        incr i
    }
    
    destroy $ssbBandCountsWin
    toplevel $ssbBandCountsWin
    set i 0
  
    set ssbBandList [list]
    foreach band $::ssbBands {lappend ssbBandList [list $band $::bandModeCounts($band)]}
    set ssbBandList [lsort -index 1 -decreasing -integer $ssbBandList]
    foreach item $ssbBandList {
        set band [lindex $item 0]
        label $ssbBandCountsWin.$band -text "$band" {*}$labelTheme
        label $ssbBandCountsWin.$band\count -text "[lindex $item 1]" {*}$labelTheme
        grid $ssbBandCountsWin.$band -column 0 -row $i
        grid $ssbBandCountsWin.$band\count -column 1 -row $i

        incr i
    }
    
    
    destroy $opWin
    toplevel $opWin
    set i 0
   
    set opList [list]
    foreach op [array names ::operaterCounts] {lappend opList [list $op $::operaterCounts($op)]}
    set opList [lsort -index 1 -decreasing -integer $opList]
    foreach item $opList {
        set op [lindex $item 0]
        label $opWin.opRank$op -text "[expr $i + 1]" {*}$labelTheme -width 3
        label $opWin.op$op -text "$op" {*}$labelTheme
        label $opWin.op$op\count -text "[lindex $item 1]" {*}$labelTheme
        grid $opWin.opRank$op -column 0 -row $i
        grid $opWin.op$op -column 1 -row $i
        grid $opWin.op$op\count -column 2 -row $i

        incr i
    }
    
    destroy $gotaOpWin
    toplevel $gotaOpWin
    set i 0
   
    set gotaOpList [list]
    foreach op [array names ::gotaOpCounts] {lappend gotaOpList [list $op $::gotaOpCounts($op)]}
    set gotaOpList [lsort -index 1 -decreasing -integer $gotaOpList]
    foreach item $gotaOpList {
        set op [lindex $item 0]
        label $gotaOpWin.opRank$op -text "[expr $i + 1]" {*}$labelTheme -width 3
        label $gotaOpWin.op$op -text "$op" {*}$labelTheme
        label $gotaOpWin.op$op\count -text "[lindex $item 1]" {*}$labelTheme
        grid $gotaOpWin.opRank$op -column 0 -row $i
        grid $gotaOpWin.op$op -column 1 -row $i
        grid $gotaOpWin.op$op\count -column 2 -row $i

        incr i
    }

    destroy $opPointWin
    toplevel $opPointWin
    set i 0
    
    foreach op [array names ::operaterPointCounts] {lappend opPointList [list $op $::operaterPointCounts($op)]}
    set opPointList [lsort -index 1 -decreasing -integer $opPointList]
    foreach item $opPointList {
        set op [lindex $item 0]
        label $opPointWin.opRank$op -text "[expr $i + 1]" {*}$labelTheme -width 3
        label $opPointWin.op$op -text "$op" {*}$labelTheme
        label $opPointWin.op$op\count -text "[lindex $item 1]" {*}$labelTheme
        grid $opPointWin.opRank$op -column 0 -row $i
        grid $opPointWin.op$op -column 1 -row $i
        grid $opPointWin.op$op\count -column 2 -row $i

        incr i
    }
    
    destroy $summaryWin
    toplevel $summaryWin
    pack [label $summaryWin.lcodeContacts -text "CW QSOs: $::codeContacts" {*}$::labelTheme -width 150]
    pack [label $summaryWin.lssbContacts -text "SSB QSOs: $::ssbContacts" {*}$::labelTheme -width 150]
    pack [label $summaryWin.lgotaContacts -text "GOTA QSOs: $::totalGotaContacts" {*}$::labelTheme -width 150]
    pack [label $summaryWin.lspacer -text "" {*}$::labelTheme -width 150]
    pack [label $summaryWin.ltotalContacts -text "All QSOs: $::totalContacts" {*}$::labelTheme -width 150]
    pack [label $summaryWin.ltotalPoints -text "QSO Points: $::totalPoints" {*}$::labelTheme -width 150]
    
    wm geometry $opWin 200x700+0+0 
    wm geometry $opPointWin 200x700+210+0
    wm geometry $ssbBandCountsWin 150x175+420+0 
    wm geometry $codeBandCountsWin 150x175+420+210
    wm geometry $gotaOpWin 200x200+420+420
    wm geometry $summaryWin 200x175+820+0
    update

    destroy $contactSpeedWin
    toplevel $contactSpeedWin
    
    set rateSplit 350
    canvas $contactSpeedWin.c -bg white -width $rateSplit -height 200

    array set timpMap {}
    for {set i 0} {$i <= $rateSplit} {incr i} {
       set timeMap($i) "0"
    }

    set maxRate 0
    if {[llength $::contactTimes] > 1} {
        set divSize [expr {([lindex $::contactTimes end] - [lindex $::contactTimes 0]) / (1.0*$rateSplit)}]
        foreach stamp $::contactTimes {
            set window [expr int(($stamp - [lindex ($::contactTimes 0])) / $divSize)]
            incr timeMap($window)
            if {$timeMap($window) > $maxRate} {set maxRate $timeMap($window)}
        }
       
        for {set i 0} {$i < $rateSplit} {incr i} {
            set y [expr (1.0*$timeMap($i))/$maxRate * 200]
            $contactSpeedWin.c create line $i 200 $i [expr 200 -$y] -fill blue
        }
    }
 
    pack $contactSpeedWin.c
      
    wm geometry $contactSpeedWin ${rateSplit}x200+625+350
}

    
set codeBands [list "2 CW" "6 CW" "10 CW" "15 CW" "20 CW" "40 CW" "80 CW"]
set ssbBands [list "2 SSB" "6 SSB" "10 SSB" "15 SSB" "20 SSB" "40 SSB" "80 SSB"]
array set bandModeCounts {}
array set operaterCounts {}
array set operaterPointCounts {}
array set gotaOpCounts {}

set ssbBandCountsWin .ssbBandCounts
set codeBandCountsWin .codeBandCounts
set opWin .operatorQSOWindow
set gotaOpWin .gotaOpQSOWindow
set opPointWin .operatorPointWindow
set contactSpeedWin .speedWin
set summaryWin .summaryWindow

wm withdraw .

toplevel $ssbBandCountsWin
toplevel $codeBandCountsWin
toplevel $opWin
toplevel $opPointWin
toplevel $summaryWin

proc go {} {
    ExportAscii
    parseAsciiExport
    DrawStats
    update
    after 10000 go
}

go
