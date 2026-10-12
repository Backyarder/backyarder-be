# Run existing checks locally

Austin requested local checks on his Mac for every project that already has checks on October 12, 2026. Automatic hosted triggers are removed; existing hosted jobs remain available only by explicit manual dispatch and can consume minutes if enabled. Repository workflow settings are separately disabled. Disabling a check is not a passing result.

Run one project's checks at a time from an isolated checkout. Use synthetic data only. The script stops on the first failure. Resolve it and rerun; an early failure does not prove later checks passed. Existing coverage floors, security regression suites and dependency audits remain in the commands.

## Setup

Use the versions and dependency commands in the existing workflow and project development guide. Python projects use an isolated virtual environment; install their existing `requirements-dev.txt` (Playbook: from `scaffold/`). claude-task-runner uses `pip install -e ".[dev]"`. Ruby checks need Ruby 3.2.2 and the locked bundle; lunch_and_learn uses `gem install --no-document vcr:6.2.0 webmock:3.18.1 rspec:3.12.0 faraday:2.7.10`. The script does not install Python/Ruby dependencies or change global tools.

Configure `DATABASE_URL` for a new, isolated loopback PostgreSQL database named `local_checks_<project>`, matching the PostgreSQL version in the workflow. Confirm its host, port, database and ownership before `LOCAL_CHECKS_CONFIRM_SYNTHETIC=1`. Playbook/POS migration and collectstatic steps write only to that isolated database and checkout. Never point this script at a development or production database.

The original workflow dropped and recreated its ephemeral database. Create an empty disposable test database before running; the local script deliberately avoids dropping an existing database. Supply the existing provider key privately if the specs require it; never commit it. The demonstration workflow has no behavioral tests and needs no replacement system.

## Run

```bash
# Activate the prepared virtualenv or set LOCAL_CHECKS_PYTHON to its python.
export LOCAL_CHECKS_CONFIRM_SYNTHETIC=1
# export DATABASE_URL with your isolated synthetic database URL first.
bash scripts/local-checks.sh
```

Pytest worker count is bounded to one where the former workflow used four; this preserves the suite while reducing simultaneous work on the Mac. Browser installation uses the macOS-supported Chromium command without Linux OS package installation. macOS results do not certify Windows/Linux-only behavior.

## Reversal and evidence

Restore the previous workflow trigger stanza and re-enable the workflow only when Austin requests hosted execution. Record the Git head, command, exit status, passed/skipped counts and any audit findings. Do not change required branch/security checks to get a merge through; surface a required-check blocker for explicit approval.
