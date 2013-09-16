# -*- coding: utf-8 -*-
# подробный вывод промежуточных шагов и результатов программы
def trace msg
  log "trace: #{msg}"
end

# основные шаги работы программы
def log msg
  if $sq.stdlog.shared?
    if $pending_log_output && $pending_log_output.length > 0
      $pending_log_output.each do |msg|
        $sq.stdlog.do { |s| s.puts "#{sprintf "%05d", Process.pid}: #{msg}" }
      end
      $pending_log_output = []
    end
    $sq.stdlog.do { |s| s.puts "#{sprintf "%05d", Process.pid}: #{msg}" }
  else
    $pending_log_output = [] unless $pending_log_output
    $pending_log_output << msg
  end
end

# информация о ходе или результате процесса
def message msg
  $sq.stdout.do { |s| s.puts msg }
  log "message: '#{msg}'"
end

# предупреждения
def warning msg
  message "warning: " + msg
end

# ошибки
def error msg
  message "error: " + msg
end

