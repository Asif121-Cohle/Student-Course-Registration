#!/usr/bin/env bats
# Functional tests for the course registration scripts.
# Run from repo root: bats tests/functional_test.bats

setup() {
  SRC_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
  FIXTURES="$SRC_DIR/tests/fixtures"

  # Fresh sandbox per test so scripts can freely mutate .txt files
  WORKDIR="$(mktemp -d)"
  cp "$SRC_DIR"/*.sh "$WORKDIR"/
  cp "$FIXTURES"/*.txt "$WORKDIR"/
  cd "$WORKDIR"
}

teardown() {
  rm -rf "$WORKDIR"
}

# ---------- SYNTAX ----------

@test "all scripts pass bash -n syntax check" {
  for f in admin.sh auth.sh main.sh student.sh; do
    run bash -n "$f"
    [ "$status" -eq 0 ]
  done
}

# ---------- ADMIN: add_course ----------

@test "add_course appends a well-formed course line" {
  run bash -c '
    source admin.sh
    printf "CSE201\nNew Course\n900\n3\n" | add_course
  '
  [ "$status" -eq 0 ]
  grep -q "^CSE201,New Course,900,3$" courses.txt
}

# ---------- ADMIN: add_student rejects duplicate ID ----------

@test "add_student rejects a duplicate student ID and retries" {
  run bash -c '
    source admin.sh
    printf "101\n999\nnewuser\nnewpass\n" | add_student
  '
  [ "$status" -eq 0 ]
  # 101 already exists in fixtures -> must not create a second line for 101
  [ "$(grep -c "^101," users.txt)" -eq 1 ]
  grep -q "^999,newuser,newpass,student$" users.txt
}

# ---------- ADMIN: admin_view_courses / admin_view_students ----------

@test "admin_view_courses lists every course from courses.txt" {
  run bash -c 'source admin.sh; admin_view_courses'
  [ "$status" -eq 0 ]
  [[ "$output" == *"CSE101"* ]]
  [[ "$output" == *"CSE102"* ]]
  [[ "$output" == *"CSE103"* ]]
}

@test "admin_view_students only lists role=student rows" {
  run bash -c 'source admin.sh; admin_view_students'
  [ "$status" -eq 0 ]
  [[ "$output" == *"alice"* ]]
  [[ "$output" != *"admin1"* ]]
}

# ---------- ADMIN: verify_payment ----------

@test "verify_payment marks a pending trx as verified on approval" {
  run bash -c '
    source admin.sh
    printf "TRX001\ny\n" | verify_payment
  '
  [ "$status" -eq 0 ]
  grep -q "^101,CSE101,TRX001,verified$" payments.txt
}

@test "verify_payment removes enrollment on rejection" {
  run bash -c '
    source admin.sh
    printf "TRX001\nn\n" | verify_payment
  '
  [ "$status" -eq 0 ]
  ! grep -q "^101,CSE101$" enrollments.txt
  ! grep -q "^101,CSE101,TRX001,pending$" payments.txt
}

@test "verify_payment reports unknown/already-verified trx cleanly" {
  run bash -c '
    source admin.sh
    printf "DOES_NOT_EXIST\n" | verify_payment
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"not found"* ]]
}

# ---------- STUDENT: get_enrolled_credits ----------

@test "get_enrolled_credits sums credits for the given student only" {
  run bash -c 'source student.sh; get_enrolled_credits 101'
  [ "$status" -eq 0 ]
  # 101 is enrolled in CSE101 (credit 3) only
  [ "$output" -eq 3 ]
}

@test "get_enrolled_credits returns 0 for a student with no enrollments" {
  run bash -c 'source student.sh; get_enrolled_credits 102'
  [ "$status" -eq 0 ]
  [ "$output" -eq 0 ]
}

# ---------- STUDENT: view_unenrolled_courses ----------

@test "view_unenrolled_courses excludes courses the student already has" {
  run bash -c 'source student.sh; view_unenrolled_courses 101'
  [ "$status" -eq 0 ]
  [[ "$output" != *"CSE101,"* ]]
  [[ "$output" == *"CSE102"* ]]
}

# ---------- STUDENT: drop_course ----------

@test "drop_course removes the enrollment and payment rows" {
  run bash -c '
    source student.sh
    printf "CSE101\n" | drop_course 101
  '
  [ "$status" -eq 0 ]
  ! grep -q "^101,CSE101$" enrollments.txt
  ! grep -q "^101,CSE101," payments.txt
}

# ---------- AUTH: login ----------

@test "login accepts valid admin credentials and routes to admin_menu" {
  run bash -c '
    admin_menu() { echo "ADMIN_MENU_REACHED"; }
    student_menu() { echo "STUDENT_MENU_REACHED"; }
    source auth.sh
    printf "admin1\nadminpass\n" | login
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"Login successful"* ]]
  [[ "$output" == *"ADMIN_MENU_REACHED"* ]]
}

@test "login routes a student account to student_menu" {
  run bash -c '
    admin_menu() { echo "ADMIN_MENU_REACHED"; }
    student_menu() { echo "STUDENT_MENU_REACHED"; }
    source auth.sh
    printf "alice\nalicepass\n" | login
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"STUDENT_MENU_REACHED"* ]]
}

@test "login rejects invalid credentials" {
  run bash -c '
    admin_menu() { echo "ADMIN_MENU_REACHED"; }
    student_menu() { echo "STUDENT_MENU_REACHED"; }
    source auth.sh
    printf "alice\nwrongpass\n" | login
  '
  [ "$status" -eq 0 ]
  [[ "$output" == *"Invalid credentials"* ]]
  [[ "$output" != *"MENU_REACHED"* ]]
}
