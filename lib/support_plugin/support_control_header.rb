module SupportControlHeader

  SUBJECT_X_MATCH = %r{\[([^\[\]]+)\]}
  X_ISSUE_ID = /^\s*(\d+)($|\s+)/i
  X_COMP     = /^\s*\d*\s*(CLOSE|RESOLVED|RESOLVE|RESOLV|CLOSED|COMP|COMPLETED|COMPLETE|DONE)($|\s+)/i
  X_ASSIGN   = /^\s*\d*\s*RESP\s+([-a-zA-Z0-9_]+)($|\s+)/i
  X_WATCH    = /^\s*\d*\s*GUARD\s+([-a-zA-Z0-9_]+)($|\s+)/i
  X_FLAG     = /^\s*\d*\s*FLAGS\s+([A-Za-z0-9,]+)($|\s+)/i
  X_IGNORE   = /^\s*\d*\s*IGNORE($|\s+)/i

  def self.included(base)
    base.send(:include, InstanceMethods)
  end

  module InstanceMethods
    def get_directives(email)
      return [] if email.nil?
      settings = Setting['plugin_support']
      control_field = email.header[settings[:mail_header].downcase]
      directives  = []
      directives << control_field.to_s.split(';') unless control_field.nil?
      if email.subject.to_s.match(SUBJECT_X_MATCH) 
        directives << $1.split(';')
      end
      directives.flatten.compact
    end

    def process_directives(issue, directives)
      settings = Setting['plugin_support']

      # X_FLAG
      if directives.detect { |d| d.to_s =~ X_FLAG }
        flags = $1.upcase
        custom_field = CustomField.find_by_name(settings['tags_field'])
        if issue.available_custom_fields.include?(custom_field)
          issue.custom_field_values = { custom_field.id => flags }
          issue.save_custom_field_values
        elsif logger && loger.info
          logger.info "SupportMailHandler: ##{issue.id} not flaggable as #{flags}"
        end
      end

      # X_ASSIGN
      if directives.detect { |d| d.to_s =~ X_ASSIGN }
        user = User.find_by_login($1)
        if issue.assignable_users.include?(user)
          issue.assigned_to = user 
        elsif logger && logger.info
          logger.info "SupportMailHandler: #{user.login} not assignable to ##{issue.id}"
        end
      end
    
      # X_WATCH 
      if directives.detect { |d| d.to_s =~ X_WATCH }
        user = User.find_by_login($1)
        if issue.addable_watcher_users.include?(user)
          issue.add_watcher(user)
        elsif logger && logger.info
          logger.info "SupportMailHandler: #{user.login} not addable as watcher to ##{issue.id}"
        end
      end

      # X_COMP  
      if directives.detect { |d| d.to_s =~ X_COMP }
        new_status = IssueStatus.find_by_name(settings['comp_status']) || IssueStatus.find(:first, :conditions => ["is_closed=?", true])
        issue.status = new_status
      end
      
      issue.save!
      return issue
    end
  end
end
