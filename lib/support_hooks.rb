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
      get_action_view.render(:partial => "issue_edit", :locals => {:to => to, :cc => cc});
    end
  end

  def view_issues_show_details_bottom(context={})
    issueid = context[:issue].id
    
    if Support.isSupportIssue(issueid)
      tracker = Support.getByIssueId(issueid)
      get_action_view.render(:partial => "issue_info", :locals => {:trackid => tracker.trackid} );
    end    
  end

  def controller_issues_edit_after_save(context={})
    if context[:params]['support_sendmail'] == "doSend" 
      header = {}
      header['to']   = context[:params]['support_to']
      header['cc']   = context[:params]['support_cc']
      header['from'] = Setting[:plugin_support][:replyto]
      mailstatus = Supportmail.deliver_issue_updated(context[:issue], context[:journal], header)
    else
      #TODO: add something when you don't send a mail to the user.
    end
  end

end
