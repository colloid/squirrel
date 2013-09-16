# -*- coding: utf-8 -*-
require 'SysVIPC'

class SemPool
  SEMMSL = 250
  def initialize
    @index = -1
    @array = SysVIPC::Semaphore.new(SysVIPC::IPC_PRIVATE, SEMMSL, 0600)
    @array.setall(Array.new(SEMMSL, 1)) if @array.pid(0) == 0
  end
  def newid
    @index = @index + 1
    raise "Semaphore overflow" if @index >= SEMMSL
    return @index
  end
  def sem_wait id
    #$stderr.puts "#{sprintf "%05d", Process.pid}: #{id} waits for semaphore"
    @array.op([SysVIPC::Sembuf.new(id, -1)])
    #$stderr.puts "#{sprintf "%05d", Process.pid}: #{id} got semaphore"
  end
  def sem_post id
    #$stderr.puts "#{sprintf "%05d", Process.pid}: #{id} posts semaphore"
    @array.op([SysVIPC::Sembuf.new(id, 1)])
    #$stderr.puts "#{sprintf "%05d", Process.pid}: #{id} posted semaphore"
  end
  def close
    #@array.rm # TODO
  end
end

$sq.semaphore = SemPool.new
at_exit { $sq.semaphore.close }

class IO
  def shared?
    false
  end
end

class SqIO
  def initialize io
    io.flush
    io.close_on_exec = false
    @io = io
    @id = $sq.semaphore.newid
    #trace "fd #{@io.to_i} got sem_id = #{@id}"
    @acquired = false
  end
  def method_missing symbol, *args
    raise "Non-blocked access to the shared iostream (#{@io.to_i})" unless @acquired
    @io.send(symbol, *args)
  end
  def do # TODO apply RAII
    begin
      $sq.semaphore.sem_wait @id
      @acquired = true
      yield self
      @io.flush unless @io.closed?
      @acquired = false
    ensure
      $sq.semaphore.sem_post @id
    end
  end
  def to_i
    @io.to_i
  end
  def reopen rhs
    if rhs.to_i == self.to_i
      return self
    end
    self.do do |s|
      rhs.do { |r| s.reopen r }
    end
  end
  def shared?
    true
  end
  def close
    # закрытие потока в этом процессе накак не повлияет на другие,
    # так что блок не нужен
    log "fd #{@io.to_i} closed"
    @io.close
  end
  protected
  def to_io
    @io
  end
end

def make_shared io
  return io if io.shared?
  $ioshared_pool = {} unless defined? $ioshared_pool
  found = $ioshared_pool[io]
  return found if found
  created = SqIO.new io
  $ioshared_pool[io] = created
  return created
end
