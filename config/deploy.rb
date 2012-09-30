# Settings
set :application, "dailyfitlog"
default_run_options[:pty] = true
ssh_options[:forward_agent] = true
set :use_sudo, false

# Colors
require 'capistrano_colors'


# Repository
set :scm, :git
set :keep_releases, 5
set :deploy_via, :remote_cache

namespace :deploy do
  desc "Configures symlinks for database.yml and public folders"
  task :config_symlink do
    run "ln -s #{shared_path}/database.yml #{release_path}/config/database.yml"
    %w(bulletin_boards registrations import).each do |folder|
      run "rm -rf #{release_path}/public/#{folder}"
      run "ln -nfs #{shared_path}/#{folder} #{release_path}/public/#{folder}"
    end
  end

  desc "Restarting services after deploy"
  task :restart do
    restart_workers
    restart_scheduler
    put_version
  end

  desc "Restart Resque Workers"
  task :restart_workers, :roles => :db do
    run_remote_rake "resque:restart_workers"
  end

  desc "Restart Resque scheduler"
  task :restart_scheduler, :roles => :db do
    run_remote_rake "resque:restart_scheduler"
  end

  desc "Puts version file to the server"
  task :put_version, :roles => :app do
    put "Date: #{Time.now.utc} Branch: #{branch} SHA: #{current_revision}", "#{release_path}/VERSION"
  end
end

desc "Invokes remote rake task, provide task=db:create as a parameter"
task :remote_rake do
  run_remote_rake "#{ENV['task']}"
end

##
# Rake helper task.
# http://pastie.org/255489
# http://geminstallthat.wordpress.com/2008/01/27/rake-tasks-through-capistrano/
# http://ananelson.com/said/on/2007/12/30/remote-rake-tasks-with-capistrano/
def run_remote_rake(rake_cmd)
  rake_args = ENV['RAKE_ARGS'].to_s.split(',')
  cmd = "cd #{fetch(:latest_release)} && #{fetch(:rake, "rake")} RAILS_ENV=#{fetch(:rails_env, "production")} #{rake_cmd}"
  cmd += "['#{rake_args.join("','")}']" unless rake_args.empty?
  run cmd
  set :rakefile, nil if exists?(:rakefile)
end

after "deploy:finalize_update", "deploy:config_symlink"
before "deploy:restart", "deploy:migrate"

after "deploy", "deploy:cleanup"
