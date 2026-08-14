#!/bin/bash


student_menu() {
  sid=$1
  while true; do
    echo ""
    echo "===== Student Panel ====="
    echo "1. Enroll in Courses"
    echo "2. View All Available (Unenrolled) Courses"
    echo "3. View Enrolled Courses"
    echo "4. Drop a Course"
    echo "5. Logout"
    read -p "Choose an option: " ch

    case $ch in
      1) enroll_courses "$sid" ;;
      2) view_unenrolled_courses "$sid" ;;
      3) view_courses "$sid" ;;
      4) drop_course "$sid" ;;
      5) break ;;
      *) echo "Invalid option" ;;
    esac
  done
}



get_enrolled_credits() {
  sid=$1
  total=0
  while IFS=, read -r student_id course_id; do
    if [ "$student_id" = "$sid" ]; then
      credit=$(grep "^$course_id," courses.txt | cut -d',' -f4)
      total=$((total + credit))
    fi
  done < enrollments.txt
  echo $total
}


enroll_courses() {
  sid=$1
  max_credits=10

  echo "===== Available Courses (Not Yet Enrolled) ====="

  # Get all course IDs the student is already enrolled in
  enrolled=$(grep "^$sid," enrollments.txt | cut -d',' -f2)

  # Display only courses not enrolled
  available_courses=()
  while IFS= read -r line; do
    cid=$(echo "$line" | cut -d',' -f1)
    if ! echo "$enrolled" | grep -wq "$cid"; then
      echo "$line"
      available_courses+=("$cid")
    fi
  done < <(tail -n +2 courses.txt)  # skip header if any

  if [ ${#available_courses[@]} -eq 0 ]; then
    echo "You are already enrolled in all available courses."
    return
  fi

  read -p "Enter course IDs to enroll (comma-separated): " input
  IFS=',' read -ra course_ids <<< "$input"

  current_credits=$(get_enrolled_credits "$sid")
  total_price=0
  valid_courses=()

  for cid in "${course_ids[@]}"; do
    # Check if course is available
    if ! [[ " ${available_courses[*]} " =~ " $cid " ]]; then
      echo "Course ID $cid is not available (already enrolled or invalid)."
      continue
    fi

    credit=$(grep "^$cid," courses.txt | cut -d',' -f4)
    price=$(grep "^$cid," courses.txt | cut -d',' -f3)

    if [ -z "$credit" ] || [ -z "$price" ]; then
      echo "Course $cid not found."
      continue
    fi

    new_total_credits=$((current_credits + credit))
    if [ "$new_total_credits" -le "$max_credits" ]; then
      valid_courses+=("$cid")
      current_credits=$new_total_credits
      total_price=$((total_price + price))
    else
      echo "Skipping $cid: would exceed credit limit of $max_credits."
    fi
  done

  if [ ${#valid_courses[@]} -eq 0 ]; then
    echo "No valid courses to enroll."
    return
  fi

  echo "Total price for selected courses: $total_price"
  read -p "Enter payment trx ID (for all selected courses): " trx

  for cid in "${valid_courses[@]}"; do
    echo "$sid,$cid" >> enrollments.txt
    echo "$sid,$cid,$trx,pending" >> payments.txt

    course_name=$(grep "^$cid," courses.txt | cut -d',' -f2)
    echo "[Email Simulation] To: u$sid@cuet.ac.bd"
    echo "You have enrolled in $course_name (Course ID: $cid). Payment pending verification."
  done
}



view_courses() {
  sid=$1
  echo "===== Your Enrolled Courses ====="
  grep "^$sid," payments.txt | grep ",verified$" | cut -d',' -f2 | while read cid; do
    grep "^$cid," courses.txt
  done
}



view_unenrolled_courses() {
  sid=$1
  echo "===== Courses You Have NOT Enrolled ====="

  enrolled=$(grep "^$sid," enrollments.txt | cut -d',' -f2 | sort | uniq)

  while IFS= read -r line; do
    cid=$(echo "$line" | cut -d',' -f1)
    if ! echo "$enrolled" | grep -Fxq "$cid"; then
      echo "$line"
    fi
  done < courses.txt
}

drop_course() {
  sid=$1
  read -p "Enter Course ID to drop: " cid
  grep -v "^$sid,$cid" enrollments.txt > temp.txt && mv temp.txt enrollments.txt
  grep -v "^$sid,$cid" payments.txt > temp.txt && mv temp.txt payments.txt
  echo "Dropped $cid"
}
