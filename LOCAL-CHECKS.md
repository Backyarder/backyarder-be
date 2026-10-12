# Run existing checks locally

Austin requested local checks on his Mac for every project that already has checks on October 12, 2026. This PR removes automatic hosted triggers; default-branch files change after merge. Existing hosted jobs remain available only by explicit manual dispatch and can consume minutes if enabled. Repository workflow settings are separately disabled. Disabling a check is not a passing result.

Run one project's checks at a time from an isolated checkout. Use synthetic data only. The script stops on the first failure. Resolve it and rerun; an early failure does not prove later checks passed. Existing coverage floors, security regression suites and dependency audits remain in the commands.

## Setup

Use the existing workflow’s Ruby **3.2.2**, selected before these commands; verify `ruby --version`. The Mac’s system Ruby 2.6.10 is insufficient. From an isolated checkout, prepare only the existing locked/focused dependencies:

```bash
bundle config set --local path vendor/bundle
bundle install
```

The wrapper does not install Ruby or gems, and no global Ruby installation is part of this migration. Keep local gems/bundle configuration untracked.

The existing test profile uses SQLite at `db/backyarder-test` inside the checkout. Use a fresh isolated checkout, verify that this test file is disposable, and set `LOCAL_CHECKS_CONFIRM_SYNTHETIC=1`. The script forces both RACK_ENV and RAILS_ENV to test. It never loads the production profile or drops a database.

The original workflow dropped and recreated its ephemeral database. Create an empty disposable test database before running; the local script deliberately avoids dropping an existing database. Supply the existing provider key privately if the specs require it; never commit it. The demonstration workflow has no behavioral tests and needs no replacement system.

## Run

```bash
# Activate the prepared virtualenv or set LOCAL_CHECKS_PYTHON to its python.
export LOCAL_CHECKS_CONFIRM_SYNTHETIC=1
bash scripts/local-checks.sh
```

Pytest worker count is bounded to one where the former workflow used four; this preserves the suite while reducing simultaneous work on the Mac. Browser installation uses the macOS-supported Chromium command without Linux OS package installation. macOS results do not certify Windows/Linux-only behavior.

## Reversal and evidence

Restore the previous workflow trigger stanza and re-enable the workflow only when Austin requests hosted execution. Record the Git head, command, exit status, passed/skipped counts and any audit findings. Do not change required branch/security checks to get a merge through; surface a required-check blocker for explicit approval.
