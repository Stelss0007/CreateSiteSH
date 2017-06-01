#!/bin/bash

set -e

BASEDIR=$(dirname "$0")

echo "Create site content..."

confFile="$BASEDIR/create-site.conf"

source "$confFile"
source "$BASEDIR/functions"


CURRENT=`pwd`
BASENAME=`basename "$CURRENT"`

#site directory
WEB_ROOT_DIR=$1
#sitename
name=$2



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
                  <?php phpinfo() ?>
                </body>
              </html>
              " > "$WEB_ROOT_DIR/index.php"

              echo -e
              coloredEcho "index.php was created" green
              echo -e
      ;;
      
      3)  
            composer create-project symfony/framework-standard-edition $WEB_ROOT_DIR

            WEB_ROOT_DIR="$WEB_ROOT_DIR/web"

            chmod -R 777 "$WEB_ROOT_DIR/../var/cache" "$WEB_ROOT_DIR/../var/logs" "$WEB_ROOT_DIR/../var/sessions"

            symfonyAppDevFileUpdate
            symfonyBinAddFiles

            if [ -n "$name" ]; then
                echo "Reset Server Config"
                generateVhost
                sudo service apache2 reload
            fi

            siteUrl="http://$name/app_dev.php"
      ;;

      4)

            composer global require 'fxp/composer-asset-plugin:^1.3.1'
            composer create-project --prefer-dist yiisoft/yii2-app-basic $WEB_ROOT_DIR

            WEB_ROOT_DIR="$WEB_ROOT_DIR/web"


            if [ -n "$name" ]; then
                echo "Reset Server Config"
                generateVhost
                sudo service apache2 reload
            fi
      ;;

      5) 
            composer create-project laravel/laravel $WEB_ROOT_DIR '5.0.*' --prefer-dist

            WEB_ROOT_DIR="$WEB_ROOT_DIR/public"

            chmod -R 777 "$WEB_ROOT_DIR/../storage" "$WEB_ROOT_DIR/../bootstrap/cache"

            if [ -n "$name" ]; then
                echo "Reset Server Config"
                generateVhost
                sudo service apache2 reload
            fi
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

            git clone $gitRepo $WEB_ROOT_DIR

            read -p "Set up site root path $WEB_ROOT_DIR/: " rootPath

            if [ -n "$rootPath" ]; then
              WEB_ROOT_DIR="$WEB_ROOT_DIR/$rootPath"
            fi
      ;;

      *) echo "INVALID NUMBER!" ;;
    esac
fi
