require_dependency 'issues_controller'

module SupportPatchIssuesController
  def self.included(base)
    base.send(:include, InstanceMethods)
 
    base.class_eval do
      alias_method_chain :reply, :reply_signature
    end
  end

  module InstanceMethods
    def reply_with_reply_signature
      if Support.isSupportIssue(@issue.id) 
        reply_signature
      else
        reply_without_reply_signature
      end
    end

    # Adds a signature to the quoted issue
    # We override this whole method because we need to inject a user
    # signature into the rendered reply field. 
    def reply_signature
      journal = Journal.find(params[:journal_id]) if params[:journal_id]
      support = Support.getByIssueId(@issue.id); 

      # All support issues should have journals. If no journal was given, the
      # first journal will be a stand-in.
      if journal.nil?
        journals = @issue.journals
        unless journals.nil?
          journal = journals.sort{ |x,y| x.created_on <=> y.created_on }.first
        end
      end

      # Set email headers and such based on the replyed-to journal
      unless journal.nil?
        text       = journal.notes
        date       = journal.created_on
        user       = journal.mail_header['from']
        cc         = journal.mail_header['cc']
        inreplyto  = journal.mail_header['message-id']
        references = ""
        MessageId.find_all_by_issue_id(@issue.id, :order => 'id asc').each do |mesg|
          references += " " + mesg.message_id
        end
      else
        text = date = user = cc = inreplyto = references = nil
      end

      # Replaces pre blocks with [...]
      date = date.to_s(:db)
      text = text.to_s.strip.gsub(%r{<pre>((.|\s)*?)</pre>}m, '[...]')
      content =  "On #{date}, #{ll(Setting.default_language, :text_user_wrote, user)}\n> "
      content << text.gsub(/(\r?\n|\r\n?)/, "\n> ") + "\n\n"

      # insert a signature, if is support issue and exists
      @settings = Setting[:plugin_support]
      homedir_path   = @settings[:homedir_path]
      signature_file = @settings[:signature_file]
      begin
        unless homedir_path.empty? || signature_file.empty?
            sigfile = File.open("#{homedir_path}/#{User.current.login}/#{signature_file}", "rb")
            content << "\n\n" + sigfile.read unless sigfile.nil?
            sigfile.close
        end
      rescue Exception
        logger.info "IssuesController: unable to insert user signature" if logger && logger.info
      end

      render(:update) { |page|
        page.<< "$('notes').value = \"#{escape_javascript content}\";"
        page.<< "$('support_to').value = \"#{escape_javascript user}\";"
        page.<< "$('support_cc').value = \"#{escape_javascript cc}\";"
        page.<< "$('support_reference').value = \"#{escape_javascript references}\";"
        page.<< "$('support_inreplyto').value = \"#{escape_javascript inreplyto}\";"
        page.show 'update'
        page << "Form.Element.focus('notes');"
        page << "Element.scrollTo('update');"
        page << "$('notes').scrollTop = $('notes').scrollHeight - $('notes').clientHeight;"
      } 
    end
  end
end

IssuesController.send(:include, SupportPatchIssuesController)
