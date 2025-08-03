# Analytics Monitoring Performance Test Suite

## Overview

This comprehensive performance test suite validates the Analytics Monitoring system's ability to handle enterprise-scale loads with the following targets:

- **Dashboard Load Time**: <3 seconds
- **API Response Time**: <2 seconds  
- **Alert Delivery**: <1 minute
- **High-Volume Processing**: 1M+ data points daily
- **Concurrent Users**: 100+ supported
- **WebSocket Connections**: 200+ concurrent

## Test Suite Components

### 1. Core Performance Tests

#### `analytics_monitoring_performance_test.rb`
**Main comprehensive performance test covering:**
- High-volume data processing (1M+ data points simulation)
- Dashboard performance and concurrent users (100+ users)
- Real-time WebSocket performance and stress testing
- ETL pipeline performance benchmarks
- Background job processing performance
- Database query optimization
- Alert system scalability
- API response time validation
- Memory and resource usage analysis
- Stress testing and system resilience

#### `high_volume_data_processing_test.rb`
**Specialized high-volume data processing tests:**
- Sustained processing: 1M+ records daily capacity
- Peak load processing: 50,000+ records/second bursts
- Multi-platform concurrent processing
- Memory efficiency under load
- Error handling and recovery at scale
- Pipeline throughput analysis by platform

#### `websocket_stress_test.rb`
**Real-time WebSocket performance validation:**
- Connection establishment performance (200+ concurrent)
- Message latency (<50ms target)
- Broadcast performance and scalability
- Connection reliability and recovery
- Memory usage under WebSocket load
- Peak load stress testing

#### `analytics_performance_test_runner.rb`
**Comprehensive orchestration and reporting:**
- Executes all performance test components
- Comprehensive performance analysis
- Scalability analysis and projections
- Enterprise readiness validation
- Final recommendations and action plans
- Multiple report formats (JSON, HTML, CSV, Executive Summary)

## Performance Targets

### Critical Performance Requirements

| Metric | Target | Validation Method |
|--------|---------|------------------|
| Dashboard Load Time | <3 seconds | Load testing with realistic data |
| API Response Time | <2 seconds | Multiple endpoint testing |
| Alert Delivery Time | <1 minute | End-to-end alert testing |
| Daily Data Processing | 1M+ data points | High-volume batch testing |
| Concurrent Users | 100+ users | Concurrent load simulation |
| WebSocket Connections | 200+ concurrent | Connection stress testing |
| Message Latency | <50ms | Real-time communication testing |
| Memory Efficiency | <500MB per 1M records | Memory profiling under load |
| Error Rate | <0.1% | Error injection and recovery testing |
| System Uptime | >95% availability | Reliability and resilience testing |

## Running the Tests

### Prerequisites

```bash
# Ensure test environment is properly configured
export RAILS_ENV=test

# Install dependencies
bundle install

# Setup test database
rails db:test:prepare

# Clear any existing performance reports
rm -f tmp/analytics_performance_*
rm -f tmp/high_volume_*
rm -f tmp/websocket_*
```

### Individual Test Execution

#### Run Specific Performance Tests

```bash
# Main comprehensive performance test suite
rails test test/performance/analytics_monitoring_performance_test.rb

# High-volume data processing tests
rails test test/performance/high_volume_data_processing_test.rb

# WebSocket stress tests
rails test test/performance/websocket_stress_test.rb

# Comprehensive test runner with full analysis
rails test test/performance/analytics_performance_test_runner.rb
```

#### Run All Performance Tests

```bash
# Execute all performance tests
rails test test/performance/

# Or run with specific pattern
rails test test/performance/*performance*.rb
```

### Comprehensive Test Execution

For complete enterprise readiness validation:

```bash
# Run the comprehensive test runner for full analysis
rails test test/performance/analytics_performance_test_runner.rb

# This will execute all test components and generate:
# - Comprehensive performance analysis
# - Enterprise readiness assessment
# - Scalability analysis
# - Detailed recommendations
# - Multiple report formats
```

## Test Configuration

### Environment Variables

```bash
# Optional: Customize test parameters
export PERFORMANCE_TEST_SCALE_FACTOR=1.0    # Scale test loads (0.5 = half load, 2.0 = double load)
export PERFORMANCE_TEST_DURATION=standard   # standard, extended, quick
export PERFORMANCE_TEST_MEMORY_TRACKING=true # Enable detailed memory tracking
export PERFORMANCE_TEST_CONCURRENT_USERS=100 # Override concurrent user target
```

