# frozen_string_literal: true

module Analytics
  module CrmPlatforms
    class SalesforceService
      include ActiveModel::Model
      include RateLimitingService

      attr_accessor :integration, :access_token, :instance_url

      API_VERSION = "v58.0"

      # Salesforce object types
      SOBJECT_TYPES = {
        leads: "Lead",
        opportunities: "Opportunity",
        contacts: "Contact",
        accounts: "Account",
        campaigns: "Campaign",
        campaign_members: "CampaignMember"
      }.freeze

      def initialize(integration)
        @integration = integration
        @access_token = integration.access_token
        @instance_url = integration.instance_url
        validate_credentials!
      end

      # Lead synchronization
      def sync_leads(limit: 200, offset: 0)
        with_rate_limiting("salesforce_leads_sync", user_id: integration.user_id) do
          soql_query = build_leads_query(limit, offset)
          response = execute_soql_query(soql_query)

          if response.success?
            leads_data = response.data["records"]
            sync_results = process_leads_batch(leads_data)

            ServiceResult.success(data: {
              total_records: response.data["totalSize"],
              synced_count: sync_results[:created] + sync_results[:updated],
              created_count: sync_results[:created],
              updated_count: sync_results[:updated],
              errors: sync_results[:errors]
            })
          else
            ServiceResult.failure("Failed to fetch leads from Salesforce: #{response.message}")
          end
        end
      rescue => e
        Rails.logger.error "Salesforce leads sync failed: #{e.message}"
        ServiceResult.failure("Leads sync failed: #{e.message}")
      end

      # Opportunity synchronization
      def sync_opportunities(limit: 200, offset: 0)
        with_rate_limiting("salesforce_opportunities_sync", user_id: integration.user_id) do
          soql_query = build_opportunities_query(limit, offset)
          response = execute_soql_query(soql_query)

          if response.success?
            opportunities_data = response.data["records"]
            sync_results = process_opportunities_batch(opportunities_data)

            ServiceResult.success(data: {
              total_records: response.data["totalSize"],
              synced_count: sync_results[:created] + sync_results[:updated],
              created_count: sync_results[:created],
              updated_count: sync_results[:updated],
              errors: sync_results[:errors]
            })
          else
            ServiceResult.failure("Failed to fetch opportunities from Salesforce: #{response.message}")
          end
        end
      rescue => e
        Rails.logger.error "Salesforce opportunities sync failed: #{e.message}"
        ServiceResult.failure("Opportunities sync failed: #{e.message}")
      end

      # Full sync for all enabled data types
      def full_sync
        sync_results = {
          leads: { created: 0, updated: 0, errors: [] },
          opportunities: { created: 0, updated: 0, errors: [] }
        }

        # Sync leads if enabled
        if integration.sync_leads?
          lead_result = sync_all_leads
          if lead_result.success?
            sync_results[:leads] = lead_result.data
          else
            sync_results[:leads][:errors] << lead_result.message
          end
        end

        # Sync opportunities if enabled
        if integration.sync_opportunities?
          opp_result = sync_all_opportunities
          if opp_result.success?
            sync_results[:opportunities] = opp_result.data
          else
            sync_results[:opportunities][:errors] << opp_result.message
          end
        end

        total_synced = sync_results[:leads][:created] + sync_results[:leads][:updated] +
                      sync_results[:opportunities][:created] + sync_results[:opportunities][:updated]

        integration.mark_successful_sync!

        ServiceResult.success(data: {
          total_synced: total_synced,
          results: sync_results
        })
      rescue => e
        integration.update_last_error!("Full sync failed: #{e.message}")
        ServiceResult.failure("Full sync failed: #{e.message}")
      end

      # Test connection
      def test_connection
        with_rate_limiting("salesforce_test_connection", user_id: integration.user_id) do
          response = Faraday.get("#{instance_url}/services/data/#{API_VERSION}/") do |req|
            req.headers["Authorization"] = "Bearer #{access_token}"
            req.headers["Accept"] = "application/json"
          end

          if response.success?
            data = JSON.parse(response.body)
            ServiceResult.success(data: {
              connection_status: "connected",
              api_version: API_VERSION,
              organization_id: extract_org_id_from_instance_url
            })
          else
            ServiceResult.failure("Connection test failed: #{response.status}")
          end
        end
      rescue => e
        ServiceResult.failure("Connection test failed: #{e.message}")
      end

      # Get available fields for object types
      def get_object_fields(sobject_type)
        with_rate_limiting("salesforce_describe", user_id: integration.user_id) do
          response = Faraday.get("#{instance_url}/services/data/#{API_VERSION}/sobjects/#{sobject_type}/describe/") do |req|
            req.headers["Authorization"] = "Bearer #{access_token}"
            req.headers["Accept"] = "application/json"
          end

          if response.success?
            data = JSON.parse(response.body)
            fields = data["fields"].map do |field|
              {
                name: field["name"],
                label: field["label"],
                type: field["type"],
                required: !field["nillable"],
                length: field["length"]
              }
            end
            ServiceResult.success(data: { fields: fields })
          else
            ServiceResult.failure("Failed to describe #{sobject_type}: #{response.status}")
          end
        end
      rescue => e
        ServiceResult.failure("Failed to get fields for #{sobject_type}: #{e.message}")
      end

      # Create or update lead
      def create_or_update_lead(lead_data)
        with_rate_limiting("salesforce_lead_upsert", user_id: integration.user_id) do
          # Use external ID for upsert if available, otherwise create
          if lead_data[:external_id].present?
            upsert_lead_by_external_id(lead_data)
          else
            create_lead(lead_data)
          end
        end
      end

      # Analytics and reporting
      def generate_analytics_report(start_date, end_date)
        with_rate_limiting("salesforce_analytics", user_id: integration.user_id) do
          analytics_data = {
            date_range: { start: start_date, end: end_date },
            leads_metrics: calculate_leads_metrics(start_date, end_date),
            opportunities_metrics: calculate_opportunities_metrics(start_date, end_date),
            conversion_metrics: calculate_conversion_metrics(start_date, end_date),
            pipeline_metrics: calculate_pipeline_metrics(start_date, end_date)
          }

          ServiceResult.success(data: analytics_data)
        end
      rescue => e
        ServiceResult.failure("Analytics report generation failed: #{e.message}")
      end

      private

      def validate_credentials!
        raise ArgumentError, "Integration is required" unless integration
        raise ArgumentError, "Access token is missing" unless access_token.present?
        raise ArgumentError, "Instance URL is missing" unless instance_url.present?
      end

      def execute_soql_query(query)
        encoded_query = URI.encode_www_form_component(query)
        url = "#{instance_url}/services/data/#{API_VERSION}/query/?q=#{encoded_query}"

        response = Faraday.get(url) do |req|
          req.headers["Authorization"] = "Bearer #{access_token}"
          req.headers["Accept"] = "application/json"
        end

        if response.success?
          data = JSON.parse(response.body)
          ServiceResult.success(data: data)
        else
          error_data = JSON.parse(response.body) rescue {}
          error_message = error_data.dig(0, "message") || "Query failed with status #{response.status}"
          ServiceResult.failure(error_message)
        end
      rescue => e
        ServiceResult.failure("SOQL query execution failed: #{e.message}")
      end

      def build_leads_query(limit, offset)
        field_mappings = integration.field_mappings_with_defaults["lead"] || {}

        # Base fields that we always want to sync
        base_fields = %w[Id FirstName LastName Email Company Phone Status LeadSource CreatedDate LastModifiedDate]

        # Add mapped custom fields
        custom_fields = field_mappings.values.reject { |field| base_fields.include?(field) }
        all_fields = (base_fields + custom_fields).uniq

        # Build WHERE clause for incremental sync
        where_clause = if integration.last_sync_cursor.present?
          "LastModifiedDate > #{integration.last_sync_cursor.iso8601}"
        else
          "CreatedDate >= LAST_N_DAYS:30"  # Initial sync: last 30 days
        end

        "SELECT #{all_fields.join(', ')} FROM Lead WHERE #{where_clause} ORDER BY LastModifiedDate ASC LIMIT #{limit} OFFSET #{offset}"
      end

      def build_opportunities_query(limit, offset)
        field_mappings = integration.field_mappings_with_defaults["opportunity"] || {}

        # Base fields for opportunities
        base_fields = %w[Id Name AccountId Amount CloseDate StageName Probability Type LeadSource CreatedDate LastModifiedDate OwnerId]

        # Add mapped custom fields
        custom_fields = field_mappings.values.reject { |field| base_fields.include?(field) }
        all_fields = (base_fields + custom_fields).uniq

        # Build WHERE clause for incremental sync
        where_clause = if integration.last_sync_cursor.present?
          "LastModifiedDate > #{integration.last_sync_cursor.iso8601}"
        else
          "CreatedDate >= LAST_N_DAYS:30"  # Initial sync: last 30 days
        end

        "SELECT #{all_fields.join(', ')} FROM Opportunity WHERE #{where_clause} ORDER BY LastModifiedDate ASC LIMIT #{limit} OFFSET #{offset}"
      end

      def process_leads_batch(leads_data)
        created_count = 0
        updated_count = 0
        errors = []

        leads_data.each do |salesforce_lead|
          begin
            lead_attrs = map_salesforce_lead_to_attributes(salesforce_lead)
            existing_lead = integration.crm_leads.find_by(crm_id: salesforce_lead["Id"])

            if existing_lead
              existing_lead.update!(lead_attrs)
              updated_count += 1
            else
              integration.crm_leads.create!(lead_attrs)
              created_count += 1
            end
          rescue => e
            errors << "Lead #{salesforce_lead['Id']}: #{e.message}"
            Rails.logger.error "Failed to process Salesforce lead #{salesforce_lead['Id']}: #{e.message}"
          end
        end

        # Update sync cursor
        if leads_data.any?
          latest_modified = leads_data.map { |lead| Time.parse(lead["LastModifiedDate"]) }.max
          integration.update!(last_sync_cursor: latest_modified)
        end

        {
          created: created_count,
          updated: updated_count,
          errors: errors
        }
      end

      def process_opportunities_batch(opportunities_data)
        created_count = 0
        updated_count = 0
        errors = []

        opportunities_data.each do |salesforce_opp|
          begin
            opp_attrs = map_salesforce_opportunity_to_attributes(salesforce_opp)
            existing_opp = integration.crm_opportunities.find_by(crm_id: salesforce_opp["Id"])

            if existing_opp
              existing_opp.update!(opp_attrs)
              updated_count += 1
            else
              integration.crm_opportunities.create!(opp_attrs)
              created_count += 1
            end
          rescue => e
            errors << "Opportunity #{salesforce_opp['Id']}: #{e.message}"
            Rails.logger.error "Failed to process Salesforce opportunity #{salesforce_opp['Id']}: #{e.message}"
          end
        end

        # Update sync cursor
        if opportunities_data.any?
          latest_modified = opportunities_data.map { |opp| Time.parse(opp["LastModifiedDate"]) }.max
          integration.update!(last_sync_cursor: latest_modified)
        end

        {
          created: created_count,
          updated: updated_count,
          errors: errors
        }
      end

      def map_salesforce_lead_to_attributes(salesforce_lead)
        {
          crm_id: salesforce_lead["Id"],
          brand: integration.brand,
          first_name: salesforce_lead["FirstName"],
          last_name: salesforce_lead["LastName"],
          email: salesforce_lead["Email"],
          phone: salesforce_lead["Phone"],
          company: salesforce_lead["Company"],
          status: salesforce_lead["Status"],
          source: salesforce_lead["LeadSource"],
          crm_created_at: Time.parse(salesforce_lead["CreatedDate"]),
          crm_updated_at: Time.parse(salesforce_lead["LastModifiedDate"]),
          last_synced_at: Time.current,
          raw_data: salesforce_lead
        }
      end

      def map_salesforce_opportunity_to_attributes(salesforce_opp)
        {
          crm_id: salesforce_opp["Id"],
          brand: integration.brand,
          name: salesforce_opp["Name"],
          account_id: salesforce_opp["AccountId"],
          amount: salesforce_opp["Amount"],
          stage: salesforce_opp["StageName"],
          type: salesforce_opp["Type"],
          probability: salesforce_opp["Probability"],
          close_date: salesforce_opp["CloseDate"] ? Date.parse(salesforce_opp["CloseDate"]) : nil,
          lead_source: salesforce_opp["LeadSource"],
          owner_id: salesforce_opp["OwnerId"],
          is_closed: %w[Closed\ Won Closed\ Lost].include?(salesforce_opp["StageName"]),
          is_won: salesforce_opp["StageName"] == "Closed Won",
          crm_created_at: Time.parse(salesforce_opp["CreatedDate"]),
          crm_updated_at: Time.parse(salesforce_opp["LastModifiedDate"]),
          last_synced_at: Time.current,
          raw_data: salesforce_opp
        }
      end

      def sync_all_leads
        all_results = { created: 0, updated: 0, errors: [] }
        offset = 0
        limit = 200

        loop do
          result = sync_leads(limit: limit, offset: offset)

          if result.success?
            data = result.data
            all_results[:created] += data[:created_count]
            all_results[:updated] += data[:updated_count]
            all_results[:errors].concat(data[:errors])

            # Stop if we've retrieved all records
            break if data[:synced_count] < limit
            offset += limit
          else
            all_results[:errors] << result.message
            break
          end
        end

        ServiceResult.success(data: all_results)
      end

      def sync_all_opportunities
        all_results = { created: 0, updated: 0, errors: [] }
        offset = 0
        limit = 200

        loop do
          result = sync_opportunities(limit: limit, offset: offset)

          if result.success?
            data = result.data
            all_results[:created] += data[:created_count]
            all_results[:updated] += data[:updated_count]
            all_results[:errors].concat(data[:errors])

            # Stop if we've retrieved all records
            break if data[:synced_count] < limit
            offset += limit
          else
            all_results[:errors] << result.message
            break
          end
        end

        ServiceResult.success(data: all_results)
      end

      def calculate_leads_metrics(start_date, end_date)
        query = <<~SOQL
          SELECT COUNT(Id) total_leads,
                 COUNT_DISTINCT(CASE WHEN CreatedDate >= #{start_date.iso8601} AND CreatedDate <= #{end_date.iso8601} THEN Id END) new_leads,
                 COUNT_DISTINCT(CASE WHEN IsConverted = true THEN Id END) converted_leads
          FROM Lead
          WHERE CreatedDate <= #{end_date.iso8601}
        SOQL

        response = execute_soql_query(query)
        response.success? ? response.data["records"].first : {}
      end

      def calculate_opportunities_metrics(start_date, end_date)
        query = <<~SOQL
          SELECT COUNT(Id) total_opportunities,
                 COUNT_DISTINCT(CASE WHEN CreatedDate >= #{start_date.iso8601} AND CreatedDate <= #{end_date.iso8601} THEN Id END) new_opportunities,
                 COUNT_DISTINCT(CASE WHEN IsWon = true THEN Id END) won_opportunities,
                 SUM(Amount) total_amount,
                 SUM(CASE WHEN IsWon = true THEN Amount ELSE 0 END) won_amount
          FROM Opportunity
          WHERE CreatedDate <= #{end_date.iso8601}
        SOQL

        response = execute_soql_query(query)
        response.success? ? response.data["records"].first : {}
      end

      def calculate_conversion_metrics(start_date, end_date)
        # This would involve more complex queries to calculate conversion rates
        # between different stages in the sales funnel
        {}
      end

      def calculate_pipeline_metrics(start_date, end_date)
        query = <<~SOQL
          SELECT StageName, COUNT(Id) stage_count, SUM(Amount) stage_value
          FROM Opportunity
          WHERE IsClosed = false
          GROUP BY StageName
        SOQL

        response = execute_soql_query(query)
        if response.success?
          { pipeline_breakdown: response.data["records"] }
        else
          {}
        end
      end

      def create_lead(lead_data)
        url = "#{instance_url}/services/data/#{API_VERSION}/sobjects/Lead/"

        response = Faraday.post(url) do |req|
          req.headers["Authorization"] = "Bearer #{access_token}"
          req.headers["Content-Type"] = "application/json"
          req.body = lead_data.to_json
        end

        if response.success?
          data = JSON.parse(response.body)
          ServiceResult.success(data: { id: data["id"] })
        else
          error_data = JSON.parse(response.body) rescue {}
          ServiceResult.failure(error_data.dig(0, "message") || "Lead creation failed")
        end
      rescue => e
        ServiceResult.failure("Lead creation failed: #{e.message}")
      end

      def upsert_lead_by_external_id(lead_data)
        external_id = lead_data.delete(:external_id)
        url = "#{instance_url}/services/data/#{API_VERSION}/sobjects/Lead/External_Id__c/#{external_id}"

        response = Faraday.patch(url) do |req|
          req.headers["Authorization"] = "Bearer #{access_token}"
          req.headers["Content-Type"] = "application/json"
          req.body = lead_data.to_json
        end

        if response.success?
          data = JSON.parse(response.body) rescue {}
          ServiceResult.success(data: { id: data["id"] })
        else
          error_data = JSON.parse(response.body) rescue {}
          ServiceResult.failure(error_data.dig(0, "message") || "Lead upsert failed")
        end
      rescue => e
        ServiceResult.failure("Lead upsert failed: #{e.message}")
      end

      def extract_org_id_from_instance_url
        # Extract organization ID from Salesforce instance URL
        # This is a simplified extraction - in practice, you might need to make an API call
        uri = URI.parse(instance_url)
        uri.host.split(".").first
      end
    end
  end
end
