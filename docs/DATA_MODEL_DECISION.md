# Data Model Decision: Separate Reek/Flog/Flay Scores

**Date**: 2025-10-29
**Task**: #25 (subtask of #23)
**Decision Maker**: rails-expert agent

## Problem Statement

Currently, all three static analysis tools (Reek, Flog, Flay) share one MetricSummary record with `scan_type: "static_analysis"`. This makes it impossible to display individual scores for each tool on the dashboard.

**Current State**:
- One MetricSummary record for all three tools
- `scan_type: "static_analysis"`
- Only aggregated counts (total_issues, high/medium/low_severity)
- `average_score` field exists but only captures Flog complexity (gets overwritten by other tools)

## Options Evaluated

### Option A: Separate scan_types (RECOMMENDED)
Create individual scan_types for each tool: "reek", "flog", "flay"

**Pros**:
- Clean separation of concerns - each tool has its own record
- Easy to query: `app.metric_summaries.find_by(scan_type: "reek")`
- Follows existing pattern (security, rubocop, drift all have separate scan_types)
- No schema changes required - works with existing columns
- Tool-specific scores easily accessible
- Future-proof: easy to add more tools without schema migrations

**Cons**:
- Creates 3 MetricSummary records instead of 1 (minimal storage impact)
- Slightly more records to manage (negligible with proper indexing)

**Implementation**:
- Reek: `scan_type="reek"`, `total_issues` = smell count
- Flog: `scan_type="flog"`, `average_score` = avg complexity
- Flay: `scan_type="flay"`, `total_issues` = duplication count

### Option B: Use metadata JSON field
Store per-tool scores in the `metadata` field (already exists)

**Pros**:
- Keep single MetricSummary record
- No additional records created
- metadata field already exists

**Cons**:
- JSON parsing required for every read
- Harder to query and filter (can't use SQL WHERE clauses)
- Not indexed - slower queries
- Less discoverable - have to know the JSON structure
- Violates separation of concerns
- Goes against Rails conventions

### Option C: Add dedicated columns
Add `reek_score`, `flog_score`, `flay_score` columns to MetricSummary

**Pros**:
- Direct column access (fastest reads)
- Type safety at database level

**Cons**:
- Requires schema migration
- Less flexible - every new tool needs new columns
- Column names specific to tools (not generalizable)
- Still need `scan_type` to differentiate what the record represents
- Doesn't scale well (what about future tools?)

## Decision: Option A (Separate scan_types)

**Rationale**:

1. **Consistency**: This follows the established pattern. Looking at the codebase:
   - SecurityScanner creates `scan_type: "security"`
   - RubocopScanner creates `scan_type: "rubocop"`
   - DriftScanner creates `scan_type: "drift"`
   - StaticAnalysisScanner should create 3 separate scan_types

2. **No Schema Changes**: Works with existing schema - zero migration risk

3. **Clean Architecture**: Each tool's metrics are isolated and independently queryable

4. **Easy Dashboard Display**: The view already iterates over `@summaries` - we just add 3 records instead of 1

5. **Scalability**: Future tools can be added without changing the schema

6. **Indexing**: The `index_metric_summaries_on_app_id_and_scan_type` index already exists and will make these queries fast

## Implementation Plan

### Step 1: Update StaticAnalysisScanner
Split the single `create_summary` method into three separate summaries:

```ruby
def create_reek_summary
  reek_scans = app.quality_scans.where(scan_type: "reek")

  app.metric_summaries.find_or_initialize_by(scan_type: "reek").tap do |summary|
    summary.total_issues = reek_scans.count
    summary.high_severity = reek_scans.where(severity: ["critical", "high"]).count
    summary.medium_severity = reek_scans.where(severity: "medium").count
    summary.low_severity = reek_scans.where(severity: "low").count
    summary.scanned_at = Time.current
    summary.save!
  end
end

def create_flog_summary
  flog_scans = app.quality_scans.where(scan_type: "flog")

  app.metric_summaries.find_or_initialize_by(scan_type: "flog").tap do |summary|
    summary.total_issues = flog_scans.count
    summary.average_score = flog_scans.average(:metric_value).to_f.round(2)
    summary.high_severity = flog_scans.where(severity: ["critical", "high"]).count
    summary.medium_severity = flog_scans.where(severity: "medium").count
    summary.low_severity = flog_scans.where(severity: "low").count
    summary.scanned_at = Time.current
    summary.save!
  end
end

def create_flay_summary
  flay_scans = app.quality_scans.where(scan_type: "flay")

  app.metric_summaries.find_or_initialize_by(scan_type: "flay").tap do |summary|
    summary.total_issues = flay_scans.count
    summary.high_severity = flay_scans.where(severity: ["critical", "high"]).count
    summary.medium_severity = flay_scans.where(severity: "medium").count
    summary.low_severity = flay_scans.where(severity: "low").count
    summary.scanned_at = Time.current
    summary.save!
  end
end
```

### Step 2: Update QualityScan records
Change the `scan_type` in `parse_*_results` methods:
- Reek results: `scan_type: "reek"` (was "static_analysis")
- Flog results: `scan_type: "flog"` (was "static_analysis")
- Flay results: `scan_type: "flay"` (was "static_analysis")

### Step 3: Update QualityScan::SCAN_TYPES constant
Add the three new scan types to the constant (if it exists) or controller logic

### Step 4: Update Tests
- Update specs to expect 3 separate MetricSummary records
- Update factory to create separate records for each tool
- Verify queries work correctly

### Step 5: Data Migration (Optional)
Create a rake task to migrate existing "static_analysis" records:
- Read existing records
- Split into 3 based on which tool created them (check file_path patterns or message prefixes)
- Delete old "static_analysis" records

## Benefits of This Approach

1. **Dashboard Display**: Easy to show individual scores
   ```erb
   <% reek = @summaries.find { |s| s.scan_type == "reek" } %>
   <% flog = @summaries.find { |s| s.scan_type == "flog" } %>
   <% flay = @summaries.find { |s| s.scan_type == "flay" } %>
   ```

2. **Historical Tracking**: Each tool's scores tracked independently over time

3. **Targeted Improvements**: Can see which tool is flagging most issues

4. **No Breaking Changes**: Existing "security", "rubocop", "drift" scans unaffected

## Risks and Mitigations

**Risk**: Existing "static_analysis" records in production
**Mitigation**: Create data migration rake task to split them, or simply delete and re-scan

**Risk**: Tests might expect single "static_analysis" record
**Mitigation**: Update test expectations to match new behavior

**Risk**: Dashboard might need updates to handle 3 new scan types
**Mitigation**: QualityScan::SCAN_TYPES array needs updating, but view already handles dynamic scan types

## Success Metrics

After implementation:
- ✅ 3 separate MetricSummary records per app (reek, flog, flay)
- ✅ Each has appropriate counts and scores
- ✅ Dashboard displays individual tool scores
- ✅ All tests passing
- ✅ Historical data preserved or re-scanned

## Next Steps

Task #26 should implement this decision:
1. Update StaticAnalysisScanner service
2. Update QualityScan constant
3. Update tests
4. Create data migration rake task
5. Test locally
6. Deploy and verify
