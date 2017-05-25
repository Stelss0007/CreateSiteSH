#!/bin/bash

# Скрипт создания сайта на локальном компе

######################################################
####### Данные для конфигурации скрипта ##############
######################################################

# Здесь нужно настроить под себя

# Мой текущий юзер под которым я работаю, он нужен для того чтобы создавть директории и запускать скрипты от его имени (git, composer)
user='rus'
# Суфикс домена, у меня роутер разворачивает все *.rus.visual на мой IP
domainSufix='.rus.visual'
# Текущая директория
sitesRootDirectory="$(pwd)/"
# Путь к PHPStorm для того чтобы после создания сайта, открыть проэкт
# https://www.jetbrains.com/help/phpstorm/2017.1/working-with-phpstorm-features-from-command-line.html
# Для того чтобы создать command line launcher нужно перейти Tools>Create command-line Launcher и указать path и имя где будет лежать скрипт и нажать Ok.
# Обычно это ~/bin/pstorm
phpStormCLI='~/bin/pstorm'


# Настройки закончились



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

function generateVhost() {
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
}

function symfonyAppDevFileUpdate() {
echo "
<?php

use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\Debug\Debug;

// If you don't want to setup permissions the proper way, just uncomment the following PHP line
// read http://symfony.com/doc/current/setup.html#checking-symfony-application-configuration-and-setup
// for more information
//umask(0000);

// This check prevents access to debug front controllers that are deployed by accident to production servers.
// Feel free to remove this, extend it, or make something more sophisticated.
if ((
        in_array(@\$_SERVER['REMOTE_ADDR'], array('127.0.0.1', 'fe80::1', '::1'))
        &&
        !isset(\$_SERVER['HTTP_CLIENT_IP'])
        &&
        !isset(\$_SERVER['HTTP_X_FORWARDED_FOR'])
    )
        ||
    preg_match('/^192\.168\.\d{1,3}\.\d{1,3}$/', @\$_SERVER['REMOTE_ADDR']) // Ugly, but works)
) {
//pass
} else {
    header('HTTP/1.0 403 Forbidden');
    exit('You are not allowed to access this file. Check '.basename(__FILE__).' for more information.');
} 

/** @var \Composer\Autoload\ClassLoader \$loader */
\$loader = require __DIR__.'/../app/autoload.php';
Debug::enable();

\$kernel = new AppKernel('dev', true);
\$kernel->loadClassCache();
\$request = Request::createFromGlobals();
\$response = \$kernel->handle(\$request);
\$response->send();
\$kernel->terminate(\$request, \$response);

" > $WEB_ROOT_DIR/app_dev.php
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

# Если нужно создадим запись в файле хоста
# закоментировать если мы делаем проброс на роутере
sed -i "1s/^/127.0.0.1 $name\n/" /etc/hosts

# Бросим меседж о начале создания файла хоста
echo "Creating a vhost for $sitesAvailabledomain with a webroot $WEB_ROOT_DIR"

# Если параметр $WEB_ROOT_DIR не пустой, создадим директорию, если ее нет, 
# установим права и назанчим пользователя и групу 
if [ -z "$WEB_ROOT_DIR" ];  then
  mkdir -p -m 0755 $newSiteRootDirectory
  chown -R "$user:$user" $newSiteRootDirectory
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


siteUrl="http://$name/"
sitePath=$WEB_ROOT_DIR


# Предложим сразу создать контент (Создать индекс файл, или установить фреймворк, или клонировать готовый проэкт)
echo -e
read -p "Do you want create site content? (N/y): " createContent
createContent=${createContent:-N}

if [ "$createContent" = "y" -o "$createContent" = "Y" -o "$createContent" = "Yes" -o "$createContent" = "yes" ];  then
    # Проверим директорию на пустоту, если не пустая, знач нельзя добавлять контент
    if [ "$(ls -A $WEB_ROOT_DIR)" ]; then
      echo "Can't create content on new site, $WEB_ROOT_DIR is not Empty"
    else
	# Выведем список предлагаемых варияантов
	echo -e
	echo "What do you want?"
	echo -e
	echo "0.  Cancel creating content"
	echo "1.  Create 'index.html'"
	echo "2.  Create 'index.php'"
	echo "3.  Create 'Symfony 3 Project'"
	echo "4.  Create 'YII 2 Project'"
	echo "5.  Create 'Laravel 5 Project'"
	echo "6.  Create WordPress Project"
	echo "10. Clone  Git Repository"
	
	echo -e
	read -p "Please check: " contentType
	contentType=${contentType:-0}
	
	case $contentType in
	  1) 
	    echo "
	      <html>
		<head></head>
		<body>
		  <h2>It's work!</h2>
		</body>
	      </html>
	      " > "$WEB_ROOT_DIR/index.html"
	      
	      echo -e
	      coloredEcho "index.html was created" green 
	      echo -e
	  ;;
	  
	  2) 
	    echo "
	      <html>
		<head></head>
		<body>
		  <h2>It's work!</h2>
		  <?php
		    echo 'PHP is working fine!';
		  ?>
		</body>
	      </html>
	      " > "$WEB_ROOT_DIR/index.php"
	      
	      echo -e
	      coloredEcho "index.php was created" green 
	      echo -e
	  ;;
	  
	  3)  
	    su rus -c "composer create-project symfony/framework-standard-edition $WEB_ROOT_DIR"
	    
	    WEB_ROOT_DIR="$WEB_ROOT_DIR/web"
	    generateVhost
	    service apache2 reload
	    
	    chmod -R 777 "$WEB_ROOT_DIR/../var/cache" "$WEB_ROOT_DIR/../var/logs" "$WEB_ROOT_DIR/../var/sessions"
	    
	    symfonyAppDevFileUpdate
	    
	    siteUrl="http://$name/app_dev.php"
	  ;;
	  4)
	    su rus -c "composer global require 'fxp/composer-asset-plugin:^1.3.1'"
	    su rus -c "composer create-project --prefer-dist yiisoft/yii2-app-basic $WEB_ROOT_DIR"
	    
	    WEB_ROOT_DIR="$WEB_ROOT_DIR/web"
	    generateVhost
	    service apache2 reload
	  ;;
	  5) 
	    su rus -c "composer create-project laravel/laravel $WEB_ROOT_DIR '5.0.*' --prefer-dist"
	    
	    WEB_ROOT_DIR="$WEB_ROOT_DIR/public"
	    generateVhost
	    service apache2 reload
	    
	    chmod -R 777 "$WEB_ROOT_DIR/../storage" "$WEB_ROOT_DIR/../bootstrap/cache"
	  ;;
	  6) 
	      echo -e
	      echo "Download latest WordPress version."
	      echo -e
	      cd $WEB_ROOT_DIR
	      # Качнем последнюю версию
	      curl -O https://wordpress.org/latest.tar.gz
	      # Рапакуем
	      tar -zxvf latest.tar.gz
	      # Зайдем в директорию и скопируем все в родительскую папку
	      cd wordpress
	      # скопируем все в родительскую папку
	      cp -rf . ..
	      # Вернемся вродительскую директорию
	      cd ..
	      # Грохнем ненужное
	      rm -R wordpress
	      rm -R latest.tar.gz
	  ;;
	  7) echo "seven" ;;
	  8) echo "eight" ;;
	  9) echo "nine" ;;
	  10) 
	    read -p "Repository path: " gitRepo
	    
	    su rus -c "git clone $gitRepo $WEB_ROOT_DIR"
	    
	    read -p "Set up site root path $WEB_ROOT_DIR/: " rootPath
	    
	    if [ -n "$rootPath" ]; then
	      WEB_ROOT_DIR="$WEB_ROOT_DIR/$rootPath"
	    fi
	    
	    generateVhost
	  ;;
	  *) echo "INVALID NUMBER!" ;;
	esac
    fi
else 
    echo -e
    echo 'Created site without content'
    echo -e
fi

# Все готово, выводим соответствующий меседж
echo -e
echo "Done, your site was created at path: $WEB_ROOT_DIR,"
echo "please browse to $siteUrl to check!"

echo -e

# Можем открыть PHPStorm
if [ -n "$phpStormCLI" ]; then
  read -p "Do you want open PHPStorm? (N/y): " openPhpStorm
  if [ "$openPhpStorm" = "y" -o "$openPhpStorm" = "Y" -o "$openPhpStorm" = "Yes" -o "$openPhpStorm" = "yes" ];  then
    su rus -c "$phpStormCLI $sitePath &"
  fi
fi

