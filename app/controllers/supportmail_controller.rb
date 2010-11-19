class SupportmailController < ApplicationController

  before_filter   :authorize, :only => [:test]
  accept_key_auth :index, :test, :recieve

  def index
    respond_to do |format|
      format.html { render :nothing => true }
    end
  end
  
  def test
    respond_to do |format|
      format.html { render :nothing => true }
    end
  end
  
  def recieve
    respond_to do |format|
      format.html { render :nothing => true }
    end
  end
  
end
