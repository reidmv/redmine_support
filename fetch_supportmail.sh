#/usr/local/bin/rake -f 

if [ -f $LOCKFILE ]; then
  echo " Lockfile exists, goodbye.."
  exit 1;
fi

touch $LOCKFILE


/usr/local/bin/rake -f /path/to/redmine/Rakefile \
  tw_support:email:receive_imap \
  RAILS_ENV="production" \
  host=mail.host.com \
  username=mail_username \
  password=mail_password \
  move_on_success=INBOX.imported

rm $LOCKFILE

