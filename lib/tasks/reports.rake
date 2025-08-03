# frozen_string_literal: true

namespace :reports do
  desc "Seed default report templates"
  task seed_templates: :environment do
    puts "Seeding default report templates..."
    Reports::TemplateSeederService.seed_default_templates
    puts "Report templates seeded successfully!"
  end

  desc "Clean up expired report exports"
  task cleanup_exports: :environment do
    puts "Cleaning up expired report exports..."
    ReportExport.cleanup_expired!
    puts "Cleanup completed!"
  end

  desc "Start report schedule monitoring (use with sidekiq/background jobs)"
  task start_scheduler: :environment do
    puts "Starting report scheduler..."
    ReportScheduleJob.perform_later
    puts "Report scheduler started!"
  end

  desc "Generate sample report data for testing"
  task generate_sample_data: :environment do
    puts "Generating sample report data..."
    
    # This would create sample reports for testing
    user = User.first || User.create!(
      email: "test@example.com",
      first_name: "Test",
      last_name: "User",
      password: "password"
    )
    
    brand = user.brands.first || user.brands.create!(
      name: "Sample Brand",
      description: "A sample brand for testing"
    )
    
    # Create a sample report
    report = brand.custom_reports.create!(
      user: user,
      name: "Sample Marketing Report",
      description: "A sample report for testing the system",
      report_type: "dashboard",
      status: "active"
    )
    
    # Add some metrics
    report.report_metrics.create!([
      {
        metric_name: "page_views",
        display_name: "Page Views",
        data_source: "google_analytics",
        aggregation_type: "sum",
        sort_order: 1
      },
      {
        metric_name: "conversion_rate",
        display_name: "Conversion Rate",
        data_source: "google_analytics",
        aggregation_type: "average",
        sort_order: 2
      }
    ])
    
    puts "Sample report created: #{report.name} (ID: #{report.id})"
    puts "Sample data generation completed!"
  end
end