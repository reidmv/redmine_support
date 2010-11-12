# Redmine - project management software
# Copyright (C) 2006-2008  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

require 'redmine'
require 'net/imap'

module SupportPlugin
  module IMAP
    class << self
      def check(imap_options={}, options={})
        @settings = Setting[:plugin_support]

        host         = imap_options[:host]     || @settings[:mailhost]
        username     = imap_options[:username] || @settings[:username]
        password     = imap_options[:password] || @settings[:password]
        port         = imap_options[:port]     || @settings[:mailport]
        ssl          = imap_options[:ssl]      || !@settings[:mailssl].nil?
        imported_dir = imap_options[:imported] || @settings[:imported_dir]
        import_dir   = imap_options[:import]   || 'INBOX'
        
        #imap = Net::IMAP.new(host, port, ssl)
        imap = Net::IMAP.new(host, port, ssl)
        imap.login(username, password) unless username.nil?
        imap.select(import_dir)
        imap.search(['NOT', 'SEEN']).each do |message_id|
          msg = imap.fetch(message_id,'RFC822')[0].attr['RFC822']
          logger.debug "Receiving message #{message_id}\n"  if logger && logger.debug?
          if Supportmail.receive(msg)
            logger.debug "Message #{message_id} successfully received" if logger && logger.debug?
            if imported_dir
              imap.copy(message_id, imported_dir)
            end
            imap.store(message_id, "+FLAGS", [:Seen, :Deleted])
          else
            logger.debug "Message #{message_id} can not be processed" if logger && logger.debug?
            imap.store(message_id, "+FLAGS", [:Seen])
            if imap_options[:move_on_failure]
              imap.copy(message_id, imap_options[:move_on_failure])
              imap.store(message_id, "+FLAGS", [:Deleted])
            end
          end
        end
        imap.expunge
      end
      
      private
      
      def logger
        RAILS_DEFAULT_LOGGER
      end
    end
  end
end
