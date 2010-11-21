require_dependency 'mail_handler_controller'

module SupportMailHandlerControllerPatch
  def self.included(base)
    base.send(:include, InstanceMethods)
  end

  module InstanceMethods
    def support
      options = params.dup
      email = options.delete(:email)
      if SupportMailHandler.receive(email, options)
        render :nothing => true, :status => :created
      else
        render :nothing => true, :status => :unprocessable_entity
      end
    end
  end
end

MailHandlerController.send(:include, SupportMailHandlerControllerPatch)
