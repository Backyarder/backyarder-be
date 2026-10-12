#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ -n "${LOCAL_CHECKS_PYTHON:-}" ]]; then
  export PATH="$(dirname "$LOCAL_CHECKS_PYTHON"):$PATH"
fi
: "${LOCAL_CHECKS_CONFIRM_SYNTHETIC:?Set to 1 only for an isolated synthetic test database}"
[[ "$LOCAL_CHECKS_CONFIRM_SYNTHETIC" == 1 ]]
: "${DATABASE_URL:?Set an isolated local test database URL; never production}"
python - <<'CHECK_LOCAL_DATABASE'
import os
from urllib.parse import urlparse
url = urlparse(os.environ['DATABASE_URL'])
if url.scheme not in ('postgres', 'postgresql') or url.hostname not in ('127.0.0.1', 'localhost'):
    raise SystemExit('Checks require an explicitly configured loopback PostgreSQL database.')
if not url.path.removeprefix('/').startswith('local_checks_'):
    raise SystemExit('Use a dedicated database named local_checks_<project>; never a shared database.')
CHECK_LOCAL_DATABASE
export RACK_ENV=test
export RAILS_ENV=test
RACK_ENV=test bundle exec rake db:migrate
RACK_ENV=test bundle exec rake db:seed
bundle exec rspec spec/*
