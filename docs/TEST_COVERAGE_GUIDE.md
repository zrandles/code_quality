# Test Coverage Guide

## Overview

The code_quality app tracks test coverage across all ecosystem apps using SimpleCov. This guide explains how coverage tracking works, how to add it to new apps, and how to interpret the results.

## How Test Coverage Works

### SimpleCov Integration

SimpleCov is a code coverage tool for Ruby that tracks which lines of code are executed during test runs. When tests run with SimpleCov enabled, it:

1. Monitors which lines of code are executed
2. Generates coverage data in JSON format
3. Creates HTML reports for human viewing
4. Stores results in the `coverage/` directory

### Coverage Data Files

SimpleCov generates two key files in the `coverage/` directory:

1. **`.last_run.json`** - Simple file containing overall coverage percentage
   ```json
   {
     "result": {
       "line": 87.45
     }
   }
   ```

2. **`.resultset.json`** - Detailed per-file line coverage data
   ```json
   {
     "RSpec": {
       "coverage": {
         "/path/to/file.rb": [1, 1, 0, null, 1, 0],
         ...
       },
       "timestamp": 1698765432
     }
   }
   ```

   **Line coverage array format**:
   - `1` or higher: Line was executed (number = execution count)
   - `0`: Line was not executed (uncovered code)
   - `null`: Line is not executable (comments, blank lines, etc.)

### TestCoverageScanner

The `TestCoverageScanner` service parses SimpleCov results and stores them in the code_quality database:

1. **Checks for existing coverage data** (`coverage/.resultset.json`)
2. **If missing, attempts to run tests** (with 60-second timeout)
3. **Parses coverage results** from `.resultset.json`
4. **Creates QualityScans** for files with low coverage (<80%)
5. **Stores overall coverage** in MetricSummary

**Storage structure**:
- **QualityScans**: Individual files with coverage < 80%
  - `scan_type`: "test_coverage"
  - `severity`: "high" (<50%) or "medium" (50-79%)
  - `message`: "Low test coverage: 45.2%"
  - `file_path`: Full path to the file
  - `metric_value`: Coverage percentage for that file
- **MetricSummary**: Overall coverage for the app
  - `scan_type`: "test_coverage"
  - `average_score`: Overall coverage percentage
  - `total_issues`: Count of files with low coverage
  - `metadata`: `{ overall_coverage: 87.45 }`

## Adding SimpleCov to a New App

### Step 1: Add SimpleCov Gem

Add to your `Gemfile` in the test group:

```ruby
group :development, :test do
  gem "rspec-rails"  # or whatever test framework you use
  gem "simplecov", require: false
end
```

Run `bundle install`.

### Step 2: Configure SimpleCov

**For RSpec apps** - Add to `spec/rails_helper.rb` (BEFORE `require 'rspec/rails'`):

```ruby
# Configure SimpleCov for code coverage
require 'simplecov'
SimpleCov.start 'rails' do
  add_filter '/spec/'
  add_filter '/config/'
  add_filter '/vendor/'

  # Optional: Set minimum coverage threshold
  minimum_coverage 80  # Fail if coverage drops below 80%
end

ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
# ... rest of rails_helper.rb
```

**For Minitest apps** - Add to `test/test_helper.rb` (at the TOP, before everything):

```ruby
require 'simplecov'
SimpleCov.start 'rails' do
  add_filter '/test/'
  add_filter '/config/'
  add_filter '/vendor/'
end

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
# ... rest of test_helper.rb
```

**CRITICAL**: SimpleCov must be required and started BEFORE Rails is loaded. Put it at the very top of your test helper file.

### Step 3: Run Tests

```bash
# RSpec
bundle exec rspec

# Minitest
bundle exec rails test
```

SimpleCov will automatically:
- Generate `coverage/.resultset.json` with detailed coverage data
- Generate `coverage/.last_run.json` with overall percentage
- Create HTML report in `coverage/index.html`

### Step 4: View Coverage Report

Open the HTML report in your browser:

```bash
open coverage/index.html
```

