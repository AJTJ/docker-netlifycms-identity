FROM golang:1-stretch

ARG MARIADB_PASSWORD=netlifycms
ARG GOTRUE_PASSWORD=netlifycms
ARG DEBIAN_FRONTEND=noninteractive
ARG SHARED_JWT_SECRET="secret-key-shared-between-git-gateway-and-gotrue"
ARG NETLIFY_REPO="gasbuddy/netlify-example"
ARG OPERATOR_TOKEN="super-secret-operator-token"
ARG GITHUB_TOKEN="abcd"
ARG GOTRUE_LOG_LEVEL=DEBUG
ARG ADMIN_EMAIL=nobdody@test.com
ARG ADMIN_PASSWORD="netlifycms"

RUN echo "mariadb-server-5.5 mysql-server/root_password password $MARIADB_PASSWORD" > /root/maria_conf.txt
RUN echo "mariadb-server-5.5 mysql-server/root_password_again password $MARIADB_PASSWORD" >> /root/maria_conf.txt

RUN apt-get update && \
  apt-get -y install software-properties-common dirmngr git make && \
  apt-key adv --recv-keys --keyserver keyserver.ubuntu.com 0xF1656F24C74CD1D8 && \
  add-apt-repository 'deb [arch=amd64,i386,ppc64el] http://mirror.klaus-uwe.me/mariadb/repo/10.3/debian stretch main' && \
  apt-get update && \
  debconf-set-selections /root/maria_conf.txt && \
  rm -f /root/maria_conf.txt && \
  apt-get -y install mariadb-server sqlite3

ENV GOPATH=$HOME/go
ENV PATH="${PATH}:$GOROOT/bin:$GOPATH/bin:/usr/local/go/bin:$GOPATH/src/github.com/netlify/gotrue"
ENV GO111MODULE=on

# GOTRUE CONFIG
ENV GOTRUE_DB_DATABASE_URL="gotrue:$GOTRUE_PASSWORD@tcp(127.0.0.1:3306)/gotrue?parseTime=true&multiStatements=true"
RUN printf "GOTRUE_JWT_SECRET=$SHARED_JWT_SECRET\nGOTRUE_JWT_EXP=3600\n" > /etc/default/gotrue && \
  printf "PORT=8081\nGOTRUE_DB_DRIVER=mysql\nGOTRUE_API_HOST=localhost\nGOTRUE_JWT_AUD=\"\"\n" >> /etc/default/gotrue && \
  printf "GOTRUE_SITE_URL=https://example.com\nGOTRUE_LOG_LEVEL=$GOTRUE_LOG_LEVEL\n" >> /etc/default/gotrue && \
  printf "GOTRUE_OPERATOR_TOKEN=$OPERATOR_TOKEN\nGOTRUE_DISABLE_SIGNUP=true\n" >> /etc/default/gotrue && \
  printf "GOTRUE_SMTP_HOST=\nGOTRUE_SMTP_PORT=25\nGOTRUE_SMTP_USER=\nGOTRUE_SMTP_PASS=\n" >> /etc/default/gotrue && \
  printf "GOTRUE_SMTP_ADMIN_EMAIL=\nGOTRUE_MAILER_SUBJECTS_CONFIRMATION='Welcome to GoTrue'\n" >> /etc/default/gotrue && \
  printf "GOTRUE_MAILER_SUBJECTS_RECOVERY='Reset your GoTrue password'\nGOTRUE_DB_DATABASE_URL=\"$GOTRUE_DB_DATABASE_URL\"\n" >> /etc/default/gotrue && \
  cat /etc/default/gotrue

# GIT-GATEWAY CONFIG
ENV GITGATEWAY_JWT_SECRET=$SHARED_JWT_SECRET
ENV GITGATEWAY_API_HOST=localhost
ENV GITGATEWAY_GITHUB_REPO=$NETLIFY_REPO
ENV GITGATEWAY_ROLES="admin,editor"
ENV GITGATEWAY_GITHUB_ACCESS_TOKEN=$GITHUB_TOKEN
RUN env | grep GITGATEWAY > /etc/default/git-gateway

RUN /etc/init.d/mysql start && \
  mysql -u root -p${MARIADB_PASSWORD} -e "CREATE DATABASE gotrue; CREATE USER 'gotrue'@'localhost' IDENTIFIED BY '""$GOTRUE_PASSWORD""'; GRANT ALL PRIVILEGES ON gotrue.* TO gotrue@localhost; FLUSH PRIVILEGES;" && \
  mkdir -p $GOPATH/src/github.com/netlify && \
  cd $GOPATH/src/github.com/netlify && \
  git clone https://github.com/netlify/gotrue && \
  cd gotrue && \
  make deps && \
  make build && \
  set -a && \
  . /etc/default/gotrue && \
  gotrue migrate && \
  gotrue admin createuser -i 00000000-0000-0000-0000-000000000000 $ADMIN_EMAIL $ADMIN_PASSWORD --superadmin && \
  cd $GOPATH/src/github.com/netlify && \
  git clone https://github.com/netlify/git-gateway.git && \
  cd git-gateway && \
  make deps && \
  make build

COPY git-gateway /etc/init.d/
COPY gotrue /etc/init.d/
COPY entry.sh /root/

RUN apt-get clean && rm -rf /var/lib/apt/lists/*

ENTRYPOINT /root/entry.sh