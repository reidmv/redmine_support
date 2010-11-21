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
    # signature into the reply field. 
    def reply_signature
      journal = Journal.find(params[:journal_id]) if params[:journal_id]
      support = Support.getByIssueId(@issue.id); 

      # Things are different if it's a reply or a reply to a reply
      if not journal.nil?
        header = journal.mail_header
        text = journal.notes
        date = journal.created_on
      elsif not support.nil?
        header = support.original_mail_header
        text = @issue.description
        date = @issue.created_on
      end

      # Set the potential recpients of email
      unless header.nil?
        user = header['from']
        cc   = header['cc']
      else
        user = cc = nil
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
        page.show 'update'
        page << "Form.Element.focus('notes');"
        page << "Element.scrollTo('update');"
        page << "$('notes').scrollTop = $('notes').scrollHeight - $('notes').clientHeight;"
      } 
    end
  end
end

IssuesController.send(:include, SupportPatchIssuesController)
