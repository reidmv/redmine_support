namespace :tw_support do
  namespace :email do
    task :receive_imap => :environment do
      imap_options = {:host => ENV['host'],
                :port => ENV['port'],
                :ssl => ENV['ssl'],
                :username => ENV['username'],
                :password => ENV['password'],
                :folder => ENV['folder'],
                :move_on_success => ENV['move_on_success'],
                :move_on_failure => ENV['move_on_failure']}

      Trollweb::IMAP.check(imap_options)
    end
  end
end