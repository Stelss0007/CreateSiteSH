#!/bin/bash

BASEDIR=$(dirname "$0")
APP_NAME='zena'

functionFile="$HOME/$APP_NAME/functions"

source "$functionFile"

checkConfigurationFile
