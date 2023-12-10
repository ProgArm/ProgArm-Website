FROM httpd:2.4.58

RUN apt-get update
RUN apt-get install -y libcgi-pm-perl libcapture-tiny-perl libdatetime-perl libcapture-tiny-perl libgeo-ip-perl
RUN apt-get install -y libcrypt-rijndael-perl libcrypt-random-seed-perl

COPY ./httpd.conf /usr/local/apache2/conf/httpd.conf-extra
RUN cat /usr/local/apache2/conf/httpd.conf-extra >> /usr/local/apache2/conf/httpd.conf

COPY ./htdocs/  /usr/local/apache2/htdocs/
COPY ./cgi-bin/ /usr/local/apache2/cgi-bin/
COPY ./config/  /usr/local/apache2/config/
COPY ./config-private/ /usr/local/apache2/config-private/

# Set permissions to www-data, there's seems to be no other way to do that
RUN sed -i 's/^exec /chown -R www-data:www-data \/srv\/data \/srv\/data-private\n\nexec /' /usr/local/bin/httpd-foreground
