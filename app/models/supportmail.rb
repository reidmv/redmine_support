class Supportmail < ActionMailer::Base

  SUBJECT_MATCH = %r{\[TW-#([A-Z]+[0-9]+)\]}

  def receive(email)
    sender = email.from.to_a.first.to_s.strip
    subject = email.subject
    message = cleanup_body(plain_text_body(email))
    
    if m = email.subject.match(SUBJECT_MATCH)
      trackid = m[1].to_s
    else
      trackid = 0     
    end
    
    if trackid == 0
      ## Create new issue
      
      if not email.header['auto-submitted'].nil?
        # Auto submitted mail - ignore it.
        return false
      end
      
      uid = genuid
      while Support.find_by_trackid(uid)
       uid = genuid
      end
     
      issue = create_issue(email,uid)
      
      newtracker = Support.new(:trackid => uid, :email => sender, :issueid => issue.id)
      newtracker.save!
      
      # Send mail to user
      mailstatus = Supportmail.deliver_issue_created(newtracker, build_subject(uid,subject))
    else
      ## Append to an old one.
      support = Support.find_by_trackid(trackid)
      issue = receive_issue_reply(support.issueid,email)
    end
        
    return true
  end

  # Mail issue_created
  def issue_created(tracker,track_subject)
    from SUPPORT_CONFIG['support_replyto']
    
    # Common headers
    headers 'X-Mailer' => 'Redmine',
            'X-Redmine-Host' => Setting.host_name,
            'X-Redmine-Site' => 'Support System',
            'Precedence' => 'bulk',
            'Auto-Submitted' => 'auto-generated'
  
    recipients tracker.email
    subject track_subject
    body :trackid => tracker.trackid
    content_type "text/plain"
    body render(:file => "newissue.text.plain.rhtml", :body => body)
  end
  
  # Mail issue_updated
  def issue_updated(issue,journal)
    from SUPPORT_CONFIG['support_replyto']
    
    # Common headers
    headers 'X-Mailer' => 'Redmine',
            'X-Redmine-Host' => Setting.host_name,
            'X-Redmine-Site' => 'Support System',
            'Precedence' => 'bulk',
            'Auto-Submitted' => 'auto-generated'

    tracker = Support.getByIssueId(issue.id);
    
    recipients tracker.email
    subject "RE: " + build_subject(tracker.trackid,issue.subject)
    body :trackid => tracker.trackid,
         :status => issue.status,
         :agent => journal.user,
         :message => journal.notes
         
    content_type "text/plain"
    body render(:file => "updateissue.text.plain.rhtml", :body => body)
    
  end
  
  def create_issue(email,uid)
    user = User.find(:first, :conditions => ["login=?", 'support']) 
    project = target_project
    tracker = project.trackers.find_by_name('support') || project.trackers.find(:first)
    category = project.issue_categories.find(:first)
    priority = IssuePriority.find_by_name('normal')
    status =  IssueStatus.find_by_name('new')
    
    issue = Issue.new(:author => user, :project => project, :tracker => tracker, :category => category, :priority => priority)
    # check workflow
    if status && issue.new_statuses_allowed_to(user).include?(status)
      issue.status = status
    end
    issue.subject = email.subject.chomp
    if issue.subject.blank?
      issue.subject = '(no subject)'
    end
    # custom fields
    #issue.custom_field_values = issue.available_custom_fields.inject({}) do |h, c|
    #  if value = get_keyword(c.name, :override => true)
    #    h[c.id] = value
    #  end
    #  h
    #end
    issue.description = cleanup_body(plain_text_body(email)) + "\nTrackerID: " + uid
    # add To and Cc as watchers before saving so the watchers can reply to Redmine
    #add_watchers(issue)
    issue.save!
    add_attachments(issue,email,user)
    logger.info "MailHandler: issue ##{issue.id} created by #{user}" if logger && logger.info
    issue
  end
  
  # Adds a note to an existing issue
  def receive_issue_reply(issue_id,email)
    status =  IssueStatus.find_by_name('Tildelt')
    user = User.find(:first, :conditions => ["login=?", 'support']) 
    
    issue = Issue.find_by_id(issue_id)
    return unless issue
    # check permission
    #unless @@handler_options[:no_permission_check]
    #  raise UnauthorizedAction unless user.allowed_to?(:add_issue_notes, issue.project) || user.allowed_to?(:edit_issues, issue.project)
    #  raise UnauthorizedAction unless status.nil? || user.allowed_to?(:edit_issues, issue.project)
    #end

    # add the note
    journal = issue.init_journal(user, cleanup_body(plain_text_body(email)))
    add_attachments(issue,email,user)
    # check workflow
    if status && issue.new_statuses_allowed_to(user).include?(status)
      issue.status = status
    end
    issue.save!
    logger.info "MailHandler: issue ##{issue.id} updated by #{user}" if logger && logger.info
    journal
  end
  
  
  
  def add_attachments(obj,email,user)
    if email.has_attachments?
      email.attachments.each do |attachment|
        Attachment.create(:container => obj,
                          :file => attachment,
                          :author => user,
                          :content_type => attachment.content_type)
      end
    end
  end
  
  
  def target_project
    # TODO: other ways to specify project:
    # * parse the email To field
    # * specific project (eg. Setting.mail_handler_target_project)
    target = Project.find_by_identifier('support')
    raise MissingInformation.new('Unable to determine target project') if target.nil?
    target
  end
  
  
  #  def self.newcase(email, name, issueid)
  # 
  #  uid = genuid
  #  
  #  while Support.find(:id => uid) do
  #    uid = genuid
  #  end
  #  
  #  create(:id => uid, :email => email, :name => name, :issueid => id)  
  #  
  #  return uid
  #end

  # Returns the correct subjecttype
  def build_subject(uid, subject)
    return "[TW-#" + uid + "] " + subject
  end
  
  # Returns the text/plain part of the email
  # If not found (eg. HTML-only email), returns the body with tags removed
  def plain_text_body(email)
    parts = email.parts.collect {|c| (c.respond_to?(:parts) && !c.parts.empty?) ? c.parts : c}.flatten
    if parts.empty?
      parts << email
    end
    plain_text_part = parts.detect {|p| p.content_type == 'text/plain'}
    if plain_text_part.nil?
      # no text/plain part found, assuming html-only email
      # strip html tags and remove doctype directive
      plain_text_body = strip_tags(@email.body.to_s)
      plain_text_body.gsub! %r{^<!DOCTYPE .*$}, ''
    else
      plain_text_body = plain_text_part.body.to_s
    end
    plain_text_body.strip!
    return plain_text_body
  end
  
  # Removes the email body of text after the truncation configurations.
  def cleanup_body(body)
    delimiters = Setting.mail_handler_body_delimiters.to_s.split(/[\r\n]+/).reject(&:blank?).map {|s| Regexp.escape(s)}
    unless delimiters.empty?
      regex = Regexp.new("^(#{ delimiters.join('|') })\s*[\r\n].*", Regexp::MULTILINE)
      body = body.gsub(regex, '')
    end
    return body.strip
  end
  
  def genuid
    return (0..2).map{ ('A'..'Z').to_a[rand(26)] }.join + (0..2).map{ ('0'..'9').to_a[rand(10)] }.join
  end

    
end
