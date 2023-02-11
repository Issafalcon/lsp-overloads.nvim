#!/bin/bash
tempfile=".test_output.tmp"
TEST_INIT=scripts/minimal_init.lua
TEST_DIR=tests/

if [[ -n $1 ]]; then
  nvim --headless --noplugin -u ${TEST_INIT} \
    -c "PlenaryBustedFile $1" | tee "${tempfile}"
else
  nvim --headless --clean --noplugin -u ${TEST_INIT} \
    -c "set rtp?" \
    -c "lua vim.cmd([[PlenaryBustedDirectory ${TEST_DIR} { minimal_init = '${TEST_INIT}'}]])" | tee "${tempfile}"
fi

# Plenary doesn't emit exit code 1 when tests have errors during setup
errors=$(sed 's/\x1b\[[0-9;]*m//g' "${tempfile}" | awk '/(Errors|Failed) :/ {print $3}' | grep -v '0')

rm "${tempfile}"

if [[ -n $errors ]]; then
  echo "Tests failed"
  exit 1
fi

exit 0
