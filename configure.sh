#!/bin/bash

BASEDIR=$(dirname "$0")
APP_NAME='zena'

confFile="$HOME/$APP_NAME/create-site.conf"
functionFile="$HOME/$APP_NAME/functions"

source "$functionFile"

checkConfigurationFile
