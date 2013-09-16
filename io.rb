# -*- coding: utf-8 -*-

# Создаем новые потоки и оперируем с имеющимися

class SqIO
  def + rhs
    rhs = make_shared rhs
    if defined? @@sum_pool
      found = @@sum_pool[[self, rhs]]
      return found if found
      found = @@sum_pool[[rhs, self]]
      return found if found
    else
      @@sum_pool = {}
    end

    r, w = IO.pipe
    r = make_shared r
    w = make_shared w
    log "new pipe: #{w.to_i} => #{r.to_i}"

    if pid = fork # parent
      log "#{pid} forked and detached"
      Process.detach pid
      r.close()
      @@sum_pool[[self, rhs]] = w
      return w

    else # child

      log "connect fd-s: #{r.to_i} => (#{self.to_i}, #{rhs.to_i})"
      w.close()
      line = nil
      loop do
        r.do { |r| line = r.gets }
        raise StopIteration unless line
        self.do { |s| s.write line }
        rhs.do { |rhs| rhs.write line }
      end
      log "exit 0"
      exit 0

    end
  end

  def pump *args
    args.each_with_index do |io, i|
      args[i] = make_shared io
    end

    hash = Hash.new(0)
    args.each do |arg|
      hash[arg] += 1
    end

    @@iopump_pool = {} unless defined? @@iopump_pool
    found = @@iopump_pool[hash]
    return found if found

    if pid = fork # parent

      log "#{pid} forked and detached"
      Process.detach pid
      @@iopump_pool[hash] = pid
      return pid

    else # child

      log "something"
      log "connect fd-s: #{self.to_i} => "\
          "(#{args.inject("") { |m, o| m + ", " + o.to_i.to_s }[2..-1]})"

      line = nil
      loop do
        self.do { |s| line = s.gets }
        raise StopIteration unless line
        args.each do |io|
          io.do { |i| i.write line }
        end
      end
      log "exit 0"
      exit 0
    end
  end
end
      
