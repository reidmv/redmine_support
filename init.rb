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

::SUPPORT_ROOT = "#{RAILS_ROOT}/vendor/plugins/support"
::SUPPORT_CONFIG = YAML.load_file("#{SUPPORT_ROOT}/config/support.yml")[RAILS_ENV]

Redmine::Plugin.register :support do
  name 'Support plugin'
  author 'Kurt Inge Småda / Reid Vandewielel'
  description 'Helpdesk & Support plugin'
  version '0.0.2'
end
