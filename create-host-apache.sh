#!/bin/bash

#set -eu
BASEDIR=$(dirname "$0")

echo "Create new Apache host..."

confFile="$BASEDIR/create-site.conf"

source "$confFile"
source "$BASEDIR/functions"

# Название сайта
name=$1
# Директори гда будет лежать сайт
WEB_ROOT_DIR=$2


function generateVhost() {
echo "
<VirtualHost *:$port>
  ServerName $name
  DocumentRoot $WEB_ROOT_DIR
  ServerAdmin $email
  
  <Directory $WEB_ROOT_DIR >
    Options -Includes -Indexes -ExecCGI
    AllowOverride All
    Require all granted
  </Directory>
</VirtualHost>" > "$sitesAvailabledomain"
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
sitesEnable='/etc/apache2/sites-enabled/'
# Директория где лежат sites-available
sitesAvailable='/etc/apache2/sites-available/'
# Формируем имя конфиг фала VHOST
sitesAvailabledomain=$sitesAvailable$name.conf

# Если нужно создадим запись в файле хоста
# закоментировать если мы делаем проброс на роутере
sed -i "1s/^/127.0.0.1 $name\n/" /etc/hosts

# Бросим меседж о начале создания файла хоста
echo "Creating a vhost for $sitesAvailabledomain with a webroot {$WEB_ROOT_DIR}"

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
coloredEcho 'New Virtual Host Created' green
echo -e 


# Енейблим наш новый сайт
a2ensite $name
# Рестартуем Апач
service apache2 reload

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
