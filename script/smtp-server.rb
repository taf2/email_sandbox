#!/usr/bin/env ruby
#
# initially from http://snippets.dzone.com/posts/show/3932
# the goal here is very simple
# provide an SMTP interface to receive all emails from an application
# drop each email into a database and provide an easy web interface to see all the emails that would normally be sent
#
require 'gserver'
require 'optparse'

options = {}

OptionParser.new do |opts|
  opts.banner = "Usage: #{__FILE__} [options]"

  opts.on("-p", "--port PORT", "Bind to PORT") do |port|
    options[:port] = port
  end

  opts.on("-e", "--environment ENV", "Load RAILS environment, defaults to development") do |environment|
    options[:environment] = environment
  end

end.parse!

options[:environment] ||= 'development'
options[:port] ||= 1234

puts "Booting... #{options[:environment]}"

RACK_ENV = ENV['RAILS_ENV'] = RAILS_ENV = options[:environment]

APP_PATH = File.expand_path('../../config/application',  __FILE__)
require File.expand_path('../../config/environment',  __FILE__)

PID_PATH = File.expand_path(File.join(Rails.root,'tmp','pids','smtp.pid'))
LOG_STDERR = File.expand_path(File.join(Rails.root,'log','smtp.stderr.log'))
LOG_STDOUT = File.expand_path(File.join(Rails.root,'log','smtp.stdout.log'))

if File.exist?(PID_PATH)
  STDERR.puts "Error #{PID_PATH} exists!"
  exit 1
end

class SMTPServer < GServer
  def serve(io)
    @data_mode = false
    puts "Connected"
    io.print "220 hello\r\n"
    email = Email.new
    email.message = ''
    loop do
      if IO.select([io], nil, nil, 0.1)
        data = io.readpartial(4096)
        puts ">>" + data
        email.message += data
        ok, op = process_line(email,data)
        break unless ok
        io.print op
      end
      break if io.closed?
    end
    if email.valid?
      email.save
    end
    io.print "221 bye\r\n"
    io.close
  end

  def process_line(email,line)
    if (line =~ /^(HELO|EHLO)/)
      return true, "220 and..?\r\n"
    end
    if (line =~ /^QUIT/)
      return false, "bye\r\n"
    end
    if (line =~ /^MAIL FROM\:/)
      email.from = line.sub(/^MAIL FROM\:/,'')
      return true, "220 OK\r\n"
    end
    if (line =~ /^RCPT TO\:/)
      email.to = line.sub(/^RCPT TO\:/,'')
      return true, "220 OK\r\n"
    end
    if (line =~ /^DATA/)
      @data_mode = true
      return true, "354 Enter message, ending with \".\" on a line by itself\r\n"
    end
    if (@data_mode) && (line.chomp =~ /^.$/)
      @data_mode = false
      return true, "220 OK\r\n"
    end
    if @data_mode
      puts line 
      return true, ""
    else
      return true, "500 ERROR\r\n"
    end
  end
end

defined?(ActiveRecord::Base) and ActiveRecord::Base.connection.disconnect!

pid = fork do
  Process.setsid

  fork do
    Dir.chdir '/'
    File.umask 0000

    STDIN.reopen '/dev/null'
    STDOUT.reopen LOG_STDOUT, 'a'
    STDOUT.sync = true
    STDERR.reopen LOG_STDERR, 'a'
    STDERR.sync = true
    #STDERR.reopen STDOUT

    defined?(ActiveRecord::Base) and ActiveRecord::Base.connection.disconnect!
    defined?(ActiveRecord::Base) and ActiveRecord::Base.establish_connection

    a = SMTPServer.new(options[:port].to_i)
    puts "Listening on Port #{options[:port]} as #{Process.pid}"

    File.open(PID_PATH,'wb') {|f| f << Process.pid }

    at_exit { File.unlink(PID_PATH) }

    a.start
    a.join

  end
end

Process.detach(pid)