### Test Data Setup

The tests automatically create necessary test data, but you can customize:

```ruby
# In test/test_helper.rb or individual test files
class PerformanceTestConfig
  CONCURRENT_USERS = ENV.fetch('PERFORMANCE_TEST_CONCURRENT_USERS', 100).to_i
  WEBSOCKET_CONNECTIONS = ENV.fetch('PERFORMANCE_TEST_WEBSOCKET_CONNECTIONS', 200).to_i
  HIGH_VOLUME_RECORDS = ENV.fetch('PERFORMANCE_TEST_HIGH_VOLUME_RECORDS', 100_000).to_i
  
  # Scale factors for different test environments
  SCALE_FACTORS = {
    'ci' => 0.3,        # Reduced load for CI environments
    'development' => 0.5, # Moderate load for development
    'staging' => 0.8,    # Near-production load for staging
    'production' => 1.0  # Full load for production validation
  }
end
```

## Understanding Test Results

### Performance Reports Generated

After running tests, the following reports are generated in `tmp/`:

#### 1. JSON Report (`analytics_comprehensive_performance_report_*.json`)
- Complete test execution data
- Detailed performance metrics
- Raw test results for programmatic analysis

#### 2. HTML Report (`analytics_performance_report_*.html`)
- Visual performance dashboard
- Interactive charts and metrics
- Easy-to-read performance breakdown

#### 3. CSV Summary (`analytics_performance_summary_*.csv`)
- Tabular performance data
- Import into spreadsheets for analysis
- Trend tracking over time

#### 4. Executive Summary (`analytics_performance_executive_summary_*.txt`)
- High-level performance assessment
- Key findings and recommendations
- Deployment readiness status

### Performance Scoring

#### Overall Performance Score Calculation
- **Critical Tests (80% weight)**: Core system functionality
- **Non-Critical Tests (20% weight)**: Enhancement features

#### Individual Test Scoring
- **90-100**: Excellent performance, ready for enterprise
- **75-89**: Good performance, minor optimizations recommended
- **60-74**: Acceptable performance, moderate improvements needed
- **<60**: Poor performance, significant optimization required

### Enterprise Readiness Assessment

#### Readiness Levels
- **Enterprise Ready**: All critical tests pass, score >85
- **Nearly Ready**: Most tests pass, score >75, minor optimizations needed
- **Needs Optimization**: Moderate performance gaps, score >65
- **Not Ready**: Major performance issues, score <65

## Performance Optimization Guide

### Common Performance Issues and Solutions

#### 1. Slow Dashboard Load Times (>3 seconds)

**Symptoms:**
- Dashboard takes longer than 3 seconds to load
- High database query times
- Large payload sizes

**Solutions:**
```ruby
# Implement data caching
Rails.cache.fetch("dashboard_metrics_#{brand.id}_#{time_range}", expires_in: 5.minutes) do
  expensive_dashboard_calculation
end

# Optimize database queries with proper indexing
add_index :social_media_metrics, [:platform, :date, :brand_id]
add_index :google_analytics_metrics, [:brand_id, :date, :metric_name]

# Implement pagination for large datasets
metrics = SocialMediaMetric.includes(:social_media_integration)
                          .where(date: date_range)
                          .page(params[:page])
                          .per(100)
```

#### 2. High API Response Times (>2 seconds)

**Symptoms:**
- API endpoints respond slowly
- Database query bottlenecks
- N+1 query problems

**Solutions:**
```ruby
# Optimize API responses with eager loading
def analytics_data
  @brand.social_media_metrics
        .includes(:social_media_integration)
        .where(date: date_range)
        .select(:platform, :metric_type, :value, :date)
end

# Implement response caching
def cached_analytics_summary
  Rails.cache.fetch("api_analytics_#{@brand.id}_#{params[:time_range]}", expires_in: 10.minutes) do
    Analytics::SummaryService.new(@brand, params[:time_range]).generate
  end
end

# Use database views for complex aggregations
execute <<-SQL
  CREATE VIEW analytics_summary AS
  SELECT 
    platform,
    DATE(date) as summary_date,
    SUM(CASE WHEN metric_type = 'reach' THEN value ELSE 0 END) as total_reach,
    SUM(CASE WHEN metric_type = 'engagement' THEN value ELSE 0 END) as total_engagement
  FROM social_media_metrics
  GROUP BY platform, DATE(date)
SQL
```

#### 3. WebSocket Connection Issues

