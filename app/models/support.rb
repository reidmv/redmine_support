class Support < ActiveRecord::Base

  serialize :original_mail_headers  
  
#  def self.getIssueid(trackid)
#    row = find(:id => trackid)
#    
#  end

  def self.getByIssueId(issueid)
    row = self.find(:first, :conditions => "issueid = #{issueid}")
    return row
  end

  def self.getTrackid(issueid)
    row = self.getByIssueId(issueid)
    
    return row.trackid;
  end

  def self.isSupportIssue(issueid)
    if self.count(:conditions => "issueid = #{issueid}") > 0 
      return true
    else
      return false
    end
  end
  
  
  
end
