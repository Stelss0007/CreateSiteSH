#!/bin/bash

# Скрипт создания сайта на локальном компе



user='rus:rus'
domainSufix='.rus.visual'
sitesRootDirectory="$(pwd)/"

##########################################################################################
### Входные параметры, если их нет то в процессе будет запрос на введение этих значений ##
##########################################################################################

# Название сайта
name=$1
# Директори гда будет лежать сайт
WEB_ROOT_DIR=$2


############################## Функции ############################################

# Функция разукрашка
function coloredEcho(){
    local exp=$1;
    local color=$2;
    if ! [[ $color =~ '^[0-9]$' ]] ; then
       case $(echo $color | tr '[:upper:]' '[:lower:]') in
        black) color=0 ;;
        red) color=1 ;;
        green) color=2 ;;
        yellow) color=3 ;;
        blue) color=4 ;;
        magenta) color=5 ;;
        cyan) color=6 ;;
        white|*) color=7 ;; # white or invalid color
       esac
    fi
    tput setaf $color;
    echo $exp;
    tput sgr0;
}
#####################################################################################


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


# Форимируем имя сайта вмете с суфиксом
name=$name$domainSufix
# Имейл поумолчанию
email=${3-'admin@rus.visual'}
# Директория где лежат sites-enabled
sitesEnable='/etc/apache2/sites-enabled/'
# Директория где лежат sites-available
sitesAvailable='/etc/apache2/sites-available/'
# Формируем имя конфиг фала VHOST
sitesAvailabledomain=$sitesAvailable$name.conf

# Бросим меседж о начале создания файла хоста
echo "Creating a vhost for $sitesAvailabledomain with a webroot $WEB_ROOT_DIR"

# Если параметр $WEB_ROOT_DIR не пустой, создадим директорию, если ее нет, 
# установим права и назанчим пользователя и групу 
if [ -z "$WEB_ROOT_DIR" ];  then
  mkdir -p -m 0755 $newSiteRootDirectory
  chown -R $user $newSiteRootDirectory
  WEB_ROOT_DIR=$newSiteRootDirectory
fi

echo $WEB_ROOT_DIR

###################################################
# Создаем virtual host с правилами
echo "
<VirtualHost *:80>
  ServerName $name
  DocumentRoot $WEB_ROOT_DIR
  ServerAdmin $email
  
  <Directory $WEB_ROOT_DIR >
    Options -Includes -Indexes -ExecCGI
    AllowOverride All
    Require all granted
  </Directory>
</VirtualHost>" > $sitesAvailabledomain
###################################################


echo -e 
coloredEcho 'New Virtual Host Created' green
echo -e 

# Если нужно создадим запись в файле хоста
# закоментировать если мы делаем проброс на роутере

#sed -i "1s/^/127.0.0.1 $name\n/" /etc/hosts

# Енейблим наш новый сайт
a2ensite $name
# Рестартуем Апач
service apache2 reload


# Предложим сразу создать контент (Создать индекс файл, или установить фреймворк, или клонировать готовый проэкт)
echo 'Do you want create site content? (N/Y)'
read -p "Enter SiteName (test): " createContent
createContent=${createContent:-N}

if [ $createContent="y" || $createContent="Y" || $createContent="Yes" || $createContent="yes" ];  then
    # Проверим директорию на пустоту, если не пустая, знач нельзя добавлять контент
    if [ "$(ls -A $DIR)" ]; then
      echo "Can't create content on new site, $DIR is not Empty"
    else
	# Выведем список предлагаемых варияантов
	echo "0. Cancel creating content"
	echo "1. Create 'index.html'"
	echo "2. Create 'index.php'"
	echo "3. Create 'Simfony 3 Project'"
	echo "4. Create 'YII 2 Project'"
	echo "5. Create 'Laravel 5 Project'"
	echo "10. Clone Git Repository"
    fi
else 
    echo -e
    echo 'Created site without content'
    echo -e
fi

# Все готово, выводим соответствующий меседж
echo "Done, your site was created at path: $WEB_ROOT_DIR,"
echo "please browse to http://$name to check!"