**Symptoms:**
- Connection establishment takes >500ms
- Message latency >50ms
- Connection drops under load

**Solutions:**
```ruby
# Optimize WebSocket connection management
class AnalyticsDashboardChannel < ApplicationCable::Channel
  def subscribed
    stream_from "analytics_dashboard_#{current_brand.id}"
    
    # Implement connection pooling
    ConnectionPool.checkout(current_user.id)
  end
  
  def unsubscribed
    ConnectionPool.checkin(current_user.id)
  end
end

# Implement message compression
def broadcast_analytics_update(data)
  compressed_data = Zlib::Deflate.deflate(data.to_json)
  ActionCable.server.broadcast(
    "analytics_dashboard_#{brand_id}",
    { type: 'compressed_update', data: compressed_data }
  )
end
```

#### 4. High-Volume Data Processing Bottlenecks

**Symptoms:**
- Processing rate <12 records/second sustained
- Memory usage spikes during processing
- High error rates during ingestion

**Solutions:**
```ruby
# Implement efficient batch processing
class HighVolumeDataProcessor
  BATCH_SIZE = 5_000
  
  def process_large_dataset(data)
    data.each_slice(BATCH_SIZE) do |batch|
      ActiveRecord::Base.transaction do
        process_batch_efficiently(batch)
      end
      
      # Prevent memory buildup
      GC.start if batch_count % 10 == 0
    end
  end
  
  private
  
  def process_batch_efficiently(batch)
    # Use bulk insert for better performance
    SocialMediaMetric.insert_all(
      batch.map { |record| transform_record(record) }
    )
  end
end

# Implement parallel processing
require 'concurrent'

def parallel_process_platforms(platforms_data)
  futures = platforms_data.map do |platform, data|
    Concurrent::Future.execute do
      process_platform_data(platform, data)
    end
  end
  
  futures.map(&:value) # Wait for all to complete
end
```

#### 5. Database Query Optimization

**Symptoms:**
- Individual queries take >100ms
- Complex aggregations take >5 seconds
- High database CPU usage

**Solutions:**
```sql
-- Add proper indexes for analytics queries
CREATE INDEX idx_social_media_metrics_analytics 
ON social_media_metrics (brand_id, platform, date, metric_type);

CREATE INDEX idx_google_analytics_metrics_reporting
ON google_analytics_metrics (brand_id, date DESC, metric_name);

-- Optimize aggregation queries with partial indexes
CREATE INDEX idx_recent_metrics 
ON social_media_metrics (platform, metric_type, value) 
WHERE date >= CURRENT_DATE - INTERVAL '30 days';

-- Use materialized views for heavy aggregations
CREATE MATERIALIZED VIEW daily_analytics_summary AS
SELECT 
  brand_id,
  platform,
  date,
  SUM(CASE WHEN metric_type = 'reach' THEN value ELSE 0 END) as daily_reach,
  SUM(CASE WHEN metric_type = 'engagement' THEN value ELSE 0 END) as daily_engagement
FROM social_media_metrics
WHERE date >= CURRENT_DATE - INTERVAL '90 days'
GROUP BY brand_id, platform, date;

-- Refresh materialized view regularly
CREATE OR REPLACE FUNCTION refresh_analytics_summary()
RETURNS void AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY daily_analytics_summary;
END;
$$ LANGUAGE plpgsql;
```

## Continuous Performance Monitoring

### Setting Up Production Performance Monitoring

#### 1. Application Performance Monitoring (APM)

```ruby
# Gemfile
gem 'newrelic_rpm'  # or datadog, skylight, etc.

# config/newrelic.yml
production:
  app_name: Analytics Monitoring System
  license_key: <%= ENV['NEW_RELIC_LICENSE_KEY'] %>
  monitor_mode: true
  developer_mode: false
  
  # Custom performance tracking
  custom_insights_events:
    enabled: true
  
  # Database query analysis
  explain_enabled: true
  explain_threshold: 0.5
```

#### 2. Custom Performance Metrics

