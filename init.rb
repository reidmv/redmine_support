require 'redmine'

require 'support_hooks'
require 'support_application_helper_patch'
require 'support_issues_controller_patch'
require 'support_journal_patch'

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
  author 'Kurt Inge Småda / Reid Vandewiel'
  description 'Helpdesk & Support plugin'
  version '0.0.2'
  settings :default => {
    'api_key'        => 'secret',
    'mail_header'    => 'X-TW',
    'replyto'        => 'support@host.com',
    'tracker'        => 'support',
    'login_user'     => 'support',
    'homedir_path'   => '/u',
    'signature_file' => '.signature',
    'auto_newreply'  => 'false',

 }, :partial => 'settings/support_settings'

  project_module :support do
    permission :disable_support_cc, { :support => :index, :supportmail => :index }, :require => :member
    permission :view_support_issue, { :supportmail => :index }, :require => :member
  end
end
