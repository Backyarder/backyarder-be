#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ -n "${LOCAL_CHECKS_PYTHON:-}" ]]; then
  export PATH="$(dirname "$LOCAL_CHECKS_PYTHON"):$PATH"
fi
: "${LOCAL_CHECKS_CONFIRM_SYNTHETIC:?Set to 1 only for an isolated synthetic test database}"
[[ "$LOCAL_CHECKS_CONFIRM_SYNTHETIC" == 1 ]]
RACK_ENV=test bundle exec rake db:migrate
RACK_ENV=test bundle exec rake db:seed
bundle exec rspec spec/*
