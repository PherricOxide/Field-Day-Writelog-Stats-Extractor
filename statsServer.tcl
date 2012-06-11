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
    set ::totalPoints 0


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

        # Skip dupes and deleted contacts
        if {$points == 0} {
            continue;
        }

        incr totalPoints $points
        
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
            set ::operaterCounts($op) 0
        }


        if {[info exists ::operaterPointCounts($op)]} {
            set ::operaterPointCounts($op) [expr $::operaterPointCounts($op) + $points]
        } else {
            set ::operaterPointCounts($op) $points
        }
    }

    puts "Points $totalPoints"
}

proc logit msg {
    puts $msg
}


proc DrawStats {} {
    global codeBandCountsWin
    global ssbBandCountsWin
    global opWin
    global opPointWin
    global summaryWin

    global labelTheme

    destroy $codeBandCountsWin
    toplevel $codeBandCountsWin
    set i 0 
    
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
    
    foreach op [array names ::operaterCounts] {lappend opList [list $op $::operaterCounts($op)]}
    set opList [lsort -index 1 -decreasing -integer $opList]
    foreach item $opList {
        set op [lindex $item 0]
        label $opWin.opRank$op -text "[expr $i + 1]" {*}$labelTheme
        label $opWin.op$op -text "$op" {*}$labelTheme
        label $opWin.op$op\count -text "[lindex $item 1]" {*}$labelTheme
        grid $opWin.opRank$op -column 0 -row $i
        grid $opWin.op$op -column 1 -row $i
        grid $opWin.op$op\count -column 2 -row $i

        incr i
    }

    destroy $opPointWin
    toplevel $opPointWin
    set i 0
    
    foreach op [array names ::operaterPointCounts] {lappend opPointList [list $op $::operaterPointCounts($op)]}
    set opPointList [lsort -index 1 -decreasing -integer $opPointList]
    foreach item $opPointList {
        set op [lindex $item 0]
        label $opPointWin.opRank$op -text "[expr $i + 1]" {*}$labelTheme
        label $opPointWin.op$op -text "$op" {*}$labelTheme
        label $opPointWin.op$op\count -text "[lindex $item 1]" {*}$labelTheme
        grid $opPointWin.opRank$op -column 0 -row $i
        grid $opPointWin.op$op -column 1 -row $i
        grid $opPointWin.op$op\count -column 2 -row $i

        incr i
    }
    
    
    destroy $summaryWin
    toplevel $summaryWin
    
    
    wm geometry $opWin 235x700+0+0 
    wm geometry $opPointWin 235x700+250+0 
    wm geometry $ssbBandCountsWin 150x180+500+0 
    wm geometry $codeBandCountsWin 150x180+660+0
    wm geometry $summaryWin 150x200+820+0
}

    
set codeBands [list "2 CW" "6 CW" "10 CW" "15 CW" "20 CW" "40 CW" "80 CW"]
set ssbBands [list "2 SSB" "6 SSB" "10 SSB" "15 SSB" "20 SSB" "40 SSB" "80 SSB"]
array set bandModeCounts {}
array set operaterCounts {}
array set operaterPointCounts {}


set ssbBandCountsWin .ssbBandCounts
set codeBandCountsWin .codeBandCounts
set opWin .operatorQSOWindow
set opPointWin .operatorPointWindow
set summaryWin .summaryWindow

wm withdraw .

toplevel $ssbBandCountsWin
toplevel $codeBandCountsWin
toplevel $opWin
toplevel $opPointWin
toplevel $summaryWin

    #ExportAscii
    parseAsciiExport
    DrawStats
    update
    after 4000
