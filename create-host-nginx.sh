#!/bin/bash

#set -eu
BASEDIR=$(dirname "$0")

echo "Create new NGINX host..."

confFile="$BASEDIR/create-site.conf"

source "$confFile"
source "$BASEDIR/functions"

# Название сайта
name=$1
# Директори гда будет лежать сайт
WEB_ROOT_DIR=$2


function generateVhost() {
echo "
server {
    listen *:$port;

    root $WEB_ROOT_DIR;

    index index.php index.html index.htm index.nginx-debian.html;

    server_name $name;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php5-fpm.sock;
    }

    location ~ /\.ht {
        deny all;
    }
}
" > "$sitesAvailabledomain"
}


# Читаем даные с консоли, если не пердался параметром с консоли
# Если парматр названия сайта не передавался, запросм его
if [ -z "$name" ];  then
  read -p "Enter SiteName (test): " name
  name=${name:-test}
fi


# Предложим путь для директории сайта относительно текущего каталога
newSiteRootDirectory=$sitesRootDirectory$name

#Читаем даные с консоли, если не пердался параметром с консоли
# Если парматр директории сайта не передавался, запросм его
if [ -z "$WEB_ROOT_DIR" ];  then
  read -p "Enter WebRoot directory ($newSiteRootDirectory): " WEB_ROOT_DIR
fi

# Имейл поумолчанию
email="admin@$name"
# Директория где лежат sites-enabled
sitesEnable='/etc/nginx/sites-enabled/'
# Директория где лежат sites-available
sitesAvailable='/etc/nginx/sites-available/'
# Формируем имя конфиг фала VHOST
sitesAvailabledomain=$sitesAvailable$name.conf

# Если нужно создадим запись в файле хоста
# закоментировать если мы делаем проброс на роутере
sed -i "1s/^/127.0.0.1 $name\n/" /etc/hosts

# Бросим меседж о начале создания файла хоста
echo "Creating a vhost for $sitesAvailabledomain with a webroot $WEB_ROOT_DIR"

# Если параметр $WEB_ROOT_DIR не пустой, создадим директорию, если ее нет, 
# установим права и назанчим пользователя и групу 
if [ -z "$WEB_ROOT_DIR" ];  then
  mkdir -p -m 0755 $newSiteRootDirectory
  WEB_ROOT_DIR=$newSiteRootDirectory
fi

echo $WEB_ROOT_DIR

###################################################
# Создаем virtual host с правилами
generateVhost
###################################################


echo -e 
coloredEcho 'New Nginx Virtual Host Created' green
echo -e 


# Енейблим наш новый сайт
if [ ! -f $sitesEnable$name.conf ]
then
    echo "Generate nginx conf file..."
    sudo ln -s  $sitesAvailabledomain $sitesEnable$name.conf
fi
# Рестартуем NGINX
echo "Restart nginx"
sudo service nginx restart

if [ "$port" = "80" ]; then
  siteUrl="http://$name/"
else 
  siteUrl="http://$name:$port/"
fi


sitePath=$WEB_ROOT_DIR

# Все готово, выводим соответствующий меседж
echo -e
echo "Done, your host was created at path: $sitePath,"
echo "please browse to $siteUrl to check!"

echo -e
