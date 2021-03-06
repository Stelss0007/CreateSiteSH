#!/bin/bash

#set -eu

hostType=$1

echo "Create host:"

case $hostType in
  apache) 
      sudo $HOME/zena/create-host-apache.sh $2 $3 $4
  ;;
  
  nginx) 
      sudo $HOME/zena/create-host-nginx.sh $2 $3 $4
  ;;
  
  *)
      echo "Unknown server!"
      echo "Supported servers:"
      echo "  apache"
      echo "  nginx"
  ;;
esac

