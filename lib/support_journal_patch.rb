require_dependency 'journal'

module SupportJournalPatch
  def self.included(base)
    base.class_eval do
      serialize :mail_header, Hash
    end
  end
end

Journal.send(:include, SupportJournalPatch)
