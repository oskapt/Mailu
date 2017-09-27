#!/bin/bash

: ${DOMAIN:=example.com}
: ${HOSTNAME:=mail.${DOMAIN}}
: ${MESSAGE_SIZE_LIMIT:=50000000}
: ${RELAYNETS:=10.42.0.0/16}
: ${RECIPIENT_DELIMITER:="+"}

vars=( 
  DOMAIN 
  HOSTNAME 
  MESSAGE_SIZE_LIMIT 
  RELAYNETS 
  RELAYHOST 
  RECIPIENT_DELIMITER 
)

# Substitute configuration
for VARIABLE in $vars; do
  sed -i "s={{ $VARIABLE }}=${!VARIABLE}=g" /etc/postfix/*.cf
done

# Override Postfix main configuration
if [[ -f /srv/postfix/overrides/postfix.cf ]]; then
  while read line; do
    postconf -e "$line"
  done < /srv/postfix/overrides/postfix.cf
  echo "Loaded '/srv/postfix/overrides/postfix.cf'"
else
  echo "No extra postfix settings loaded because optional '/srv/postfix/overrides/postfix.cf' not provided."
fi

# Override Postfix master configuration
if [[ -f /srv/postfix/overrides/postfix.master ]]; then
  while read line; do
    postconf -Me "$line"
  done < /srv/postfix/overrides/postfix.master
  echo "Loaded '/srv/postfix/overrides/postfix.master'"
else
  echo "No extra postfix settings loaded because optional '/srv/postfix/overrides/postfix.master' not provided."
fi

# Include table-map files
if [[ $(ls -A /srv/postfix/overrides/*.map 2> /dev/null | wc -l ) -gt 0 ]]; then
  cp /srv/postfix/overrides/*.map /etc/postfix/
  postmap /etc/postfix/*.map
  rm /etc/postfix/*.map
  chown root:root /etc/postfix/*.db
  chmod 0600 /etc/postfix/*.db
  echo "Loaded 'map files'"
else
  echo "No extra map files loaded because optional '/srv/postfix/overrides/*.map' not provided."
fi

# Actually run Postfix
[[ -f /var/run/rsyslogd.pid ]] && rm -f /var/run/rsyslogd.pid
[[ -d /srv/postfix/queue ]] || mkdir -p /srv/postfix/queue
chown -R postfix /srv/postfix/queue
/usr/lib/postfix/post-install meta_directory=/etc/postfix create-missing

exec /usr/bin/supervisord -c /etc/supervisord.conf
