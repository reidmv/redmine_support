require_dependency 'application_helper'

module SupportApplicationHelperPatch
  def self.included(base)
    base.send(:include, InstanceMethods)
 
    base.class_eval do
      alias_method_chain :textilizable, :textilizable_support
  
      # We override this because we don't want support issues to be parsed by
      # RedCloth3. Email contains all kinds of things that shouldn't be parsed. 
      # I'm overriding it here 'cause I can't figure out how to define it in
      # a module and have it work correctly. Need to brush up on ruby methinks.
      def textilizable_support(*args)
        options = args.last.is_a?(Hash) ? args.pop : {}
        case args.size
        when 1
          obj = options[:object]
          text = args.shift
        when 2
          obj = args.shift
          attr = args.shift
          text = obj.send(attr).to_s
        else
          raise ArgumentError, 'invalid arguments to textilizable'
        end
        return '' if text.blank?
        project = options[:project] || @project || (obj && obj.respond_to?(:project) ? obj.project : nil)
        only_path = options.delete(:only_path) == false ? false : true

        # This is the real edit. We don't take Setting.text_formatting, but
        # instead just use "none".
        text = Redmine::WikiFormatting.to_html('none', text, :object => obj, :attribute => attr) { |macro, args| exec_macro(macro, obj, args) }

        parse_non_pre_blocks(text) do |text|
          [:parse_inline_attachments, :parse_wiki_links, :parse_redmine_links].each do |method_name|
            send method_name, text, project, obj, attr, only_path, options
          end
        end
      end
    end
  end

  module InstanceMethods
    def textilizable_with_textilizable_support(*args)
      if Support.isSupportIssue(@issue.id) 
        textilizable_support *args
      else
        textilizable_without_textilizable_support *args
      end
    end
  end
end

ApplicationHelper.send(:include, SupportApplicationHelperPatch)
