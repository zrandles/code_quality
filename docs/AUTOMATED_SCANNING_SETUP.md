# Automated Quality Scanning Setup

## Overview

The code_quality app now automatically scans all apps in the ecosystem daily at 2am UTC, populating the production dashboard with quality metrics.

## Architecture Decision

**Approach**: Run scans ON the production server

**Rationale**:
1. Direct access to source code at `/home/zac/{app_name}/current`
2. Results write directly to production database (no sync complexity)
3. Scans production dependencies, not dev dependencies
4. Automated via cron (set it and forget it)
5. Follows database safety rules (no local-to-production data transfer)

## Implementation

### 1. Rake Tasks

Three rake tasks were created in `lib/tasks/scan_apps.rake`:

#### `rake quality:scan_all`
Scans all apps in the ecosystem (excluding triplechain per ecosystem rules).

**Features**:
- Auto-detects environment (production vs development paths)
- Skips non-existent app directories
- Runs all scanners: SecurityScanner, StaticAnalysisScanner, RubocopScanner, DriftScanner
- Updates app status based on scan results
- Comprehensive error handling and progress reporting

**Usage**:
```bash
# Production
cd ~/code_quality/current
RAILS_ENV=production bundle exec rake quality:scan_all

# Development
cd ~/zac_ecosystem/apps/code_quality
bin/rails quality:scan_all
```

#### `rake quality:scan_app[app_name]`
Scans a single app by name.

**Usage**:
```bash
# Production
RAILS_ENV=production bundle exec rake quality:scan_app[agent_tracker]

# Development
bin/rails quality:scan_app[agent_tracker]
```

#### `rake quality:clear_scans`
Clears all scan data (useful for testing).

### 2. Cron Job

Daily automated scans run at 2am UTC (6pm Pacific):

```cron
0 2 * * * cd /home/zac/code_quality/current && RAILS_ENV=production /home/zac/.rbenv/shims/bundle exec rake quality:scan_all >> /home/zac/code_quality/shared/log/quality_scans.log 2>&1
```

**Log file**: `/home/zac/code_quality/shared/log/quality_scans.log`

**To view logs**:
```bash
ssh zac@24.199.71.69 'tail -100 ~/code_quality/shared/log/quality_scans.log'
```

### 3. Apps Scanned

**19 total apps** (excluding triplechain):
- agent_tracker
- app_monitor
- chromatic
- code_quality
- custom_pages
- golden_deployment
- high_score_basketball
- idea_tracker
- niche_digest
- nike_giveaway
- powered_cube
- shopify_stockout_calc
- soccer_elo
- solitaire
- test_dummy_app
- test_game_template
- trivia_app
- wordle_app
- wordle_variant

**Note**: Apps not deployed to production are automatically skipped (e.g., custom_pages, nike_giveaway).

## Scanner Status

### Working Scanners

1. **DriftScanner** - FULLY WORKING
   - Checks deployment configuration
   - Compares gem versions with golden_deployment
   - Validates Tailwind setup
   - Verifies path-based routing

### Partially Working Scanners

2. **StaticAnalysisScanner** - FLOG & FLAY WORKING, REEK FAILING
   - Flog: Complexity analysis working
   - Flay: Duplication detection working
   - Reek: Parsing errors (needs investigation)

### Blocked Scanners

3. **SecurityScanner (Brakeman)** - BLOCKED
   - Error: "can't find executable brakeman for gem brakeman"
   - Reason: Running from code_quality's bundle, but scanning other apps
   - Solution needed: Use each app's bundle context or install globally

4. **RubocopScanner** - BLOCKED
   - Error: "can't find executable rubocop for gem rubocop"
   - Reason: Same as Brakeman
   - Solution needed: Same as Brakeman

5. **TestCoverageScanner** - NOT ENABLED
   - Commented out in AppScannerJob (line 14)
   - Reason: "can be slow"
   - Status: Available but disabled for performance

## Current Results (First Scan)

**Production scan completed**: 2025-10-29 14:13 UTC

**Apps scanned**: 11 (8 skipped - not deployed)
**Apps failed**: 0

**Status breakdown**:
- Critical: agent_tracker, app_monitor, idea_tracker, niche_digest
- Healthy: chromatic, code_quality, golden_deployment, high_score_basketball, powered_cube, soccer_elo, test_dummy_app

