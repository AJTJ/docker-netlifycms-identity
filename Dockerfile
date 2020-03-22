FROM debian:stretch-slim

ARG DEBIAN_FRONTEND=noninteractive
ARG NETLIFY_REPO="gasbuddy/netlify-example"
ARG OPERATOR_TOKEN="super-secret-operator-token"
ARG GITHUB_TOKEN="abcd"
ARG GOTRUE_LOG_LEVEL=DEBUG
ARG ADMIN_EMAIL=nobdody@test.com
ARG ADMIN_PASSWORD="netlifycms"

ENV GOROOT=/usr/local/go
ENV GOPATH=$HOME/go
ENV PATH="${PATH}:$GOROOT/bin:$GOPATH/bin:/usr/local/go/bin:$GOPATH/src/github.com/netlify/gotrue"
ENV GO111MODULE=on

COPY gotrue.env /etc/default/gotrue
COPY git-gateway.env /etc/default/git-gateway
COPY git-gateway /etc/init.d/
COPY gotrue /etc/init.d/
COPY entry.sh /root/
COPY setup.sh /root/
COPY .env /root/

RUN echo "mariadb-server-5.5 mysql-server/root_password password netlifycms" > /root/maria_conf.txt && \
  echo "mariadb-server-5.5 mysql-server/root_password_again password netlifycms" >> /root/maria_conf.txt && \
  apt-get -q update && \
  apt-get -y -q install software-properties-common dirmngr git wget build-essential vim-tiny nginx && \
  wget -q https://dl.google.com/go/go1.14.1.linux-amd64.tar.gz && \
  tar -xf go1.14.1.linux-amd64.tar.gz && \
  rm -rf go1.14.1.linux-amd64.tar.gz && \
  mv go /usr/local && \
  apt-key adv --recv-keys --keyserver keyserver.ubuntu.com 0xF1656F24C74CD1D8 && \
  add-apt-repository 'deb [arch=amd64,i386,ppc64el] http://mirror.klaus-uwe.me/mariadb/repo/10.3/debian stretch main' && \
  apt-get -q update && \
  debconf-set-selections /root/maria_conf.txt && \
  rm -f /root/maria_conf.txt && \
  apt-get -y install mariadb-server sqlite3 && \
  mkdir -p $GOPATH/src/github.com/netlify && \
  cd $GOPATH/src/github.com/netlify && \
  git clone https://github.com/netlify/gotrue && \
  cd gotrue && \
  make deps && \
  make build && \
  set -a && \
  cd $GOPATH/src/github.com/netlify && \
  git clone --depth 1 https://github.com/netlify/git-gateway.git && \
  cd git-gateway && \
  make deps && \
  make build && \
  apt-get -y remove --purge build-essential wget && \
  apt-get -y autoremove && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/* && \
  rm -rf /usr/local/go && \
  rm -rf /go/pkg

ENTRYPOINT /root/entry.sh