This shows:
- Overall coverage percentage
- Per-file coverage breakdown
- Lines covered vs uncovered
- Color-coded line highlighting (red = uncovered, green = covered)

### Step 5: Add Coverage to .gitignore

Add this to your `.gitignore`:

```
/coverage/
```

Coverage reports are generated locally and should not be committed to git.

## Golden Deployment Template

The `golden_deployment` app has SimpleCov properly configured. All new apps created from the template will automatically have coverage enabled.

**Configuration location**: `apps/golden_deployment/spec/rails_helper.rb` (lines 4-20)

**What it includes**:
- SimpleCov gem in Gemfile
- Proper configuration in rails_helper.rb
- Coverage filtering (excludes spec/, config/, vendor/)
- Ready to use immediately after running tests

## How TestCoverageScanner Works

### Scanner Workflow

1. **Check app exists**: Verifies app directory exists
2. **Look for existing coverage**: Checks for `coverage/.resultset.json`
3. **Run tests if needed**: If no coverage file exists AND test directory exists
   - Runs: `cd #{app.path} && timeout 60 bin/rails test 2>&1`
   - 60-second timeout prevents hanging on slow test suites
4. **Parse coverage results**: Reads `.resultset.json` and calculates coverage
5. **Flag low-coverage files**: Creates QualityScans for files < 80% coverage
6. **Store overall coverage**: Creates/updates MetricSummary with overall percentage

### Coverage Calculation

**Per-file coverage**:
```ruby
file_total = line_coverage.compact.size  # Exclude null (non-executable) lines
file_covered = line_coverage.count { |l| l && l > 0 }  # Count executed lines
file_coverage_pct = (file_covered.to_f / file_total * 100).round(2)
```

**Overall coverage**:
```ruby
overall_coverage = (total_covered_lines / total_executable_lines * 100).round(2)
```

### Severity Thresholds

- **High severity**: Coverage < 50% (critical gap)
- **Medium severity**: Coverage 50-79% (needs improvement)
- **Info**: Overall coverage summary (not an issue)

Files with ≥80% coverage are not flagged as issues.

## Interpreting Dashboard Results

### Coverage Column

The code_quality dashboard shows test coverage in the "Coverage" column:

- **Percentage displayed**: Overall coverage from MetricSummary.average_score
- **Color coding**:
  - Green: ≥80% (good)
  - Yellow: 50-79% (needs work)
  - Red: <50% (critical)
- **"N/A"**: No SimpleCov configuration or no tests

### Quality Scans Table

Click on an app to see detailed quality scans. Coverage-related scans show:

- **Scan Type**: "test_coverage"
- **Severity**: "high" or "medium" for low-coverage files
- **Message**: "Low test coverage: 45.2%"
- **File Path**: Which file has low coverage
- **Metric Value**: Exact coverage percentage

### Metric Summary

The MetricSummary record stores:
- `average_score`: Overall coverage percentage (e.g., 87.45)
- `total_issues`: Count of files below 80% coverage
- `high_severity`: Count of files below 50%
- `medium_severity`: Count of files between 50-79%
- `metadata`: `{ overall_coverage: 87.45 }`

## Running Coverage Scans

### Automatic Scans

Coverage scans run automatically daily at 2am UTC as part of `quality:scan_all`:

```bash
# Cron job on production server
0 2 * * * cd /home/zac/code_quality/current && RAILS_ENV=production /home/zac/.rbenv/shims/bundle exec rake quality:scan_all
```

See `AUTOMATED_SCANNING_SETUP.md` for full automation details.

### Manual Scans

**Scan all apps**:
```bash
# Production
ssh zac@24.199.71.69 'cd ~/code_quality/current && RAILS_ENV=production /home/zac/.rbenv/shims/bundle exec rake quality:scan_all'

# Development
cd ~/zac_ecosystem/apps/code_quality
bin/rails quality:scan_all
```

**Scan single app**:
```bash
# Production
ssh zac@24.199.71.69 'cd ~/code_quality/current && RAILS_ENV=production /home/zac/.rbenv/shims/bundle exec rake quality:scan_app[app_monitor]'

# Development
cd ~/zac_ecosystem/apps/code_quality
bin/rails quality:scan_app[app_monitor]
```

