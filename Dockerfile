FROM ubuntu:trusty
MAINTAINER Johannes Goslar <jogo@kronberger-spiele.de>
WORKDIR /app

# Install base packages
RUN apt-get update && \
DEBIAN_FRONTEND=noninteractive apt-get -yq install \
apache2 \
curl \
git \
imagemagick \
libapache2-mod-php5 \
mysql-client \
php-apc \
php-pear \
php5-curl \
php5-gd \
php5-imagick \
php5-mcrypt \
php5-mysql \
php5-xdebug \
&& \
rm -rf /var/lib/apt/lists/* && \
curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
RUN /usr/sbin/php5enmod mcrypt
RUN echo "ServerName localhost" >> /etc/apache2/apache2.conf && \
sed -i "s/variables_order.*/variables_order = \"EGPCS\"/g" /etc/php5/apache2/php.ini

ADD run.sh /run.sh
RUN chmod 755 /run.sh

RUN a2enmod rewrite
ADD typo3.conf /etc/apache2/sites-enabled/000-default.conf

ADD typo3.php.ini /etc/php5/conf.d/

RUN rm -fr /app && mkdir /app && rm -r /var/www/html && ln -s /app /var/www/html
VOLUME [ "/app/uploads", "/app/fileadmin"]

RUN rm /etc/php5/apache2/conf.d/20-xdebug.ini
ADD xdebug-settings.ini /etc/apache2/xdebug-settings.ini

ENV DB_HOST **LinkMe**
ENV DB_PORT **LinkMe**
ENV DB_NAME typo3
ENV DB_USER admin
ENV DB_PASS **ChangeMe**
ENV INSTALL_TOOL_PASSWORD password
ENV ALLOW_OVERRIDE **False**

EXPOSE 80
CMD ["/bin/bash", "-c", "/run.sh"]

ADD AdditionalConfiguration.php /app/typo3conf/

ADD composer.json /app/
ADD composer.lock /app/
RUN composer install && cp typo3conf/ext/typo3_console/Scripts/typo3cms .
