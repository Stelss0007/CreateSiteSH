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

# Путь к PHPStorm для того чтобы после создания сайта, открыть проэкт, если будет пусто то не будет открывать проэкты в IDE
# https://www.jetbrains.com/help/phpstorm/2017.1/working-with-phpstorm-features-from-command-line.html
# Для того чтобы создать command line launcher нужно перейти Tools>Create command-line Launcher и указать path и имя где будет лежать скрипт и нажать Ok.
# Обычно это ~/bin/pstorm

# phpStormCLI='~/bin/pstorm'
phpStormCLI=''


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

function checkPrograms() {

  # Проверим Апач
  if which apache2 >/dev/null; then
      coloredEcho "- Apache2 exists" green
  else
      coloredEcho "- Apache2 does not exist, please install apache2" red
      exit 1
  fi
  
  # Проверим Композер
  if which composer >/dev/null; then
      coloredEcho "- Composer exists" green
  else
      coloredEcho "- Composer does not exist, please install composer" red
      exit 1
  fi
    
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


function symfonyBinAssentsFile() {
echo "
#!/bin/sh

set -e; set -u
. \"\$(dirname \$0)/common\"

write_title \"Cleaning assets\"
rm -f \"\$WEB_DIR/js/\"*
rm -f \"\$WEB_DIR/css/\"*

write_title \"Installing assets\"
exec_console assets:install --symlink \"\$@\"

write_title \"Building assets\"
exec_console assetic:dump \"\$@\"

" > $WEB_ROOT_DIR/../bin/assets
}

function symfonyBinClearCacheFile() {
echo "
#!/bin/sh

set -e; set -u
. \"\$(dirname \$0)/common\"

write_title \"Clearing cache\"
exec_console cache:clear --no-warmup \"\$@\"

" > $WEB_ROOT_DIR/../bin/clear-cache
}


function symfonyBinCommonFile() {
echo "

BIN_DIR=\$(cd \$(dirname \$0) && pwd)
BASE_DIR=\$(cd \"\$BIN_DIR/..\" && pwd)
APP_DIR=\"\$BASE_DIR/app\"
WEB_DIR=\"\$BASE_DIR/web\"
VENDOR_DIR=\"\$BASE_DIR/vendor\"
CONSOLE=\"\$APP_DIR/console\"
UNSAFE_BINS_FLAG=\"\$BASE_DIR/.allow_unsafe_bins\"
COMPOSER_INSTALL_PROD_OPTIONS=\"--no-dev --no-interaction\"
COMPOSER_INSTALL_DEV_OPTIONS=\"\"


cd \$BASE_DIR
[ -f \"\$BASE_DIR/.bin-config\" ] && . \"\$BASE_DIR/.bin-config\"


detect_composer() {
    local env_composer=\"\${COMPOSER_BIN:-}\"

    if [ ! -z \"\$env_composer\" -a -f \"\$env_composer\" -a -x \"\$env_composer\" ]; then
        echo \"\$env_composer\"
        return
    fi

    set +e
    local system_composer=\$(which \"composer\")
    set -e

    if [ ! -z \"\$system_composer\" -a -x \"\$system_composer\" ]; then
        echo \"\$system_composer\"
        return
    fi

    local composer=\"\$BASE_DIR/composer\"

    for composer in \"\$BASE_DIR/composer\" \"\$BASE_DIR/composer.phar\"; do
        if [ -f \"\$composer\" ]; then
            echo \"\$(which php) \$composer\"
            return
        fi
    done
}

COMPOSER=\"\$(detect_composer)\"

unsafe_bin() {
    if [ ! -f \"\$UNSAFE_BINS_FLAG\" ]; then
        echo \"This script (\$0) is unsafe and can lead to data loss. If nevertheless you want to run it, create file '\$UNSAFE_BINS_FLAG'\"
        exit 1
    fi
}

exec_console() {
    cmd=\$1
    shift
    \$CONSOLE \$cmd \"\$@\"
}

exec_bin() {
    bin=\$1
    shift
    \"\$BIN_DIR/\$bin\" \"\$@\"
}

exec_vendor_bin() {
    bin=\$1
    shift
    \"\$VENDOR_DIR/bin/\$bin\" \"\$@\"
}

exec_composer() {
    if [ -z \"\$COMPOSER\" ]; then
        echo \"Can't find composer\"
        exit 1
    fi

    \$COMPOSER \"\$@\"
}

exec_composer_install_prod() {
    exec_composer install \$COMPOSER_INSTALL_PROD_OPTIONS
}

exec_composer_install_dev() {
    exec_composer install \$COMPOSER_INSTALL_DEV_OPTIONS
}

write_title() {
    echo \"======= \$@\"
}

write_line() {
    echo \" * \$@\"
}

read_symfony_parameter() {
    parameters_file=\"\$APP_DIR/config/parameters.yml\"

    if [ ! -f \"\$parameters_file\" ]; then
        return
    fi

    default=\"\${2:-}\"
    parameter=\"\$(cat \"\$parameters_file\" | sed -n \"s/^\s\+\$1:\s*\(.*\)\\$/\1/p\")\"

    if [ \"\$parameter\" = \"null\" ]; then
        parameter=\"\"
    fi

    if [ -z \"\$parameter\" ]; then
        parameter=\"\$default\"
    fi

    echo -n \"\$parameter\"
}

get_switch() {
    if [ ! -z \"\$2\" ]; then
        echo -n \"\$1\$2\"
    fi
}

" > $WEB_ROOT_DIR/../bin/common
}


function symfonyBinDatabaseDumpFile() {
echo "
#!/bin/sh

set -e; set -u
. \"\$(dirname \$0)/common\"




dump_name=\"\${1:-}\"

if [ -z \"\$dump_name\" ]; then
    echo \"You should provide database dump name\"
    exit 1
fi

dump_dir=\"\$BASE_DIR/var/db-dumps\"
dump_file=\"\$dump_dir/\${dump_name}.sql.gz\"

if [ -e \"\$dump_dir\" ]; then
    mkdir -p \"\$dump_dir\"
fi

if [ -f \"\$dump_file\" ]; then
    echo \"Database dump file already exists\"
    exit 1
fi

write_title \"Dumping database to '\$dump_file'\"
mysqldump \\
    \$(get_switch \"-u \" \"\$(read_symfony_parameter database_user root)\") \\
    \$(get_switch \"-p\" \"\$(read_symfony_parameter database_password)\") \\
    \$(get_switch \"-h \" \"\$(read_symfony_parameter database_host localhost)\") \\
    \$(get_switch \"-P \" \"\$(read_symfony_parameter database_port 3306)\") \\
    \"\$(read_symfony_parameter database_name)\" \\
    | gzip -c > \"\$dump_file\"


" > $WEB_ROOT_DIR/../bin/database-dump
}


function symfonyBinDatabaseRebuildFile() {
echo "
#!/bin/sh

set -e; set -u
. \"\$(dirname \$0)/common\"

unsafe_bin


set +e
write_title \"Dropping database\"
exec_console doctrine:database:drop --force --quiet \"\$@\"
set -e

write_title \"Creating database\"
exec_console doctrine:database:create \"\$@\"

write_title \"Updating database schema\"
exec_console doctrine:schema:update --force \"\$@\"

write_title \"Setting all migrations as migrated\"
exec_console doctrine:migrations:version --add --all --no-interaction \"\$@\"

write_title \"Loading fixtures\"
exec_console hautelook_alice:doctrine:fixtures:load --no-interaction --append \"\$@\"

" > $WEB_ROOT_DIR/../bin/dev-database-rebuild
}


function symfonyBinDevInstallFile() {
echo "
#!/bin/sh

set -e; set -u
. \"$(dirname $0)/common\"

unsafe_bin


write_title \"Installing vendors\"
exec_composer_install_dev

write_title \"Creating database\"
exec_console doctrine:database:create \"$@\"

write_title \"Updating database schema\"
exec_console doctrine:schema:update --force \"$@\"

write_title \"Setting all migrations as migrated\"
exec_console doctrine:migrations:version --add --all --no-interaction \"$@\"

write_title \"Loading fixtures\"
exec_console doctrine:fixtures:load --no-interaction --append \"$@\"

exec_bin assets \"$@\"
exec_bin fix-permissions 2> /dev/null

" > $WEB_ROOT_DIR/../bin/dev-install
}

function symfonyBinDevRebuildFile() {
echo "
#!/bin/sh

set -e; set -u
. \"\$(dirname \$0)/common\"

unsafe_bin


write_title \"Installing vendors\"
exec_composer_install_dev

exec_bin clear-cache \"\$@\"
exec_bin dev-database-rebuild \"\$@\"
exec_bin assets \"\$@\"
exec_bin fix-permissions 2> /dev/null

" > $WEB_ROOT_DIR/../bin/dev-rebuild
}


function symfonyBinFixPermissionsFile() {
echo "
#!/bin/sh

set -e; set -u
. \"\$(dirname \$0)/common\"


get_current_user() {
    if [ \"\$(id -u)\" -eq 0 -a ! -z \"\${SUDO_USER:-}\" ]; then
        echo \"\$SUDO_USER\"
    else
        echo \"\$(whoami)\"
    fi
}

set_acl_full() {
    user=\"\$(get_current_user)\"
    set +e
    find \"\$@\" -type d -print0 | xargs -0 setfacl -d -m u:www-data:rwX -m u:\$user:rwX
    find \"\$@\" -print0 | xargs -0 setfacl -m u:www-data:rwX -m u:\$user:rwX
    set -e
}

set_acl_limited() {
    user=\"\$(get_current_user)\"
    set +e
    find \"\$@\" -type d -print0 | xargs -0 setfacl -d -m u:www-data:rX -m u:\$user:rwX
    find \"\$@\" -print0 | xargs -0 setfacl -m u:www-data:rX -m u:\$user:rwX
    set -e
}

remove_acl() {
    setfacl -bR \"\$@\"
}

case \"\${1:-apply}\" in
    apply)
        write_title \"Setting up permissions\"
        set_acl_full \
            \"\$APP_DIR/cache\" \"\$APP_DIR/logs\" \"\$BASE_DIR/var\" \"\$BASE_DIR/web/images\" \"\$BASE_DIR/web/assets\" \\
            \"\$BASE_DIR/web/assets/cache\" \"\$BASE_DIR/web/images\" \"\$BASE_DIR/web/images/blog\" \\
            \"\$BASE_DIR/web/images/job\" \"\$BASE_DIR/web/images/portfolio\" \"\$BASE_DIR/web/images/technology\" \\
    ;;

    remove)
        write_title \"Removing permissions\"
        remove_acl \"\$BASE_DIR\"
    ;;

    *)
        echo \"\$0 Invalid operation\"
    ;;
esac

" > $WEB_ROOT_DIR/../bin/fix-permissions
}



function symfonyBinInstallFile() {
echo "
#!/bin/sh

set -e; set -u
. \"\$(dirname \$0)/common\"

unsafe_bin


write_title \"Installing vendors (without dev packages)\"
exec_composer_install_prod

write_title \"Creating database\"
exec_console doctrine:database:create \"\$@\"

write_title \"Updating database schema\"
exec_console doctrine:schema:update --force \"\$@\"

write_title \"Setting all migrations as migrated\"
exec_console doctrine:migrations:version --add --all --no-interaction \"\$@\"

exec_bin assets \"\$@\"
exec_bin fix-permissions 2> /dev/null

" > $WEB_ROOT_DIR/../bin/fix-permissions
}

function symfonyBinUpdateFile() {
echo "
#!/bin/sh

set -e; set -u
. \"\$(dirname \$0)/common\"


write_title \"Installing vendors (without dev packages)\"
exec_composer_install_prod

exec_bin update-assets-version

exec_bin clear-cache

write_title \"Running migrations\"
exec_console doctrine:migrations:migrate --no-interaction

exec_bin assets
exec_bin fix-permissions 2> /dev/null

write_title \"Warming up cache\"
exec_console cache:warmup


" > $WEB_ROOT_DIR/../bin/fix-permissions
}


function symfonyBinAddFiles() {
  symfonyBinAssentsFile
  symfonyBinClearCacheFile
  symfonyBinCommonFile
  symfonyBinDatabaseDumpFile
  symfonyBinDatabaseRebuildFile
  symfonyBinDevInstallFile
  symfonyBinDevRebuildFile
  symfonyBinFixPermissionsFile
  symfonyBinInstallFile
  symfonyBinUpdateFile
}
#####################################################################################


# Прверим наличие нужного софта
checkPrograms

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
	    su $user -c "composer create-project symfony/framework-standard-edition $WEB_ROOT_DIR"
	    
	    WEB_ROOT_DIR="$WEB_ROOT_DIR/web"
	    generateVhost
	    service apache2 reload
	    
	    chmod -R 777 "$WEB_ROOT_DIR/../var/cache" "$WEB_ROOT_DIR/../var/logs" "$WEB_ROOT_DIR/../var/sessions"
	    
	    symfonyAppDevFileUpdate
	    symfonyBinAddFiles
	    
	    siteUrl="http://$name/app_dev.php"
	  ;;
	  4)
	    su $user -c "composer global require 'fxp/composer-asset-plugin:^1.3.1'"
	    su $user -c "composer create-project --prefer-dist yiisoft/yii2-app-basic $WEB_ROOT_DIR"
	    
	    WEB_ROOT_DIR="$WEB_ROOT_DIR/web"
	    generateVhost
	    service apache2 reload
	  ;;
	  5) 
	    su $user -c "composer create-project laravel/laravel $WEB_ROOT_DIR '5.0.*' --prefer-dist"
	    
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
	    
	    su $user -c "git clone $gitRepo $WEB_ROOT_DIR"
	    
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
    su $user -c "$phpStormCLI $sitePath &"
  fi
fi

