class SupportMailer < ActionMailer::Base

  def support_issue_created(issue, original_header)
    settings = Setting['plugin_support']

    message_id issue
    redmine_headers 'Project' => issue.project.identifier,
                    'Issue-Id' => issue.id
    redmine_headers 'Issue-Assignee' => issue.assigned_to.login if issue.assigned_to
    headers['in-reply-to'] = original_header['message-id']
    headers['references']  = original_header['message-id']
    recipients original_header['from']
    from settings['replyto']
    cc [ original_header['cc'], settings['replyto'] ].flatten.compact
    subject "Re: #{issue.subject}"
    body :issueid => issue.id
    content_type "text/plain"
    body render(:file => "support.newissue.text.plain.rhtml", :body => body)
  end

  def support_issue_updated(journal)
    settings = Setting['plugin_support']
    issue    = Issue.find(journal.journalized_id)
    header   = journal.mail_header

    message_id journal
    redmine_headers 'Project' => issue.project.identifier,
                    'Issue-Id' => issue.id
    redmine_headers 'Issue-Assignee' => issue.assigned_to.login if issue.assigned_to
    headers['in-reply-to'] = header['in-reply-to']
    headers['references']  = header['references']
    headers[settings['mail_header']] = header[settings['mail_header']]
    recipients header['to']
    from settings['replyto']
    cc [ header['cc'], settings['replyto'] ].flatten.compact
    subject "Re: #{issue.subject}"
    body :status => issue.status,
         :agent => journal.user,
         :message => journal.notes
    content_type "text/plain"
    body render(:file => "support.updateissue.text.plain.rhtml", :body => body)
  end

  def redmine_headers(h)
    h.each { |k,v| headers["X-Redmine-#{k}"] = v }
  end

  def message_id(object)
    @message_id_object = object
  end

  def deliver!(mail = @mail)
    return false if (recipients.nil? || recipients.empty?) &&
                    (cc.nil? || cc.empty?) &&
                    (bcc.nil? || bcc.empty?)
                    
    # Set Message-Id 
    if @message_id_object
      mail.message_id = self.class.message_id_for(@message_id_object)
    end
    
    # Log errors when raise_delivery_errors is set to false, Rails does not
    raise_errors = self.class.raise_delivery_errors
    self.class.raise_delivery_errors = true
    begin
      return super(mail)
    rescue Exception => e
      if raise_errors
        raise e
      elsif logger && logger.error
        logger.error "The following error occured while sending email notification: \"#{e.message}\". Check your configuration in config/email.yml."
      end
    ensure
      self.class.raise_delivery_errors = raise_errors
    end
  end

  def self.message_id_for(object)
    timestamp1 = object.send(object.respond_to?(:created_on) ? :created_on : :updated_on) 
    timestamp2 = Time.now
    hash = "redmine.#{object.class.name.demodulize.underscore}-#{object.id}.#{timestamp1.strftime("%Y%m%d%H%M%S")}.#{timestamp2.strftime("%Y%m%d%H%M%S")}"
    host = Setting.mail_from.to_s.gsub(%r{^.*@}, '')
    host = "#{::Socket.gethostname}.redmine" if host.empty?
    message_id = "<#{hash}@#{host}>"
    issue_id = case object.class.name
      when "Issue"
        object.id
      when "Journal"
        object.mail_header['message-id'] = message_id
        object.save!
        object.journalized_id
    end
    message_id_object = MessageId.new(:message_id => message_id, :issue_id => issue_id)
    message_id_object.save
    return message_id
  end

end

# Patch TMail so that message_id is not overwritten
module TMail
  class Mail
    def add_message_id( fqdn = nil )
      self.message_id ||= ::TMail::new_message_id(fqdn)
    end
  end
end