```ruby
# app/services/performance_monitor.rb
class PerformanceMonitor
  include Singleton
  
  def track_dashboard_load(brand_id, duration)
    NewRelic::Agent.record_metric('Custom/Dashboard/LoadTime', duration)
    
    if duration > 3.0
      NewRelic::Agent.notice_error(
        SlowDashboardError.new("Dashboard load time exceeded 3s: #{duration}s"),
        custom_params: { brand_id: brand_id, duration: duration }
      )
    end
  end
  
  def track_api_response(endpoint, duration)
    NewRelic::Agent.record_metric("Custom/API/#{endpoint}/ResponseTime", duration)
  end
  
  def track_data_processing_rate(rate)
    NewRelic::Agent.record_metric('Custom/DataProcessing/RecordsPerSecond', rate)
  end
end

# Usage in controllers
class AnalyticsController < ApplicationController
  def dashboard
    start_time = Time.current
    
    # Dashboard logic here
    
    duration = Time.current - start_time
    PerformanceMonitor.instance.track_dashboard_load(current_brand.id, duration)
  end
end
```

#### 3. Performance Alerting

```ruby
# config/initializers/performance_alerts.rb
if Rails.env.production?
  # Set up performance thresholds
  PerformanceThreshold.find_or_create_by(
    metric_name: 'dashboard_load_time',
    threshold_value: 3.0,
    alert_enabled: true
  )
  
  PerformanceThreshold.find_or_create_by(
    metric_name: 'api_response_time',
    threshold_value: 2.0,
    alert_enabled: true
  )
  
  # Monitor system resources
  Thread.new do
    loop do
      memory_usage = `ps -o rss= -p #{Process.pid}`.to_i / 1024.0
      cpu_usage = `ps -o %cpu= -p #{Process.pid}`.to_f
      
      if memory_usage > 2048 # 2GB
        PerformanceAlert.create!(
          alert_type: 'memory_usage',
          message: "High memory usage detected: #{memory_usage}MB",
          severity: 'high'
        )
      end
      
      sleep 60 # Check every minute
    end
  end
end
```

## Performance Test Automation

### Continuous Integration Integration

```yaml
# .github/workflows/performance-tests.yml
name: Performance Tests

on:
  push:
    branches: [main, staging]
  pull_request:
    branches: [main]
  schedule:
    - cron: '0 2 * * *' # Run daily at 2 AM

jobs:
  performance-tests:
    runs-on: ubuntu-latest
    
    services:
      postgres:
        image: postgres:13
        env:
          POSTGRES_PASSWORD: postgres
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
      
      redis:
        image: redis:6
        options: >-
          --health-cmd "redis-cli ping"
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
    
    steps:
    - uses: actions/checkout@v2
    
    - name: Set up Ruby
      uses: ruby/setup-ruby@v1
      with:
        bundler-cache: true
    
    - name: Setup Database
      run: |
        cp config/database.yml.example config/database.yml
        bundle exec rails db:create
        bundle exec rails db:migrate
      env:
        RAILS_ENV: test
        DATABASE_URL: postgres://postgres:postgres@localhost:5432/analytics_test
    
    - name: Run Performance Tests
      run: |
        # Set CI-appropriate performance test parameters
        export PERFORMANCE_TEST_SCALE_FACTOR=0.3
        export PERFORMANCE_TEST_DURATION=quick
        export PERFORMANCE_TEST_CONCURRENT_USERS=25
        export PERFORMANCE_TEST_WEBSOCKET_CONNECTIONS=50
        
        bundle exec rails test test/performance/analytics_performance_test_runner.rb
      env:
        RAILS_ENV: test
        DATABASE_URL: postgres://postgres:postgres@localhost:5432/analytics_test
        REDIS_URL: redis://localhost:6379/0
    
    - name: Upload Performance Reports
      uses: actions/upload-artifact@v2
      with:
        name: performance-reports
        path: tmp/analytics_performance_*
    
    - name: Performance Regression Check
      run: |
        # Compare with baseline performance metrics
        ruby scripts/performance_regression_check.rb
    
    - name: Comment PR with Performance Results
      if: github.event_name == 'pull_request'
      uses: actions/github-script@v6
      with:
        script: |
          const fs = require('fs');
          const summaryPath = 'tmp/analytics_performance_executive_summary_*.txt';
          const summary = fs.readFileSync(summaryPath, 'utf8');
          
          github.rest.issues.createComment({
            issue_number: context.issue.number,
            owner: context.repo.owner,
            repo: context.repo.repo,
            body: `## Performance Test Results\n\n\`\`\`\n${summary}\n\`\`\``
          });
```

### Performance Regression Detection

```ruby
# scripts/performance_regression_check.rb
require 'json'

