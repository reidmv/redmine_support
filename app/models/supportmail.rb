class Supportmail < ActionMailer::Base

  SUBJECT_MATCH      = %r{\[TW-#([A-Z]+[0-9]+)\]}
  AUTORESPONSE_MATCH = %r{\[AUTO-#([0-9]+)\]}

  def receive(email)
    @settings ||= Setting[:plugin_support]
    sender =  email.from.to_a.first.to_s.strip
    subject = email.subject
    message = cleanup_body(plain_text_body(email))
    control = email.header[@settings[:mail_header].downcase].to_s

    # If this is a mail sent by the support system, we only want to track
    # it's message-id; we don't want to duplicate the journal entry
    if control && m = control.match(AUTORESPONSE_MATCH)
      save_message_id(email, m[1]).nil? unless !Issue.exists?(m[1])
      return true
    end

    # If this is a response to an already-tracked message, add it to the 
    # appropriate issue.
    in_reply_to = email.in_reply_to.nil? ? [] : email.in_reply_to 
    references  = email.references.nil?  ? [] : email.references
    all_references = in_reply_to + references
    all_references.each do |reference|
      related_message = MessageId.find_by_message_id(reference)
      if not related_message.nil?
        receive_issue_reply(related_message.issue_id ,email)
        return true
      end  
    end

    # It's not an autoreponse, and we don't have a reference to it in our
    # database. make a new ticket. 
    uid = genuid
    while Support.find_by_trackid(uid)
     uid = genuid
    end
   
    issue = create_issue(email,uid)
    newtracker = Support.new(:trackid => uid, 
                             :email => sender, 
                             :issueid => issue.id,
                             :original_mail_header => save_headers(email))
    newtracker.save!
    message_id = save_message_id email, issue.id
    
    # Send auto-reply mail to user?
    if not @settings[:auto_newreply].nil?
      mailstatus = Supportmail.deliver_issue_created(newtracker, build_subject(uid,subject))
    end

    return true
  end

  # Mail issue_created
  def issue_created(tracker,track_subject)
    @settings ||= Setting[:plugin_support]
    oheaders = tracker.original_mail_headers

    from @settings['replyto']
    
    # Common headers
    headers 'X-Mailer' => 'Redmine',
            'X-Redmine-Host' => Setting.host_name,
            'X-Redmine-Site' => 'Support System',
            'Precedence' => 'bulk',
            @settings[:mail_header] => "[AUTO-##{tracker.issueid}]"
  
    recipients tracker.email
    if oheaders['cc'].nil? || oheaders['cc'].empty?
      cc @settings['replyto'] 
    else 
      cc [ @settings['replyto'], oheaders['cc'] ]
    end
    subject track_subject
    body :trackid => tracker.trackid
    content_type "text/plain"
    body render(:file => "newissue.text.plain.rhtml", :body => body)
  end
  
  # Mail issue_updated
  def issue_updated(issue, journal, header)
    @settings ||= Setting[:plugin_support]
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
  
  def create_issue(email,uid) 
    @settings ||= Setting[:plugin_support]
    user = User.find(:first, :conditions => ["login=?", @settings['login_user']]) 
    project = target_project
    tracker = project.trackers.find_by_name(@settings['tracker']) || project.trackers.find(:first)
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

    # add the note as a journal entry
    journal = issue.init_journal(user, cleanup_body(plain_text_body(email)))

    # save the mail headers in the journal entry
    header = {}
    journal.mail_header = save_headers(email)
    journal.save

    # save the email message-id for tracking purposes
    save_message_id email, issue.id

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
    @settings ||= Setting[:plugin_support]
    # TODO: other ways to specify project:
    # * parse the email To field
    # * specific project (eg. Setting.mail_handler_target_project)
    target = Project.find_by_identifier(@settings['project'])
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

  def save_headers(email)
    header = {}
    header['from'] = email.from_addrs.to_s
    header['to']   = email.to_addrs.to_s
    header['cc']   = email.cc_addrs.to_s
    return header
  end

  def save_message_id(email, issue_id)
    message_id = MessageId.new(:message_id => email.header['message-id'].to_s, :issue_id => issue_id)
    message_id.save
    unless message_id.nil?
      logger.info "MailHandler: message-id #{message_id.message_id} created (issue #{message_id.issue_id}" if logger && logger.info
    else
      logger.info "MailHandler: message-id creation failed (issue #{message_id.issue_id}"
    end
    return message_id
  end


end
