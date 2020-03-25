FROM gasbuddy/netlify-gotrue-git-gateway:base-build

RUN mkdir -p /root/mysql-template && cp -r /var/lib/mysql/* /root/mysql-template

COPY env/git-gateway env/gotrue /etc/default/
COPY git-gateway gotrue /etc/init.d/
COPY entry.sh setup.sh .env /root/
COPY index.html config.yml /usr/share/nginx/html/
COPY nginx.conf /etc/nginx/sites-enabled/default

VOLUME /var/lib/mysql

EXPOSE 80/tcp

ENTRYPOINT /root/entry.sh