### Force Test Execution

If you want to force tests to run (instead of using existing coverage):

```bash
# Delete existing coverage, then scan
ssh zac@24.199.71.69 'rm -rf ~/app_monitor/current/coverage && cd ~/code_quality/current && RAILS_ENV=production /home/zac/.rbenv/shims/bundle exec rake quality:scan_app[app_monitor]'
```

## Troubleshooting

### Coverage Not Appearing in Dashboard

**Symptom**: App shows "N/A" in Coverage column

**Possible causes**:

1. **SimpleCov not configured**
   - Check if `gem "simplecov"` is in Gemfile
   - Verify SimpleCov.start is in test_helper.rb or rails_helper.rb
   - Ensure SimpleCov is required BEFORE Rails

2. **No tests exist**
   - Check if `test/` or `spec/` directory exists
   - Verify test files exist and run successfully
   - Run `bundle exec rspec` or `bundle exec rails test` to verify

3. **Coverage files not generated**
   - Run tests manually: `cd ~/zac_ecosystem/apps/{app_name} && bundle exec rspec`
   - Check if `coverage/.resultset.json` was created
   - Look for SimpleCov errors in test output

4. **Scanner timeout**
   - Tests took longer than 60 seconds to run
   - Check `/home/zac/code_quality/shared/log/quality_scans.log` for timeout messages
   - Consider optimizing slow tests

**Solution**:
```bash
# Verify SimpleCov works locally
cd ~/zac_ecosystem/apps/{app_name}
bundle exec rspec
open coverage/index.html  # Should show coverage report

# If coverage works locally, trigger scan
cd ~/zac_ecosystem/apps/code_quality
bin/rails quality:scan_app[app_name]
```

### Coverage Lower Than Expected

**Symptom**: Coverage percentage seems too low

**Possible causes**:

1. **Test suite incomplete**
   - Many files have no tests
   - Tests exist but don't cover all code paths

2. **Test filters excluding files**
   - Check SimpleCov configuration for add_filter directives
   - Verify important files aren't being filtered out

3. **Integration tests not running**
   - Only unit tests run, missing integration test coverage
   - Check if test suite is complete

**Solution**:
1. Review HTML coverage report: `open coverage/index.html`
2. Identify uncovered files (red highlighting)
3. Write tests for critical uncovered code
4. Re-run tests and verify coverage increases

### Scanner Errors in Logs

**Symptom**: Errors in `/home/zac/code_quality/shared/log/quality_scans.log`

**Common errors**:

1. **"No such file or directory - coverage/.resultset.json"**
   - Tests didn't run or failed to generate coverage
   - Run tests manually to verify: `cd ~/app/current && bundle exec rspec`

2. **"Timeout - tests took longer than 60 seconds"**
   - Test suite is slow
   - Consider increasing timeout in TestCoverageScanner (line 42)

3. **"JSON parse error"**
   - `.resultset.json` is malformed or incomplete
   - Delete coverage directory and re-run tests
   - Check for SimpleCov version compatibility

**Solution**:
```bash
# View recent scanner errors
ssh zac@24.199.71.69 'tail -100 ~/code_quality/shared/log/quality_scans.log | grep -A 5 "coverage"'

# Clear bad coverage data and re-run
ssh zac@24.199.71.69 'rm -rf ~/app_monitor/current/coverage'
ssh zac@24.199.71.69 'cd ~/code_quality/current && RAILS_ENV=production /home/zac/.rbenv/shims/bundle exec rake quality:scan_app[app_monitor]'
```

### Missing Coverage for Specific Files

**Symptom**: Some files don't show in coverage report

**Possible causes**:

1. **Files filtered out**
   - Check SimpleCov configuration for add_filter
   - Common filters: `/spec/`, `/test/`, `/config/`, `/vendor/`

2. **Files never loaded**
   - If a file is never required during tests, it won't appear in coverage
   - Autoloaded files only load when accessed

3. **Files in excluded directories**
   - SimpleCov excludes certain directories by default (lib/tasks, db/migrate, etc.)

