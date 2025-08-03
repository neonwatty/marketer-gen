# frozen_string_literal: true

module Reports
  # TemplateSeederService creates default report templates
  # Provides commonly used report configurations for users
  class TemplateSeederService
    def self.seed_default_templates
      new.seed_default_templates
    end

    def seed_default_templates
      # Only seed if no public templates exist
      return if ReportTemplate.public_templates.any?

      Rails.logger.info "Seeding default report templates..."

      # Create admin user for templates if needed
      admin_user = User.find_by(email: "admin@system.local") ||
                   User.create!(
                     email: "admin@system.local",
                     first_name: "System",
                     last_name: "Admin",
                     role: "admin"
                   )

      templates = [
        marketing_overview_template(admin_user),
        social_media_performance_template(admin_user),
        email_marketing_template(admin_user),
        google_analytics_template(admin_user),
        campaign_roi_template(admin_user),
        weekly_summary_template(admin_user),
        executive_dashboard_template(admin_user)
      ]

      templates.each do |template_data|
        create_template(template_data)
      end

      Rails.logger.info "Completed seeding #{templates.count} default templates"
    end

    private

    def create_template(template_data)
      ReportTemplate.create_with_metrics(
        template_data[:attributes],
        template_data[:metrics]
      )
      Rails.logger.info "Created template: #{template_data[:attributes][:name]}"
    rescue StandardError => e
      Rails.logger.error "Failed to create template #{template_data[:attributes][:name]}: #{e.message}"
    end

    def marketing_overview_template(user)
      {
        attributes: {
          user: user,
          name: "Marketing Overview",
          description: "Comprehensive marketing performance across all channels",
          category: "marketing",
          template_type: "dashboard",
          is_public: true,
          configuration: {
            date_range: { type: "last_30_days" },
            layout: { columns: 3, responsive: true },
            styling: {
              theme: "professional",
              colors: [ "#3B82F6", "#10B981", "#F59E0B", "#EF4444" ],
              font_size: "medium"
            }
          }
        },
        metrics: [
          {
            metric_name: "total_visitors",
            display_name: "Website Visitors",
            data_source: "google_analytics",
            aggregation_type: "sum"
          },
          {
            metric_name: "conversion_rate",
            display_name: "Conversion Rate",
            data_source: "google_analytics",
            aggregation_type: "average"
          },
          {
            metric_name: "total_spend",
            display_name: "Marketing Spend",
            data_source: "campaigns",
            aggregation_type: "sum"
          },
          {
            metric_name: "campaign_roi",
            display_name: "Return on Investment",
            data_source: "campaigns",
            aggregation_type: "average"
          },
          {
            metric_name: "leads",
            display_name: "Total Leads",
            data_source: "crm",
            aggregation_type: "count"
          }
        ]
      }
    end

    def social_media_performance_template(user)
      {
        attributes: {
          user: user,
          name: "Social Media Performance",
          description: "Track engagement and reach across social platforms",
          category: "social_media",
          template_type: "standard",
          is_public: true,
          configuration: {
            date_range: { type: "last_7_days" },
            layout: { columns: 2, responsive: true }
          }
        },
        metrics: [
          {
            metric_name: "followers",
            display_name: "Total Followers",
            data_source: "social_media",
            aggregation_type: "sum"
          },
          {
            metric_name: "engagement_rate",
            display_name: "Engagement Rate",
            data_source: "social_media",
            aggregation_type: "average"
          },
          {
            metric_name: "reach",
            display_name: "Post Reach",
            data_source: "social_media",
            aggregation_type: "sum"
          },
          {
            metric_name: "impressions",
            display_name: "Impressions",
            data_source: "social_media",
            aggregation_type: "sum"
          }
        ]
      }
    end

    def email_marketing_template(user)
      {
        attributes: {
          user: user,
          name: "Email Marketing Performance",
          description: "Monitor email campaign effectiveness and subscriber growth",
          category: "email_marketing",
          template_type: "standard",
          is_public: true,
          configuration: {
            date_range: { type: "last_30_days" },
            layout: { columns: 2, responsive: true }
          }
        },
        metrics: [
          {
            metric_name: "sent_emails",
            display_name: "Emails Sent",
            data_source: "email_marketing",
            aggregation_type: "sum"
          },
          {
            metric_name: "open_rate",
            display_name: "Open Rate",
            data_source: "email_marketing",
            aggregation_type: "average"
          },
          {
            metric_name: "click_rate",
            display_name: "Click Rate",
            data_source: "email_marketing",
            aggregation_type: "average"
          },
          {
            metric_name: "unsubscribe_rate",
            display_name: "Unsubscribe Rate",
            data_source: "email_marketing",
            aggregation_type: "average"
          }
        ]
      }
    end

    def google_analytics_template(user)
      {
        attributes: {
          user: user,
          name: "Google Analytics Dashboard",
          description: "Essential website analytics and user behavior metrics",
          category: "analytics",
          template_type: "dashboard",
          is_public: true,
          configuration: {
            date_range: { type: "last_30_days" },
            layout: { columns: 3, responsive: true }
          }
        },
        metrics: [
          {
            metric_name: "page_views",
            display_name: "Page Views",
            data_source: "google_analytics",
            aggregation_type: "sum"
          },
          {
            metric_name: "sessions",
            display_name: "Sessions",
            data_source: "google_analytics",
            aggregation_type: "sum"
          },
          {
            metric_name: "users",
            display_name: "Users",
            data_source: "google_analytics",
            aggregation_type: "sum"
          },
          {
            metric_name: "bounce_rate",
            display_name: "Bounce Rate",
            data_source: "google_analytics",
            aggregation_type: "average"
          },
          {
            metric_name: "session_duration",
            display_name: "Avg Session Duration",
            data_source: "google_analytics",
            aggregation_type: "average"
          }
        ]
      }
    end

    def campaign_roi_template(user)
      {
        attributes: {
          user: user,
          name: "Campaign ROI Analysis",
          description: "Track campaign performance and return on investment",
          category: "performance",
          template_type: "detailed",
          is_public: true,
          configuration: {
            date_range: { type: "last_90_days" },
            layout: { columns: 2, responsive: true }
          }
        },
        metrics: [
          {
            metric_name: "campaign_performance",
            display_name: "Campaign Performance",
            data_source: "campaigns",
            aggregation_type: "average"
          },
          {
            metric_name: "total_spend",
            display_name: "Total Spend",
            data_source: "campaigns",
            aggregation_type: "sum"
          },
          {
            metric_name: "campaign_roi",
            display_name: "ROI",
            data_source: "campaigns",
            aggregation_type: "average"
          },
          {
            metric_name: "revenue",
            display_name: "Revenue Generated",
            data_source: "crm",
            aggregation_type: "sum"
          }
        ]
      }
    end

    def weekly_summary_template(user)
      {
        attributes: {
          user: user,
          name: "Weekly Summary Report",
          description: "Weekly overview of key marketing metrics",
          category: "general",
          template_type: "summary",
          is_public: true,
          configuration: {
            date_range: { type: "last_7_days" },
            layout: { columns: 1, responsive: true }
          }
        },
        metrics: [
          {
            metric_name: "total_visitors",
            display_name: "Weekly Visitors",
            data_source: "google_analytics",
            aggregation_type: "sum"
          },
          {
            metric_name: "leads",
            display_name: "New Leads",
            data_source: "crm",
            aggregation_type: "count"
          },
          {
            metric_name: "campaign_performance",
            display_name: "Campaign Performance",
            data_source: "campaigns",
            aggregation_type: "average"
          }
        ]
      }
    end

    def executive_dashboard_template(user)
      {
        attributes: {
          user: user,
          name: "Executive Dashboard",
          description: "High-level metrics for executive reporting",
          category: "general",
          template_type: "dashboard",
          is_public: true,
          configuration: {
            date_range: { type: "last_30_days" },
            layout: { columns: 2, responsive: true },
            styling: {
              theme: "executive",
              colors: [ "#1F2937", "#3B82F6", "#10B981", "#F59E0B" ],
              font_size: "large"
            }
          }
        },
        metrics: [
          {
            metric_name: "revenue",
            display_name: "Monthly Revenue",
            data_source: "crm",
            aggregation_type: "sum"
          },
          {
            metric_name: "leads",
            display_name: "Total Leads",
            data_source: "crm",
            aggregation_type: "count"
          },
          {
            metric_name: "campaign_roi",
            display_name: "Marketing ROI",
            data_source: "campaigns",
            aggregation_type: "average"
          },
          {
            metric_name: "conversion_rate",
            display_name: "Conversion Rate",
            data_source: "google_analytics",
            aggregation_type: "average"
          }
        ]
      }
    end
  end
end
