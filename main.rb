#!/usr/bin/env ruby

require_relative "squirrel"

def payload
  perform "echo perform"
  perform "echo perform >&2"
  execute "echo execute"
  #execute "echo execute | grep ololo"
  examine "echo ololo"
  perform "echo perform >&2"
  perform "echo perform >&2"
  execute "echo execute"
  execute "echo execute"
  execute "echo execute"
  examine "echo ololo"
  examine "echo ololo"
  examine "echo ololo"
  examine "echo ololo"
  examine "echo ololo"
  examine "echo ololo"
  examine "echo ololo"
  examine "echo execute | grep ololo"
end

def main
  $sq.stdout = make_shared $stderr
  $sq.stdlog = make_shared File.open("sq_log", "w")
  log "open 'sq_log' => #{$sq.stdlog.to_i}"
  begin
    payload()
  rescue
    error $!.message
    log "=== Exception Backtrace ==="
    $!.backtrace.each { |f| log f }
    log "==========================="
  ensure
    $sq.stdlog.close()
  end
end

main
