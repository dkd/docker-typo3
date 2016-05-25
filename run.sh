#!/bin/bash

DB_HOST=${DB_PORT_3306_TCP_ADDR:-${DB_HOST}}
DB_HOST=${DB_1_PORT_3306_TCP_ADDR:-${DB_HOST}}
DB_PORT=${DB_PORT_3306_TCP_PORT:-${DB_PORT}}
DB_PORT=${DB_1_PORT_3306_TCP_PORT:-${DB_PORT}}

if [ "$DB_PASS" = "**ChangeMe**" ] && [ -n "$DB_1_ENV_MYSQL_PASS" ]; then
    DB_PASS="$DB_1_ENV_MYSQL_PASS"
fi

echo "=> Using the following MySQL/MariaDB configuration:"
echo "========================================================================"
echo "      Database Host Address:  $DB_HOST"
echo "      Database Port number:   $DB_PORT"
echo "      Database Name:          $DB_NAME"
echo "      Database Username:      $DB_USER"
echo "========================================================================"
echo "=> Waiting for database ..."

for ((i=0;i<15;i++))
do
    DB_CONNECTABLE=$(mysql -u$DB_USER -p$DB_PASS -h$DB_HOST -P$DB_PORT -e 'status' >/dev/null 2>&1; echo "$?")
    if [[ DB_CONNECTABLE -eq 0 ]]; then
        break
    fi
    sleep 3
done

if [[ $DB_CONNECTABLE -eq 0 ]]; then
    DB_EXISTS=$(mysql -u$DB_USER -p$DB_PASS -h$DB_HOST -P$DB_PORT -e "SHOW DATABASES LIKE '"$DB_NAME"';" 2>&1 |grep "$DB_NAME" > /dev/null ; echo "$?")

    if [[ DB_EXISTS -eq 1 ]]; then
        echo "=> Creating database $DB_NAME"
        RET=$(mysql -u$DB_USER -p$DB_PASS -h$DB_HOST -P$DB_PORT -e "CREATE DATABASE $DB_NAME")
        if [[ RET -ne 0 ]]; then
            echo "Cannot create database for TYPO3"
            exit RET
        fi
        if [ -f /initial_db.sql ]; then
            echo "=> Loading initial database data to $DB_NAME"
            RET=$(mysql -u$DB_USER -p$DB_PASS -h$DB_HOST -P$DB_PORT $DB_NAME < /initial_db.sql)
            if [[ RET -ne 0 ]]; then
                echo "Cannot load initial database data for TYPO3"
                exit RET
            fi
        fi

        echo "=> Done!"
    else
        echo "=> Skipped creation of database $DB_NAME – it already exists."
    fi
else
    echo "Cannot connect to Mysql"
    exit $DB_CONNECTABLE
fi

if [ ! -f /app/typo3conf/LocalConfiguration.php ]
    then
        echo "=> First Start"

        php typo3cms install:setup --non-interactive \
            --database-user-name="admin" \
            --database-host-name="$DB_HOST" \
            --database-port="$DB_PORT" \
            --database-name="$DB_NAME" \
            --database-user-password="$DB_PASS" \
            --database-create=0 \
            --admin-user-name="admin" \
            --admin-password="password" \
            --site-name="TYPO3 Demo Installation"

        echo "Set permissions for /app folder ..."
        chown www-data:www-data -R /app/fileadmin /app/typo3temp /app/uploads /app/typo3conf

        php typo3cms install:generatepackagestates

        echo "=> Prepare Logs"
        mkdir -p /app/typo3temp/logs/
        chown -R www-data:www-data /app/typo3temp
        touch /app/typo3temp/logs/typo3.log

        echo "=> Add cron"
        echo "*/1	*	*	*	*	root bash -c 'source /root/env && cd /tmp/ && /usr/bin/php /app/typo3/cli_dispatch.phpsh scheduler' 2>&1  >> /app/typo3temp/logs/typo3.log" > /etc/cron.d/typo3
        echo "" >> /etc/cron.d/typo3

        #typo3...https://review.typo3.org/#/c/38041/
        sed -i.bak -e "s|!\$this->isImportDatabaseDone()|false|" /app/typo3/sysext/install/Classes/Controller/Action/Step/DatabaseData.php

        echo "=> Support your local devs and regenerate their autoload!"
        composer dump-autoload
fi

if [ -f /var/run/apache2/apache2.pid ]; then
    echo "=> Delete old apache pid"
    rm /var/run/apache2/apache2.pid
fi

echo "=> Tail the log"
tail -F /app/typo3temp/logs/typo3.log &

echo "=> Start cron"
export > /root/env
chmod 444 /root/env
cron

if [ "$ENABLE_XDEBUG" = "**True**" ]; then
    cp /etc/apache2/xdebug-settings.ini /etc/php5/apache2/conf.d/20-xdebug.ini
else
    if [ -f /etc/php5/apache2/conf.d/20-xdebug.ini ]
    then
        rm /etc/php5/apache2/conf.d/20-xdebug.ini
    fi
fi

echo "=> Done! Start Apache"

# Start apache in foreground if no arguments are given
if [ $# -eq 0 ]
then
    if [ "$ALLOW_OVERRIDE" = "**False**" ]; then
        unset ALLOW_OVERRIDE
    else
        sed -i "s/AllowOverride None/AllowOverride All/g" /etc/apache2/apache2.conf
        a2enmod rewrite
    fi

    source /etc/apache2/envvars
    tail -F /var/log/apache2/* &
    exec apache2 -D FOREGROUND
fi
