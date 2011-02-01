listen "/tmp/email_sandbox.unicorn.sock", :backlog => 64
worker_processes 2

working_directory "/var/www/apps/email_sandbox/current"
timeout 60
pid "/var/www/apps/email_sandbox/shared/pids/unicorn.pid"
stderr_path "/var/www/apps/email_sandbox/shared/log/unicorn.stderr.log"
stdout_path "/var/www/apps/email_sandbox/shared/log/unicorn.stdout.log"

preload_app true
GC.respond_to?(:copy_on_write_friendly=) and GC.copy_on_write_friendly = true

before_fork do |server, worker|
  defined?(ActiveRecord::Base) and ActiveRecord::Base.connection.disconnect!

  old_pid = "/var/www/apps/email_sandbox/shared/pids/unicorn.pid.oldbin"
  if File.exists?(old_pid) && server.pid != old_pid
    begin
      Process.kill("QUIT", File.read(old_pid).to_i)
    rescue Errno::ENOENT, Errno::ESRCH
      # someone else did our job for us
    end
  end

end

after_fork do |server, worker|
  port = 9000 + worker.nr
#  addr = "127.0.0.1:#{port}"
#  server.listen(addr, :tries => -1, :delay => 5, :tcp_nopush => true)

  child_pid = server.config[:pid].sub('.pid', ".#{port}.pid")

  defined?(ActiveRecord::Base) and ActiveRecord::Base.establish_connection
  # drop a pidfile
  File.open(child_pid, "wb") {|f| f << Process.pid }
end