**Solution**:
1. Check SimpleCov config: `cat spec/rails_helper.rb | grep -A 10 SimpleCov`
2. Add files to coverage: Remove from add_filter or add explicit add_group
3. Ensure files are loaded: Add tests that exercise the code

### Coverage Decreased After Changes

**Symptom**: Coverage dropped from 90% to 70%

**Possible causes**:

1. **New code added without tests**
   - Added features without corresponding tests
   - Coverage percentage reflects new untested code

2. **Tests removed or disabled**
   - Deleted tests that were covering code
   - Skipped tests (pending, skip, xit)

3. **Code refactored to different files**
   - Moved code to new files without updating tests
   - Tests no longer cover the refactored code

**Solution**:
1. Review recent changes: `git diff main`
2. Check which files lost coverage: `open coverage/index.html`
3. Write tests for new/changed code
4. Verify skipped/pending tests: `bundle exec rspec --format documentation | grep -i pending`

## Current Ecosystem Status

Based on Task #17 audit (completed 2025-10-29):

**Apps WITH SimpleCov (11 total)**:
- golden_deployment (TEMPLATE - properly configured)
- agent_tracker
- app_monitor
- chromatic
- code_quality
- custom_pages
- high_score_basketball
- idea_tracker
- powered_cube
- test_dummy_app
- wordle_variant

**Apps WITHOUT SimpleCov (8 total)**:
- **Priority 1** (have test suites, need SimpleCov):
  - niche_digest (Minitest)
  - soccer_elo (Minitest)
- **Priority 2** (need tests first):
  - nike_giveaway
  - shopify_stockout_calc
  - solitaire
  - test_game_template
  - trivia_app
  - wordle_app

**Template Status**: Golden_deployment is properly configured, so all NEW apps created from template will have SimpleCov by default.

## Best Practices

1. **Configure SimpleCov at the top** of test helper (before require rails)
2. **Run tests regularly** to keep coverage data fresh
3. **Add coverage/ to .gitignore** - never commit coverage reports
4. **Set reasonable thresholds** - 80% is good, 100% is often unrealistic
5. **Focus on critical code** - controllers, models, services deserve high coverage
6. **Don't game the metrics** - write meaningful tests, not just for coverage
7. **Review uncovered code** - use HTML report to find gaps
8. **Test happy and sad paths** - error handling needs coverage too

## Performance Considerations

### Scan Timeout

TestCoverageScanner uses a 60-second timeout per app:

```ruby
cmd = "cd #{app.path} && timeout 60 bin/rails test 2>&1"
```

**Why timeout is necessary**:
- Prevents hanging on slow/broken test suites
- Allows scan_all to complete even if one app has issues
- Daily cron job won't hang indefinitely

**If your tests take longer than 60 seconds**:
- Optimize slow tests
- Consider increasing timeout in `app/services/test_coverage_scanner.rb`
- Use pre-generated coverage (run tests separately, scanner uses existing results)

### Pre-generating Coverage

For production scans, you can generate coverage separately:

```bash
# Run tests to generate coverage (on production server)
ssh zac@24.199.71.69 'cd ~/app_monitor/current && RAILS_ENV=test bundle exec rspec'

# Then scan uses existing coverage (fast, no test execution)
ssh zac@24.199.71.69 'cd ~/code_quality/current && RAILS_ENV=production /home/zac/.rbenv/shims/bundle exec rake quality:scan_app[app_monitor]'
```

This approach:
- Separates test execution from scanning
- Allows longer test runs without hitting timeout
- Scanner just parses existing `.resultset.json`

## Related Documentation

- **AUTOMATED_SCANNING_SETUP.md** - Daily scan automation and cron setup
- **golden_deployment/spec/rails_helper.rb** - Template SimpleCov configuration
- **app/services/test_coverage_scanner.rb** - Scanner implementation

---

**Last Updated**: 2025-10-29
**Created By**: Claude (Rails Expert Agent)
**Related Tasks**: Task #14 (Test Coverage Initiative), Task #17 (SimpleCov Audit), Task #18 (Documentation)
