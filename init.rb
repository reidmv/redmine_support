require 'redmine'

require 'support_hooks'
require 'support_plugin/support_patch_application_helper'
require 'support_plugin/support_patch_issues_controller'
require 'support_plugin/support_patch_journal'
require 'support_plugin/support_patch_mailer'
require 'support_plugin/support_patch_mail_handler_controller'

#Dispatcher.to_prepare :tw_support do
#  require_dependency 'issue'
#  # Guards against including the module multiple time (like in tests)
#  # and registering multiple callbacks
#  unless Issue.included_modules.include? Trollweb::IssuePatch
#   Issue.send(:include, Trollweb::IssuePatch)
#  end
#end

SUPPORT_ROOT = RAILS_ROOT + "/vendor/plugins/support"

Redmine::Plugin.register :support do
  name 'Support plugin'
  author 'Kurt Inge Småda / Reid Vandewiee'
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

# Herefollows an ugly hack that will make stuff work without further plugin
# installation instructions. The basic problem is that ActionMailer will not
# look for templates in the plugin app/views directory. There weren't a 
# whole lot of options available and believe it or not, this was by far the
# very very very most shiny and pretty. Please I beg of you somebody step
# forward to prove me wrong!
templates = []
templates << "app/views/mailer/support.updateissue.text.plain.rhtml"
templates << "app/views/mailer/support.newissue.text.plain.rhtml"
templates.each do |template|
  begin
    File.symlink("#{SUPPORT_ROOT}/#{template}", "#{RAILS_ROOT}/#{template}")
  rescue Exception
    # I don't care if you failed. You are an ugly hack.
  end
end
