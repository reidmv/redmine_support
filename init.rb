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



Redmine::Plugin.register :redmine_tw_support do
  name 'Trollweb Support plugin'
  author 'Kurt Inge Smådal'
  description 'Support plugin for Trollweb'
  version '0.0.1'
end
