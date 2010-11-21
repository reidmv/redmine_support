require_dependency 'mailer'

module SupportPatchMailer
  def self.included(base)
    base.send(:include, InstanceMethods)
  end

  module InstanceMethods
    def support_issue_created(issue)
      settings = Setting['plugin_support']
      original_header = Support.get_by_issueid(issue.id).original_mail_headers

      redmine_headers 'Project' => issue.project.identifier,
                      'Issue-Id' => issue.id,
                      'Issue-Author' => issue.author.login
      redmine_headers 'Issue-Assignee' => issue.assigned_to.login if issue.assigned_to
      message_id issue
      recipients original_header['from']
      cc [ original_header['cc'], settings['replyto'] ].flatten.compact
      subject "Re: #{issue.subject}"
      body :issue => issue
      content_type "text/plain"
      body render(:file => "support.newissue.text.plain.rhtml", :body => body, :layout => false)
    end

    def support_issue_updated(journal)
      debugger
      settings = Setting['plugin_support']
      issue    = Issue.find(journal.journalized_id)
      header   = journal.mail_header
      @updateJ = journal

      message_id journal
      recipients header['to']
      from settings['replyto']
      cc [ header['cc'], settings['replyto'] ].flatten.compact
      subject "RE: #{issue.subject}"
      body :status => issue.status,
           :agent => journal.user,
           :message => journal.notes
      content_type "text/plain"
      body render(:file => "support.updateissue.text.plain.rhtml", :body => body, :layout => false)
    end
  end
end

Mailer.send(:include, SupportPatchMailer)