class PerformanceRegressionChecker
  BASELINE_FILE = 'test/performance/baseline_performance.json'
  TOLERANCE = 0.15 # 15% performance degradation tolerance
  
  def initialize
    @current_results = load_current_results
    @baseline = load_baseline
  end
  
  def check_regressions
    regressions = []
    
    check_metric(regressions, 'overall_score', 'Overall Performance Score')
    check_metric(regressions, 'dashboard_load_time', 'Dashboard Load Time', inverse: true)
    check_metric(regressions, 'api_response_time', 'API Response Time', inverse: true)
    check_metric(regressions, 'data_processing_rate', 'Data Processing Rate')
    
    if regressions.any?
      puts "❌ Performance regressions detected:"
      regressions.each { |r| puts "  #{r}" }
      exit(1)
    else
      puts "✅ No performance regressions detected"
      update_baseline if should_update_baseline?
    end
  end
  
  private
  
  def check_metric(regressions, metric, name, inverse: false)
    current = @current_results[metric]
    baseline = @baseline[metric]
    
    return unless current && baseline
    
    if inverse
      # For metrics where lower is better (response times)
      degradation = (current - baseline) / baseline
      if degradation > TOLERANCE
        regressions << "#{name}: #{current} vs #{baseline} baseline (#{(degradation * 100).round(1)}% slower)"
      end
    else
      # For metrics where higher is better (scores, rates)
      degradation = (baseline - current) / baseline
      if degradation > TOLERANCE
        regressions << "#{name}: #{current} vs #{baseline} baseline (#{(degradation * 100).round(1)}% degradation)"
      end
    end
  end
  
  def load_current_results
    # Load from most recent test results
    report_files = Dir.glob('tmp/analytics_comprehensive_performance_report_*.json')
    latest_report = report_files.max_by { |f| File.mtime(f) }
    
    return {} unless latest_report
    
    JSON.parse(File.read(latest_report))
  end
  
  def load_baseline
    return {} unless File.exist?(BASELINE_FILE)
    JSON.parse(File.read(BASELINE_FILE))
  end
  
  def should_update_baseline?
    # Update baseline on main branch if performance improved
    ENV['GITHUB_REF'] == 'refs/heads/main' && performance_improved?
  end
  
  def performance_improved?
    return false unless @baseline['overall_score']
    @current_results['overall_score'] > @baseline['overall_score']
  end
  
  def update_baseline
    File.write(BASELINE_FILE, JSON.pretty_generate(@current_results))
    puts "✅ Updated performance baseline"
  end
end

PerformanceRegressionChecker.new.check_regressions
```

## Troubleshooting

### Common Issues and Solutions

#### 1. Tests Timing Out

```bash
# Increase test timeout
export PERFORMANCE_TEST_TIMEOUT=600  # 10 minutes

# Or reduce test scale
export PERFORMANCE_TEST_SCALE_FACTOR=0.5
```

#### 2. Memory Issues During Tests

```bash
# Monitor memory usage
export PERFORMANCE_TEST_MEMORY_TRACKING=true

# Run with smaller datasets
export PERFORMANCE_TEST_HIGH_VOLUME_RECORDS=10000
```

#### 3. Database Connection Issues

```bash
# Increase connection pool
export DATABASE_POOL_SIZE=50

# Or reduce concurrent operations
export PERFORMANCE_TEST_CONCURRENT_USERS=25
```

#### 4. WebSocket Connection Failures

```bash
# Check ActionCable configuration
# config/cable.yml should have appropriate adapter

# For test environment, use async adapter
test:
  adapter: async

# Reduce concurrent WebSocket connections for testing
export PERFORMANCE_TEST_WEBSOCKET_CONNECTIONS=50
```

### Getting Help

If you encounter issues with the performance tests:

1. **Check the logs**: Test output includes detailed timing and error information
2. **Review the reports**: Generated reports contain diagnostic information
3. **Adjust test parameters**: Use environment variables to scale tests appropriately
4. **Monitor system resources**: Ensure adequate CPU, memory, and database capacity
5. **Contact the development team**: Include performance reports and error logs

## Performance Test Maintenance

### Regular Maintenance Tasks

1. **Update baseline performance metrics** when system improvements are made
2. **Review and adjust performance targets** as business requirements change
3. **Update test data and scenarios** to reflect real-world usage patterns
4. **Monitor test execution time** and optimize for CI/CD pipeline efficiency
5. **Review and update performance optimization recommendations** based on production metrics

### Contributing to Performance Tests

When adding new features that could impact performance:

1. **Add corresponding performance tests** for new functionality
2. **Update performance targets** if new requirements are introduced  
3. **Document performance implications** of architectural changes
4. **Run full performance test suite** before merging major changes
5. **Update this README** with any new testing procedures or recommendations