require_dependency 'mailer'

module SupportPatchMailer
  def self.included(base)
    base.send(:include, InstanceMethods)
  end

  module InstanceMethods
    def issue_created(tracker, track_subject)
      original_headers = tracker.original_mail_headers

      from @settings['replyto']
      
      # Common headers
      headers 'X-Mailer' => 'Redmine',
              'X-Redmine-Host' => Setting.host_name,
              'X-Redmine-Site' => 'Support System',
              'Precedence' => 'bulk',
              @settings[:mail_header] => "[AUTO-##{tracker.issueid}]"
    
      recipients tracker.email
      if original_headers['cc'].nil? || original_headers['cc'].empty?
        cc @settings['replyto'] 
      else 
        cc [ @settings['replyto'], oheaders['cc'] ]
      end
      subject track_subject
      body :trackid => tracker.trackid
      content_type "text/plain"
      body render(:file => "newissue.text.plain.rhtml", :body => body)
    end

    def issue_updated(issue, journal, header)
      tracker = Support.getByIssueId(issue.id)

      # Update the headers in the journal entry
      journal.mail_header = header
      journal.save!

      # Build the email
      recipients header['to']
      from @settings['replyto']
      if header['cc'].nil? || header['cc'].empty?
        cc @settings['replyto'] 
      else 
        cc [ @settings['replyto'], header['cc'] ]
      end
      subject "RE: " + build_subject(tracker.trackid,issue.subject)
      headers 'X-Mailer' => 'Redmine',
              'X-Redmine-Host' => Setting.host_name,
              'X-Redmine-Site' => 'Support System',
              'Precedence' => 'bulk',
              @settings[:mail_header] => "[AUTO-##{issue.id}]"
      body :trackid => tracker.trackid,
           :status => issue.status,
           :agent => journal.user,
           :message => journal.notes
      content_type "text/plain"

      body render(:file => "updateissue.text.plain.rhtml", :body => body)
    end
  end
end

Mailer.send(:include, SupportPatchMailer)
