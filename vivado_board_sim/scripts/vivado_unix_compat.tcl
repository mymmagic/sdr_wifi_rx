# Windows-safe replacements for the small Unix command subset used by the
# openwifi Vivado Tcl scripts. Source this before sourcing the original scripts.

if {[llength [info commands native_exec]] == 0} {
  rename exec native_exec
}

proc ow_copy_contents {src_dir dst_dir} {
  file mkdir $dst_dir
  foreach item [glob -nocomplain -directory $src_dir *] {
    file copy -force $item $dst_dir
  }
}

proc ow_git_rev_for_script {script_path} {
  set script_dir [file dirname [file normalize $script_path]]
  set hash "00000000"
  if {[catch {set hash [string trim [native_exec git -C $script_dir rev-parse --short=8 HEAD]]}]} {
    set hash "00000000"
  }
  return $hash
}

proc exec {args} {
  if {[llength $args] == 0} {
    return
  }

  set cmd [lindex $args 0]

  if {[string match "*get_git_rev.sh" [file tail $cmd]]} {
    return [ow_git_rev_for_script $cmd]
  }

  switch -- $cmd {
    pwd {
      return [pwd]
    }

    rm {
      foreach item [lrange $args 1 end] {
        if {[string match "-*" $item]} {
          continue
        }
        file delete -force $item
      }
      return
    }

    mkdir {
      foreach item [lrange $args 1 end] {
        if {[string match "-*" $item]} {
          continue
        }
        file mkdir $item
      }
      return
    }

    cp {
      set paths [list]
      foreach item [lrange $args 1 end] {
        if {[string match "-*" $item]} {
          continue
        }
        lappend paths $item
      }
      if {[llength $paths] < 2} {
        error "cp requires at least one source and a destination: $args"
      }
      set dst [lindex $paths end]
      foreach src [lrange $paths 0 end-1] {
        if {[regexp {[/\\]\.$} $src] || [file tail $src] eq "."} {
          ow_copy_contents [file normalize $src] [file normalize $dst]
        } else {
          file copy -force $src $dst
        }
      }
      return
    }

    cat {
      set redirect_idx [lsearch -exact $args ">>"]
      set mode "a"
      if {$redirect_idx < 0} {
        set redirect_idx [lsearch -exact $args ">"]
        set mode "w"
      }
      if {$redirect_idx > 1} {
        set dst [lindex $args [expr {$redirect_idx + 1}]]
        set out [open $dst $mode]
        foreach src [lrange $args 1 [expr {$redirect_idx - 1}]] {
          set in [open $src r]
          puts -nonewline $out [read $in]
          close $in
        }
        close $out
        return
      }
    }

    echo {
      set redirect_idx [lsearch -exact $args ">"]
      if {$redirect_idx > 0} {
        set dst [lindex $args [expr {$redirect_idx + 1}]]
        set text [join [lrange $args 1 [expr {$redirect_idx - 1}]] " "]
        set out [open $dst w]
        puts $out $text
        close $out
        return
      }
    }
  }

  return [uplevel 1 [list native_exec {*}$args]]
}
