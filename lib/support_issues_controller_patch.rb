require_dependency 'issues_controller'

module SupportIssuesControllerPatch
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
      begin
        if journal
          user = journal.mail_header['from']
          text = journal.notes
          date = journal.created_on
        elsif Support.getByIssueId(@issue.id);
          user = Support.getByIssueId(@issue.id).original_mail_header['from']
          text = @issue.description
          date = @issue.created_on
        end
      rescue NoMethodError
        user = @issue.author
        text = @issue.description
        date = @issue.created_on
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
      unless homedir_path.empty? || signature_file.empty?
        begin
          sigfile = File.open("#{homedir_path}/#{User.current.login}/#{signature_file}", "rb")
          content << "\n\n" + sigfile.read unless sigfile.nil?
          sigfile.close
        rescue SystemCallError
          # we don't care if the file doesn't exist
        end
      end

      render(:update) { |page|
        page.<< "$('notes').value = \"#{escape_javascript content}\";"
        page.show 'update'
        page << "Form.Element.focus('notes');"
        page << "Element.scrollTo('update');"
        page << "$('notes').scrollTop = $('notes').scrollHeight - $('notes').clientHeight;"
      } 
    end
  end
end

IssuesController.send(:include, SupportIssuesControllerPatch)
