class SupportMailHandler < ActionMailer::Base

  include SupportControlHeader

  class MissingInformation < StandardError; end

  MESSAGE_ID_RE      = %r{^<redmine\.([a-z0-9_]+)\-(\d+)\.\d+\.\d+@}
  SUBJECT_MATCH      = %r{\[TW-#([A-Z]+[0-9]+)\]}
  AUTORESPONSE_MATCH = %r{\[AUTO-#([0-9]+)\]}
  
  attr_accessor :project
  attr_accessor :settings

  def self.receive(raw_mail, options={})
    logger.info "Received mail:\n #{raw_mail}" unless logger.nil?
    mail = TMail::Mail.parse(raw_mail)
    mail.base64_decode
    handler = new
    handler.project  = options['project']
    handler.settings = Setting[:plugin_support]
    handler.receive(mail)
  end

  def receive(email)
    @directives ||= get_directives(email)
    # only receive the mail if the project has the support module enabled.
    if not Project.find_by_identifier(@project).module_enabled?('support')
      logger.error "SupportMailHandler: support module not enabled for #{@project}" if logger && logger.error
      return false
    end
  
    # If this email has already been processed, discard it.
    if not MessageId.find_by_message_id(email.message_id).nil?
      logger.info "SupportMailHandler: duplicate submission for #{email.message_id}" if logger && logger.info
      return false
    end
     
    # Determine the issue id for the email
    # Update that issue with this email
    # Process any relevant control header directives
    issue = determine_issue(email)
    unless issue.nil?
      update_support_issue(issue, email)
      process_directives(issue, @directives)
    end

    return !issue.nil?
  end

  def determine_issue(email)
    @directives ||= get_directives(email)
    references  = [email.in_reply_to, email.references].flatten.compact
    
    # If we are to ignore this email, do so.
    # Else, if there's a directive specifying a valid ticket number, use it.
    # Else, if there's a formatted message-id, use that to determine the issue
    # Else, try and use the referenced messages to determine the issue
    # Else, throw in the towel and create a new issue.
    if @directives.detect { |d| d.to_s =~ X_IGNORE }
      issue = nil
    elsif @directives.detect { |d| d.to_s =~ X_ISSUE_ID }
      issue_id = $1
      begin
        issue = Issue.find(issue_id)
      rescue ActiveRecord::RecordNotFound
        # What I think we should be doing but aren't to support legacy system
        # TODO: enable this when the legacy system is no more
        #email.delete(@settings['mail_header'])
        #get_directives(email)
        #return determine_issue(email)  
        # What we do instead
        issue = create_new_support_issue(email)
      end
      if not Support.isSupportIssue(issue.id)
        email.delete(@settings['mail_header'])
        get_directives(email)
        return determine_issue(email)  
      end
    elsif references.detect {|h| h.to_s =~ MESSAGE_ID_RE}
      object_class, object_id = $1, $2.to_i
      issue_id = case object_class
        when 'journal' then Journal.find(object_id).journalized_id
        when 'issue'   then object_id
        else nil
      end
      issue = Issue.find(issue_id)
    elsif not (related_message = MessageId.find_by_message_id(references, :order => "id desc", :limit => 1)).nil?
      issue = Issue.find(related_message.issue_id)
    else
      issue = create_new_support_issue(email)
    end

    # one way or another, at this point we should have an issue.
    return issue
  end
    
  def create_new_support_issue(email)
    sender  = email.from.to_a.first.to_s.strip
    subject = email.subject
    message = cleanup_body(plain_text_body(email))
    uid     = genuid

    issue = create_issue(email)
    newtracker = Support.new(
      :trackid => uid, 
      :email   => sender, 
      :issueid => issue.id,
      :original_mail_header => save_headers(email)
    )
    newtracker.save!
    
    # Send auto-reply mail to user?
    if not @settings[:auto_newreply].nil?
      mailstatus = SupportMailer.deliver_support_issue_created(issue, save_headers(email))
    end

    return issue
  end
  
  def create_issue(email) 
    user     = User.find_by_login(@settings['login_user']) 
    project  = target_project
    tracker  = project.trackers.find_by_name(@settings['tracker']) || project.trackers.find(:first)
    priority = IssuePriority.find_by_name('normal')
    status   = IssueStatus.find_by_name('new')
    
    # Create the issue
    issue = Issue.new(
      :author   => user, 
      :project  => project, 
      :tracker  => tracker, 
      :priority => priority
    )

    # Hack for the legacy system
    # TODO: remove it (and the legacy system)
    @directives ||= get_directives(email)
    if @directives.detect { |d| d.to_s =~ X_ISSUE_ID }   
      issue.id = $1
    end

    # Check workflow & set status
    if status && issue.new_statuses_allowed_to(user).include?(status)
      issue.status = status
    end
    
    # Set issue subject & description
    issue.subject = email.subject.chomp
    if issue.subject.blank? then issue.subject = '(no subject)' end
    issue.description = "Submitted by #{email.from.to_s}, #{Time.now.strftime("%A %B %e %Y, %l:%M%p")}"
    issue.save!

    logger.info "MailHandler: issue ##{issue.id} created by #{user}" if logger && logger.info
    return issue
  end
  
  def update_support_issue(issue, email)
    status =  IssueStatus.find_by_name('Tildelt')
    user = User.find(:first, :conditions => ["login=?", @settings['login_user']]) 

    # add the note as a journal entry
    journal = issue.init_journal(user, cleanup_body(plain_text_body(email)))
    journal.mail_header = save_headers(email)

    # save the email message-id for tracking purposes
    record_message_id(issue, email)
    
    # Add any attachments
    add_attachments(issue, journal, user, email)

    # check workflow
    if status && issue.new_statuses_allowed_to(user).include?(status)
      issue.status = status
    end

    # if the ticket was previously closed, open it for revisitation
    if issue.status.is_closed?
      new_status = IssueStatus.find_by_name(@settings['revisit_status']) || IssueStatus.find(:first, :conditions => ["is_closed=?", false])
      issue.status = new_status
    end

    issue.save!
    journal.save!
    logger.info "MailHandler: issue ##{issue.id} updated by #{user}" if logger && logger.info
    return journal
  end
  
  def add_attachments(issue, journal, user, email)
    if email.has_attachments?
      email.attachments.each do |attachment|
        Attachment.create(
          :container    => issue,
          :file         => attachment,
          :author       => user,
          :content_type => attachment.content_type
        )
        journal.details << JournalDetail.new(
          :property => 'attachment',
          :prop_key => attachment.id,
          :value    => attachment.filename
        )
      end
    end
  end
  
  # returns the working project
  def target_project
    target = Project.find_by_identifier(@project)
    raise MissingInformation.new('SupportMailHandler: Unable to determine target project') if target.nil?
    return target
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
    uid = (0..2).map{ ('A'..'Z').to_a[rand(26)] }.join + (0..2).map{ ('0'..'9').to_a[rand(10)] }.join
    while Support.find_by_trackid(uid)
      uid = (0..2).map{ ('A'..'Z').to_a[rand(26)] }.join + (0..2).map{ ('0'..'9').to_a[rand(10)] }.join
    end
    return uid
  end

  def save_headers(email)
    header = {}
    email.header.each do |key, value|
      header[key] = value.to_s
    end
    return header
  end

  def record_message_id(issue, email)
    message_id = MessageId.new(:message_id => email.header['message-id'].to_s, :issue_id => issue.id)
    message_id.save
    unless message_id.nil?
      logger.info "MailHandler: message-id #{message_id.message_id} created (issue #{message_id.issue_id}" if logger && logger.info
    else
      logger.info "MailHandler: message-id creation failed (issue #{message_id.issue_id}"
    end
    return message_id
  end

end
