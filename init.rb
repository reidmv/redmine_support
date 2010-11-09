require 'redmine'
require 'hooks'

#Dispatcher.to_prepare :tw_support do
#  require_dependency 'issue'
#  # Guards against including the module multiple time (like in tests)
#  # and registering multiple callbacks
#  unless Issue.included_modules.include? Trollweb::IssuePatch
#   Issue.send(:include, Trollweb::IssuePatch)
#  end
#end

Redmine::Plugin.register :support do
  name 'Support plugin'
  author 'Kurt Inge Småda / Reid Vandewielel'
  description 'Helpdesk & Support plugin'
  version '0.0.2'
  settings :partial => 'settings/settings',
           :default => {'mailhost'   => 'mail.host.com',
                        'username'   => 'user',
                        'password'   => 'pass',
                        'import_dir' => 'mail.import',
                        'replyto'    => 'support@host.com',
                        'project'    => 'support',
                        'tracker'    => 'support' }
end
