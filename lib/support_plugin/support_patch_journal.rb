require_dependency 'journal'

module SupportPatchJournal
  def self.included(base)
    base.class_eval do
      serialize :mail_header, Hash
    end
  end
end

Journal.send(:include, SupportPatchJournal)