**Dashboard**: http://24.199.71.69/code_quality/

## Future Improvements

### High Priority

1. **Fix Scanner Execution Context**
   - Current: Running from code_quality's bundle (limited gem availability)
   - Solution: Execute scanners within each app's bundle context
   - Benefit: Brakeman and RuboCop will work

2. **Fix Reek Parsing Errors**
   - Current: "unexpected character: 'sh:' at line 1 column 1"
   - Solution: Investigate command execution and output parsing
   - Benefit: Static analysis will be complete

### Medium Priority

3. **Enable Test Coverage Scanner**
   - Current: Disabled for performance
   - Solution: Run during off-peak hours or async
   - Benefit: Track test coverage across all apps

4. **Add Notification System**
   - Current: Silent scans, check dashboard manually
   - Solution: Email/Slack alerts for critical issues
   - Benefit: Proactive quality monitoring

### Low Priority

5. **Historical Trend Tracking**
   - Current: Only latest scan visible
   - Solution: Keep scan history, show trends
   - Benefit: See quality improving/degrading over time

## Manual Operations

### Run scan immediately (production)
```bash
ssh zac@24.199.71.69 'cd ~/code_quality/current && RAILS_ENV=production /home/zac/.rbenv/shims/bundle exec rake quality:scan_all'
```

### Check cron job
```bash
ssh zac@24.199.71.69 'crontab -l | grep quality'
```

### View scan logs
```bash
ssh zac@24.199.71.69 'tail -f ~/code_quality/shared/log/quality_scans.log'
```

### Check database
```bash
ssh zac@24.199.71.69 'cd ~/code_quality/current && RAILS_ENV=production /home/zac/.rbenv/shims/bundle exec rails runner "puts ScannedApp.count"'
```

## Troubleshooting

### Cron job not running
Check crontab:
```bash
ssh zac@24.199.71.69 'crontab -l'
```

Check logs for errors:
```bash
ssh zac@24.199.71.69 'tail -100 ~/code_quality/shared/log/quality_scans.log'
```

### Dashboard showing no data
1. Check database has records:
   ```bash
   ssh zac@24.199.71.69 'cd ~/code_quality/current && RAILS_ENV=production /home/zac/.rbenv/shims/bundle exec rails runner "puts ScannedApp.count"'
   ```

2. Run scan manually to verify:
   ```bash
   ssh zac@24.199.71.69 'cd ~/code_quality/current && RAILS_ENV=production /home/zac/.rbenv/shims/bundle exec rake quality:scan_all'
   ```

3. Restart app:
   ```bash
   ssh zac@24.199.71.69 'sudo systemctl restart code_quality.service'
   ```

### Scanner errors
Check scanner implementation in `app/services/`:
- `security_scanner.rb` - Brakeman
- `static_analysis_scanner.rb` - Reek, Flog, Flay
- `rubocop_scanner.rb` - RuboCop (high-value cops only)
- `drift_scanner.rb` - Golden deployment comparison
- `test_coverage_scanner.rb` - SimpleCov (disabled)

## Database Safety Note

The production database is populated ONLY by running scans on the production server. The local development database is completely separate and should NEVER be copied to production.

This approach follows the critical ecosystem rule: **NEVER copy local database to production**.

## Files Modified

1. `Gemfile.lock` - Added x86_64-linux platform
2. `lib/tasks/scan_apps.rake` - Created rake tasks (201 lines)
3. `/etc/crontab` (production server) - Added daily scan job

## Git Commit

```
commit 75d7b28d61fc5067b769e9342f7458a90218a298
Author: Claude <noreply@anthropic.com>
Date: Wed Oct 29 14:11:45 2025 +0000

Add automated quality scanning rake tasks

- Fix Gemfile.lock platform issues (add x86_64-linux)
- Create quality:scan_all rake task for scanning all apps
- Create quality:scan_app[name] for scanning individual apps
- Auto-detect environment (production vs development paths)
- Comprehensive error handling and progress reporting
- Skip triplechain per ecosystem rules
```

## Next Steps

From now on, quality scans will run automatically every day at 2am UTC. Check the dashboard at http://24.199.71.69/code_quality/ to see results.

No manual intervention required unless scanner errors need fixing (see Future Improvements section above).

---

**Last Updated**: 2025-10-29
**Implemented By**: Claude (Principal Test Engineer Agent)
