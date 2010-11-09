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
           :default => {'support_mailhost'   => 'mail.host.com',
                        'support_username'   => 'user',
                        'support_password'   => 'pass',
                        'support_import_dir' => 'mail.import',
                        'support_replyto'    => 'support@host.com',
                        'support_project'    => 'support',
                        'support_tracker'    => 'support' }
end
