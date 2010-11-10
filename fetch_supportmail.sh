#/usr/local/bin/rake -f 

LOCKFILE=/var/www/redmine/vendor/plugins/support/lockfile

if [ -f $LOCKFILE ]; then
  echo " Lockfile exists, goodbye.."
  exit 1;
fi

touch $LOCKFILE


/usr/bin/rake -f /var/www/redmine/Rakefile \
  tw_support:email:receive_imap \
  RAILS_ENV=production \
  --trace

rm $LOCKFILE

