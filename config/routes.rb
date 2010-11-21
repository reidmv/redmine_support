ActionController::Routing::Routes.draw do |map|
  map.connect 'support/:project', :controller => 'mail_handler', :action => 'support'
end
