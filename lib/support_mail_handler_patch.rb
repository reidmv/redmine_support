require_dependency 'mail_handler'

module SupportMailHandlerPatch
  def self.included(base)
    base.send(:include, InstanceMethods)
 
    base.class_eval do
      alias_method_chain :recieve, :recieve_support
    end
  end

  module InstanceMethods
    def recieve_with_recieve_support(email)
      @settings ||= Setting[:plugin_support]
      if not email.header[@settings[:mail_header].downcase].nil?
        recieve_support email
      else
        recieve_without_recieve_support email
      end
    end

    def recieve_support(email)
      debugger 
      "hello"
    end
  end
end
