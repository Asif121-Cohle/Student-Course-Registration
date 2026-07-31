#!/bin/bash

source auth.sh
source admin.sh
source student.sh

main_menu() {
  while true; do
    echo "========== Course Registration =========="
    echo "1. Login"
    echo "2. Exit"
    read -p "Choose an option: " choice

    case $choice in
      1) login ;;
      2) echo "Goodbye!"; exit ;;
      *) echo "Invalid option" ;;
    esac
  done
}

main_menu
