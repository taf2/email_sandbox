set :application, "email_sandbox"
set :repository,  "git@tools:email_sandbox.git"

set :scm, :git
set :deploy_to, "/var/www/apps/#{application}"
set :deploy_via, :remote_cache

set :user, 'deployer'
set :use_sudo, false

# host variables
set :servers, [:unicorn]
set :configs, [:database]

role :web, "o1"                          # Your HTTP server, Apache/etc
role :app, "o1"                          # This may be the same as your `Web` server
role :db,  "o1", :primary => true # This is where Rails migrations will run
role :db,  "o1"

set :gemset, "email_box"
set :rvm, "1.9.2-p0@#{gemset}"
set :rvm_home, '/home/deployer/.rvm'
set :rvm_ruby, 'ruby-1.9.2-p0'
set :default_environment, {
  'PATH'         => "#{rvm_home}/rubies/#{rvm_ruby}/bin:#{rvm_home}/gems/#{rvm_ruby}@#{gemset}/bin:/bin:#{rvm_home}/bin:$PATH",
  'RUBY_VERSION' => 'ruby 1.9.2',
  'GEM_HOME'     => "#{rvm_home}/gems/#{rvm_ruby}@#{gemset}",
  'GEM_PATH'     => "#{rvm_home}/gems/#{rvm_ruby}@#{gemset}",
  'BUNDLE_PATH'  => "#{rvm_home}/gems/#{rvm_ruby}@#{gemset}"
}

set :environment, "production"
set :stage, "production"
set :unicorn_hosts, [:o1] #, :gp2, :gp3, gp4]
set :app_hosts, unicorn_hosts
set :branch, 'master'

role :web, "o1"
role :app, *(app_hosts.map {|h| h.to_s})
role :db,  "o1", :primary => true

after "deploy:update_code", "rails:bundle"
after "deploy:update_code", "deploy:links"
after "deploy:update_code", "rails:rvm_trust"

after "deploy:symlink", "deploy:links"

after "deploy", "deploy:cleanup"

namespace :rails do
  desc "Bundle the application"
  task :bundle, :roles => :app, :except => { :no_release => true } do
    run "echo $PATH"
    run "echo 'rvm use #{rvm}' > #{release_path}/.rvmrc"
    run "cd #{release_path} && bundle install --gemfile=Gemfile"
  end

  desc "Upgrade bundler"
  task :upgrade_bundler, :roles => :app, :except => { :no_release => true } do
    run "rvm use #{rvm} && gem up bundler"
  end

  desc "Tell RVM to have trust in our release"
  task :rvm_trust do
    run "rvm rvmrc trust #{release_path} && rvm rvmrc trust #{current_path}"
  end

end

namespace :smtp do
  task :start do
    run "cd #{current_path} && rvm use #{rvm} && bundle exec ./script/smtp-server.rb"
  end

  task :stop do
    run "kill `cat #{shared_path}/pids/smtp.pid` && rm #{shared_path}/pids/smtp.pid"
  end
end

namespace :deploy do

  # fresh app server startup
  def start_server(server_name, server_type)
    command = "#{server_type} -E #{environment} -D -c #{current_path}/config/#{server_name}_#{server_type}.rb"
    run "cd #{current_path} rvm use #{rvm} && bundle exec '#{command}'"
  end

  def stop_server(server_name, server_type)
    pid = "#{shared_path}/pids/#{server_type}.pid"
    run "if [ -f #{pid} ]; then kill `cat #{pid}`; true; fi"
  end

  def restart_server(server_name, server_type)
    pid = "#{shared_path}/pids/#{server_type}.pid"
    start_command = "bundle exec #{server_type} -E #{environment} -D -c #{current_path}/config/#{server_name}_#{server_type}.rb"
    restart_conditions = "[ -f #{pid} ] && [ `ps -ef | grep \\`cat #{pid}\\` | wc -l` -gt 1 ]"

    reload_command = %(cd #{current_path} && rvm use #{rvm}; if #{restart_conditions}; then /bin/kill -s USR2 `/bin/cat #{pid}` ; else #{start_command} ; fi)
    run reload_command
  end

  def link_config(config)
    run "if [ -f '#{shared_path}/config/#{config}.yml' ]; then ln -sf #{shared_path}/config/#{config}.yml #{release_path}/config/#{config}.yml; fi"
  end

  task :start do
    servers.each do|server_type|
      send("#{server_type}_hosts").each {|host| start_server host, server_type }
    end
  end

  task :stop do
    servers.each do|server_type|
      send("#{server_type}_hosts").each {|host| stop_server host, server_type }
    end
  end

  task :restart, :roles => :app, :except => { :no_release => true } do
    servers.each do|server_type|
      send("#{server_type}_hosts").each {|host| restart_server host, server_type }
    end
  end

  desc "Link server configuration to latest deployed code base"
  task :links do
    configs.each do|config|
      link_config config
    end
  end

end
