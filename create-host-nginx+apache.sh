#!/bin/bash

#set -eu
BASEDIR=$(dirname "$0")

echo "Create new NGINX+Apache host..."

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
		server_name $name;

    		location / {
    			proxy_pass http://127.0.0.1:8080/;
    			proxy_redirect off;
    			proxy_set_header Host \$host;
    			proxy_set_header X-Real-IP \$remote_addr;
    			proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    			client_max_body_size 40m;
    			client_body_buffer_size 256k;

    			proxy_connect_timeout 120;
    			proxy_send_timeout 120;
    			proxy_read_timeout 120;
    			proxy_buffer_size 64k;
    			proxy_buffers 4 64k;
    			proxy_busy_buffers_size 64k;
    			proxy_temp_file_write_size 64k;
    			proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    		}
    		#Static files location
    		location ~* ^.+.(jpg|jpeg|gif|png|ico|css|zip|tgz|gz|rar|bz2|doc|xls|exe|pdf|ppt|txt|tar|mid|midi|wav|bmp|rtf|js|html|flv|mp3)\$
    		{
     		    root $WEB_ROOT_DIR;
    	    }
		}" > "$sitesAvailabledomain"
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
