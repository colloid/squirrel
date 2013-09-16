$sq = Object.new
class << $sq
  attr_accessor :stdlog, :stdout, :output, :semaphore
end
$sq.stdlog = $stdout
$sq.stdout = $stdout
$sq.output = []

require_relative "debug"
require_relative "sem"
require_relative "io"
require_relative "spawn"
