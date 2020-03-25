#!/bin/sh
. ./.env

service mysql start
# Setup your gotrue/git-gateway db and config based on .env values.
if mysql -u root -p${MARIADB_PASSWORD} gotrue -e "SELECT 1/count(1) FROM users;";
then
  echo "Database appears to be setup already"
  ADMIN_USER_DONE=true
else
  mysql -u root -pnetlifycms -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '""${MARIADB_PASSWORD}""';"
  mysql -u root -p${MARIADB_PASSWORD} -e "CREATE DATABASE gotrue; CREATE USER 'gotrue'@'localhost' IDENTIFIED BY '""$GOTRUEDB_PASSWORD""'; GRANT ALL PRIVILEGES ON gotrue.* TO gotrue@localhost; FLUSH PRIVILEGES;"
fi

GOTRUE_DB_DATABASE_URL="gotrue:$GOTRUEDB_PASSWORD@tcp(127.0.0.1:3306)/gotrue?parseTime=true&multiStatements=true"

printf "export GOTRUE_JWT_SECRET=$JWT_SECRET\n" >> /etc/default/gotrue
printf "export GOTRUE_DB_DATABASE_URL=\"$GOTRUE_DB_DATABASE_URL\"\n" >> /etc/default/gotrue
printf "export GOTRUE_DISABLE_SIGNUP=$DISABLE_SIGNUP\n" >> /etc/default/gotrue
printf "export GOTRUE_LOG_LEVEL=$LOG_LEVEL\n" >> /etc/default/gotrue
printf "export GOTRUE_JWT_EXP=$JWT_EXP\n" >> /etc/default/gotrue
printf "export GOTRUE_JWT_AUD=\"\"\n" >> /etc/default/gotrue
printf "export GOTRUE_SITE_URL=$SITE_URL\n" >> /etc/default/gotrue
printf "export GOTRUE_OPERATOR_TOKEN=$OPERATOR_TOKEN\n" >> /etc/default/gotrue
printf "export GOTRUE_DISABLE_SIGNUP=$DISABLE_SIGNUP\n" >> /etc/default/gotrue
printf "export GOTRUE_SMTP_HOST=$SMTP_HOST\nexport GOTRUE_SMTP_PORT=$SMTP_PORT\nexport GOTRUE_SMTP_USER=$SMTP_USER\nexport GOTRUE_SMTP_PASS=$SMTP_PASS\n" >> /etc/default/gotrue
printf "export GOTRUE_SMTP_ADMIN_EMAIL=$SMTP_ADMIN_EMAIL\n" >> /etc/default/gotrue
printf "export GOTRUE_MAILER_SUBJECTS_CONFIRMATION='"$CONFIRMATION_SUBJECT"'\n" >> /etc/default/gotrue
printf "export GOTRUE_MAILER_SUBJECTS_RECOVERY='"$RECOVERY_SUBJECT"'\n" >> /etc/default/gotrue

for v in `printenv | grep ^GOTRUE_EXTERNAL`
do
    printf "export $v\n" >> /etc/default/gotrue
done

. /etc/default/gotrue && \
  cd /go/src/github.com/netlify/gotrue && \
  gotrue migrate

if [ -z "${ADMIN_USER_DONE}" ]
then
  gotrue admin createuser -i 00000000-0000-0000-0000-000000000000 $ADMIN_EMAIL $ADMIN_PASSWORD --superadmin;
fi

printf "export GITGATEWAY_JWT_SECRET=$JWT_SECRET\n" >> /etc/default/git-gateway
printf "export GITGATEWAY_GITHUB_REPO=$NETLIFY_REPO\n" >> /etc/default/git-gateway
if [ -n "${GATEWAY_ROLES}" ]
then
  printf "export GITGATEWAY_ROLES=\"$GATEWAY_ROLES\"\n" >> /etc/default/git-gateway
fi
printf "export GITGATEWAY_GITHUB_ACCESS_TOKEN=$GITHUB_TOKEN\n" >> /etc/default/git-gateway

if [ -n "${SITE_URL}" ]
then
  SITE_HOST=`echo $SITE_URL | awk -F[/:] '{print $4}'`
  sed -i "s/example.com/$SITE_HOST/g" /etc/nginx/sites-enabled/default
fi

mysql -u gotrue -p${GOTRUEDB_PASSWORD} gotrue -e "update users set confirmed_at = NOW();"
sed -i "s/GIT_CONTENT_BRANCH/${GIT_CONTENT_BRANCH:-master}/g" /usr/share/nginx/html/config.yml

echo "Setup complete"
rm /root/.env

cd /root
./entry.sh