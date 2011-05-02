require File.dirname(__FILE__) + '/test_helper.rb'
require File.dirname(__FILE__) + '/../test_credentials.rb'
require 'simple_performer'
require 'eventmachine'
require 'faraday'
require_relative 'faraday_em_adapter'
require 'concur'

class TestPerformance < Test::Unit::TestCase

  def setup
    TestCredentials.get_credentials
    STDOUT.sync = true
    @domain = 'sdb_speed_test_domain'
    @item = 'toys'
    @attr = {'Jon' => %w{beer car}}
    # Interface instance
    @sdb = Aws::SdbInterface.new(TestCredentials.aws_access_key_id, TestCredentials.aws_secret_access_key)
    @sdb_em = Aws::SdbInterface.new(TestCredentials.aws_access_key_id, TestCredentials.aws_secret_access_key, :adapter=>Faraday::Adapter::EventMachine)
    @sdb_emf = Aws::SdbInterface.new(TestCredentials.aws_access_key_id, TestCredentials.aws_secret_access_key, :adapter=>Faraday::Adapter::EventMachineFutureAdapter)
  end



  def test_puts


    x = 50

#    assert @sdb_em.create_domain(@domain), 'create_domain fail'
#
    ret = nil
    timer = SimplePerformer::Aggregator.new

    timer.time "non em puts" do
      SimplePerformer.puts_duration("non em puts") do
        ret = put_bunch(@sdb, x)
      end
    end

    #thread pool style
    timer.time "thread pool puts" do
      SimplePerformer.puts_duration("thread pool puts") do
        puts_with_thread_pool(x)
      end
    end

    timer.time "eventmachine puts" do
      SimplePerformer.puts_duration("eventmachine puts") do
        puts_with_eventmachine(x)
      end
    end

    puts "\n\n" + timer.to_s

  end


  def puts_with_thread_pool(x)
    executor = Concur::Executor.new_thread_pool_executor(10)
    ret = []
    x.times do |i|
      f = executor.execute do
        r = @sdb.put_attributes(@domain, "#{@item}_#{i}", @attr)
      end
      puts 'f=' + f.inspect
      ret << f
    end
    x.times do |i|
      future = ret[i]
      fresult = future.get()
      puts 'fresult=' + fresult.inspect
      assert fresult[:request_id].length > 10
    end
    executor.shutdown
  end

  def puts_with_eventmachine(x)
    executor = Concur::Executor.new_eventmachine_executor
    ret = []
    x.times do |i|
      f = executor.execute do
        r = @sdb_emf.put_attributes(@domain, "#{@item}_#{i}", @attr)
      end
      puts 'f=' + f.inspect
      ret << f
    end
    x.times do |i|
      future = ret[i]
      fresult = future.get()
      puts 'fresult=' + fresult.inspect
      assert fresult[:request_id].length > 10
    end
    executor.shutdown
  end

  def test_selects
#    SimplePerformer.puts_duration("non em selects") do
#      sel = "select * from `#{@domain}`"
#      ret = @sdb.select(sel)
#      p ret
#    end

#    SimplePerformer.puts_duration("non em selects") do
#      EventMachine.run do
#        sel = "select * from `#{@domain}`"
#        ret = @sdb_em.select(sel)
#        p ret
#      end
#    end
#
#    # get attributes
#    values = @sdb_em.get_attributes(@domain, @item)[:attributes]['Jon'].to_a.sort
    # compare to original list
#    assert_equal values, @attr['Jon'].sort
    x = 10
    executor = Concur::Executor.new_eventmachine_executor
    ret = []
    x.times do |i|
      f = executor.execute do
        r = @sdb_emf.get_attributes(@domain, @item)
      end
      ret << f
    end
    x.times do |i|
      future = ret[i]
      rresult = future.get()
      puts 'rresult=' + rresult.inspect
      assert rresult[:request_id].length > 10
    end
    executor.shutdown
  end

  def wait_for_connections_and_stop
    if @connections.empty?
      EventMachine.stop
      true
    else
      puts "Waiting for #{@connections.size} connection(s) to finish ..."
      false
    end
  end

  def put_bunch(sdb, x)
    ret = []
    x.times do |i|
      r = sdb.put_attributes(@domain, "#{@item}_#{i}", @attr)
      if r.respond_to?(:async?) && r.async?
        p r
        r.on_success do |response|
          puts "#{i} response = " + response.inspect
          ret << response
        end
      else
        ret << r
      end
    end
    ret
  end


end
