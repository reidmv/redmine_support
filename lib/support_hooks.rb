require 'support_plugin/support_control_header'

# Simple method to fetch an actionview class ready
# to fetch'n'render views from the current plugin
def get_action_view
  ActionView::Base.new(File.dirname(__FILE__) + '/../app/views/')
end


# Hooks for some handy extra information within redmine
#
class SupportHooks < Redmine::Hook::Listener

  def view_issues_edit_notes_bottom(context={})
    issue   = context[:issue]
    support = Support.getByIssueId(issue.id)
    
    if not support.nil?
      to = support.original_mail_header['from']
      cc = support.original_mail_header['cc']
      control = Setting['plugin_support']['mail_header']
      get_action_view.render(:partial => "issue_edit", :locals => {:to => to, :cc => cc, :control => control});
    end
  end

  def view_issues_show_details_bottom(context={})
    issueid = context[:issue].id
    
    if Support.isSupportIssue(issueid)
      tracker = Support.getByIssueId(issueid)
      get_action_view.render(:partial => "issue_info", :locals => {:trackid => tracker.trackid} );
    end    
  end

  def view_issues_history_journal_top(context={})
    journal = context[:journal]
    if not journal.mail_header.nil?
      get_action_view.render(:partial => "support/journal_header", :locals => {:journal => journal});
    end 
  end

  def controller_issues_edit_after_save(context={})
    send = context[:params]['support_sendmail'] == "doSend"
    if Support.isSupportIssue(context[:issue].id) && send
      unless context[:journal].notes.empty? or not context[:params]['support_control'].empty?
        control = Setting['plugin_support']['mail_header']
        header = {}
        header['to']          = context[:params]['support_to']
        header['cc']          = context[:params]['support_cc']
        header['in-reply-to'] = context[:params]['support_inreplyto']
        header['references']  = context[:params]['support_reference']
        header['from']        = Setting[:plugin_support][:replyto]
        header[control]       = context[:params]['support_control']
        if not header[control].match(/^#{context[:issue].id}(\s|$)/)
          header[control] = context[:issue].id.to_s + " " + header[control]
        end
        context[:journal].mail_header = header
        context[:journal].save!
        mailstatus = SupportMailer.deliver_support_issue_updated(context[:journal])
      end
      
      # This next part is a hack just to keep us in line with the legacy snot
      # way of doing things. I would love to delete this next part. If you
      # are using the web gui you shouldn't be using the X-TTS field directly.
      context[:issue].reload
      handler = Object.new
      handler.extend(SupportControlHeader::InstanceMethods)
      directives = handler.get_directives(mailstatus)
      handler.process_directives(context[:issue], directives)
      
    end
  end

end
