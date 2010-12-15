#!/usr/bin/env ruby
#
# initially from http://snippets.dzone.com/posts/show/3932
# the goal here is very simple
# provide an SMTP interface to receive all emails from an application
# drop each email into a database and provide an easy web interface to see all the emails that would normally be sent
#
require 'gserver'
puts "Booting..."

APP_PATH = File.expand_path('../../config/application',  __FILE__)
require File.expand_path('../../config/environment',  __FILE__)

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

a = SMTPServer.new(1234)
puts "Listening on Port 1234"
a.start
a.join
