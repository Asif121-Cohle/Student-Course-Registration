#!/bin/bash

admin_menu() {
  while true; do
    echo ""
    echo "===== Admin Panel ====="
    echo "1. Add Student"
    echo "2. Remove Student"
    echo "3. Add Course"
    echo "4. Remove Course"
    echo "5. View All Students"
    echo "6. View All Courses"
    echo "7. View Registrations"
    echo "8. View Payments"
    echo "9. Verify Payment"
    echo "10. Logout"
    read -p "Choose an option: " ch

    case $ch in
      1) add_student ;;
      2) remove_student ;;
      3) add_course ;;
      4) remove_course ;;
      5) admin_view_students ;;
      6) admin_view_courses ;;
      7) cat enrollments.txt ;;
      8) cat payments.txt ;;
      9) verify_payment ;;
      10) break ;;
      *) echo "Invalid option" ;;
    esac
  done
}

add_student() {
  while true; do
    read -p "Enter student ID: " sid
    # Check if ID already exists
    if grep -q "^$sid," users.txt; then
      echo "Student ID already exists. Please try a different one."
    else
      break
    fi
  done

  while true; do
    read -p "Enter student username: " uname
    # Check if username already exists (across all users)
    if cut -d',' -f2 users.txt | grep -qw "$uname"; then
      echo "Username already exists. Please choose another."
    else
      break
    fi
  done

  read -s -p "Enter password: " pass
  echo ""

  echo "$sid,$uname,$pass,student" >> users.txt
  echo "Student added with ID: $sid"
}


remove_student() {
  read -p "Enter student ID to remove: " sid
  grep -v "^$sid," users.txt > temp.txt && mv temp.txt users.txt
  grep -v "^$sid," enrollments.txt > temp.txt && mv temp.txt enrollments.txt
  grep -v "^$sid," payments.txt > temp.txt && mv temp.txt payments.txt
  echo "Student $sid removed"
}

add_course() {
  read -p "Course ID: " cid
  read -p "Course Name: " cname
  read -p "Course Price: " price
  read -p "Course Credit: " credit
  echo "$cid,$cname,$price,$credit" >> courses.txt
  echo "Course added!"
}

remove_course() {
  read -p "Enter Course ID to remove: " cid
  grep -v "^$cid," courses.txt > temp.txt && mv temp.txt courses.txt
  grep -v ",$cid" enrollments.txt > temp.txt && mv temp.txt enrollments.txt
  grep -v ",$cid," payments.txt > temp.txt && mv temp.txt payments.txt
  echo "Course $cid removed"
}

admin_view_students() {
  echo "===== Registered Students ====="
  awk -F',' '$4 == "student" { print "ID: "$1", Username: "$2 }' users.txt
}

admin_view_courses() {
  echo "===== Available Courses ====="
  awk -F',' 'NR > 1 { print "ID: "$1", Name: "$2", Price: "$3", Credit: "$4 }' courses.txt
}

verify_payment() {
  read -p "Enter trx ID to verify: " trx

  match=$(grep ",$trx,pending" payments.txt)

  if [ -z "$match" ]; then
    echo "Transaction not found or already verified."
    return
  fi

  sid=$(echo "$match" | cut -d',' -f1)
  cid=$(echo "$match" | cut -d',' -f2)
  course_name=$(grep "^$cid," courses.txt | cut -d',' -f2)

  echo "Transaction found for Student ID: $sid, Course: $course_name"
  read -p "Approve payment? (y/n): " confirm

  if [[ "$confirm" == "y" ]]; then
    # Replace line exactly
    sed -i "s/^$sid,$cid,$trx,pending\$/$sid,$cid,$trx,verified/" payments.txt

    # Simulate email
    echo "[Email Simulation] To: u$sid@cuet.ac.bd"
    echo "Subject: Payment Verified"
    echo "Your payment for course $course_name (Course ID: $cid) has been verified. Enrollment complete!"
    echo "--------------------------------------------------------"
  else
    # Remove from both files
    grep -v "^$sid,$cid" enrollments.txt > temp.txt && mv temp.txt enrollments.txt
    grep -v "^$sid,$cid,$trx," payments.txt > temp.txt && mv temp.txt payments.txt
    echo "Payment rejected and enrollment removed."
  fi
}



