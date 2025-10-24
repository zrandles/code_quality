# Code Quality Dashboard

Comprehensive code quality monitoring for all Rails apps in the ecosystem.

## Features

- **Security Scanning** - Brakeman vulnerability detection
- **Static Analysis** - Reek, Flog, Flay for code quality
- **RuboCop** - High-value cops only (no style nitpicking)
- **Drift Detection** - Compare against golden_deployment template
- **Test Coverage** - SimpleCov integration (optional)
- **Dashboard UI** - Summary cards with drilldown views

## Production URL

http://24.199.71.69/code_quality

## Quick Start

1. Visit dashboard
2. Click "Discover Apps" to scan ~/zac_ecosystem/apps
3. Click "Scan Now" on any app to run quality checks
4. View detailed results by scan type

## Scanner Types

### Security (Brakeman)
- Detects SQL injection, XSS, command injection
- Severity: critical/high/medium/low
- File/line tracking

### Static Analysis
- **Reek**: Code smells
- **Flog**: ABC complexity (flags >20)
- **Flay**: Duplicate code detection

### RuboCop (High-Value Only)
Focus on important issues only:
- Debugger statements
- Unused variables
- Security issues (eval, open, marshal)
- Performance problems
- Rails best practices

NO style cops (quotes, whitespace, etc.)

### Drift Detection
Checks for divergence from golden_deployment:
- Missing deployment config
- Tailwind build setup
- Path-based routing
- Gem version differences

## Architecture

### Models
- `App` - Rails apps to scan
- `QualityScan` - Individual scan results
- `MetricSummary` - Aggregated metrics per scan type

### Services
- `SecurityScanner`
- `StaticAnalysisScanner`
- `RubocopScanner`
- `DriftScanner`
- `TestCoverageScanner`

### Jobs
- `AppScannerJob` - Async scanning via Solid Queue

## Status Meanings

- **Healthy** (Green): No critical/high issues
- **Warning** (Yellow): >5 medium severity issues
- **Critical** (Red): Any high/critical severity issues

## Local Development

```bash
cd ~/zac_ecosystem/apps/code_quality
bin/rails server -p 3015
open http://localhost:3015/code_quality
```

## Deployment

```bash
git add . && git commit -m "Update code quality"
git push
cap production deploy
```

## Philosophy

This tool provides **guardrails, not perfection**. The goal is to:
- ✅ Prevent quality drift while shipping fast
- ✅ Catch critical issues early
- ✅ Maintain consistency across apps
- ❌ NOT block on style preferences
- ❌ NOT aim for 100% perfect scores

## Notes

- Solid Queue plugin disabled in puma (causes crashes)
- Scanning requires local code access (apps must be in ~/zac_ecosystem/apps)
- Test coverage requires SimpleCov to be configured in target apps

## See Also

- Session doc: `~/zac_ecosystem/docs/SESSION_2025_10_24_CODE_QUALITY.md`
- Golden deployment template: `~/zac_ecosystem/apps/golden_deployment/`
