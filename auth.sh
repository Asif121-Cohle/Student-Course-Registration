#!/bin/bash

login() {
  echo "----- Login -----"
  read -p "Username: " username
  read -p "Password: " password
  echo

  user_line=$(grep ",$username,$password," users.txt)

  if [ -n "$user_line" ]; then
    user_id=$(echo "$user_line" | cut -d',' -f1)
    role=$(echo "$user_line" | cut -d',' -f4)

    echo "Login successful! Logged in as $role"
    if [ "$role" = "admin" ]; then
      admin_menu
    else
      student_menu "$user_id"
    fi
  else
    echo "Invalid credentials"
  fi
}
