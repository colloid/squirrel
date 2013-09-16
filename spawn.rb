require 'timeout'

def dev_null
  return $dev_null if $dev_null
  $dev_null = File.open("/dev/null", "r+")
  log "open '/dev/null' => #{$dev_null.to_i}"
  return $dev_null
end

# run `cmd'
# if wait == true, then detach is ignored and returns exit code
# otherwise returns child pid if detach == false and nil if detach == true
def spawn(cmd, stdin: nil, stdout: nil, stderr: nil, detach: true, wait: false)
  if stdin
    stdin = make_shared stdin
  else
    stdin = dev_null
  end

  if stdout
    stdout = make_shared stdout
  else
    stdout = dev_null
  end

  if stderr
    stderr = make_shared stderr
  else
    stderr = dev_null
  end

  if pid = fork # parent

    log "#{pid} forked"

    if wait
      log "wait for #{pid}"
      Process.waitpid pid
      rc = $?.exitstatus
      log "pid #{pid} exited => #{rc}"
      return rc
    end

    if detach
      Process.detach pid
      log "#{pid} detached"
      return nil
    end

    return pid

  else # child

    log "stdin => #{stdin.to_i}"
    log "stdout => #{stdout.to_i}"
    log "stderr => #{stderr.to_i}"
    log "exec '#{cmd}'"
    $stdin.reopen(stdin)
    $stdout.reopen(stdout)
    $stderr.reopen(stderr)
    exec "#{cmd}"
    raise "Unreachable reached"

  end
end

def perform cmd, check: true
  message "$ #{cmd}"
  rc = spawn cmd, wait: true, stdout: $sq.stdlog, stderr: $sq.stdlog + $sq.stdout
  if check && rc != 0
    warning "exit code #{rc}"
  end
  return rc
end

# TODO: watching_pipe
def execute cmd
  message "$ #{cmd}"
  rc = spawn cmd, wait: true, stdout: $sq.stdlog, stderr: $sq.stdlog + $sq.stdout
  raise "Broken Expectation (rc = #{rc})" unless rc == 0
  return rc
end

def examine cmd, output: $sq.output
  message "$ #{cmd}"
  r1, w1 = IO.pipe
  r2, w2 = IO.pipe
  r1 = make_shared r1
  w1 = make_shared w1
  r2 = make_shared r2
  w2 = make_shared w2
  log "new pipe: #{w1.to_i} => #{r1.to_i}"
  log "new pipe: #{w2.to_i} => #{r2.to_i}"

  pid = spawn cmd, stdout: w1, stderr: $sq.stdlog + $sq.stdout, wait: false, detach: false
  w1.close()
  r1.pump w2, $sq.stdlog
  r1.close()
  w2.close()

  line = nil
  rc = nil
  timeout = 0.05
  loop do
    begin
      Timeout.timeout(timeout) do
        r2.do { |r| line = r.gets }
      end
    rescue Timeout::Error
      log "Timeout::Error in examine, timeout = #{timeout}"
      timeout *= 2
      unless rc
        rc = Process.waitpid pid, Process::WNOHANG
        rc = $?.exitstatus if rc
        log "pid #{pid} exited => #{rc}" if rc
      end
      retry
    end
              
    raise StopIteration unless line
    output << line
  end

  r2.close()

  unless rc
    Process.waitpid pid
    rc = $?.exitstatus
  end
  raise "Broken Expectation (rc = #{rc})" unless rc == 0
  return rc
end

