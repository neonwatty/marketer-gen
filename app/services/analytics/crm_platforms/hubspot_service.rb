# frozen_string_literal: true

module Analytics
  module CrmPlatforms
    class HubspotService
      include ActiveModel::Model
      include RateLimitingService

      attr_accessor :integration, :access_token

      API_BASE_URL = "https://api.hubapi.com"
      API_VERSION = "v3"

      # HubSpot object types
      OBJECT_TYPES = {
        contacts: "contacts",
        deals: "deals",
        companies: "companies",
        tickets: "tickets"
      }.freeze

      # HubSpot lifecycle stages
      LIFECYCLE_STAGES = %w[
        subscriber
        lead
        marketingqualifiedlead
        salesqualifiedlead
        opportunity
        customer
        evangelist
        other
      ].freeze

      def initialize(integration)
        @integration = integration
        @access_token = integration.access_token
        validate_credentials!
      end

      # Contact/Lead synchronization
      def sync_contacts(limit: 100, after: nil)
        with_rate_limiting("hubspot_contacts_sync", user_id: integration.user_id) do
          params = build_contacts_params(limit, after)
          response = execute_api_request("#{API_BASE_URL}/crm/v3/objects/contacts", params)

          if response.success?
            contacts_data = response.data["results"]
            sync_results = process_contacts_batch(contacts_data)

            ServiceResult.success(data: {
              total_records: contacts_data.length,
              synced_count: sync_results[:created] + sync_results[:updated],
              created_count: sync_results[:created],
              updated_count: sync_results[:updated],
              errors: sync_results[:errors],
              next_after: response.data.dig("paging", "next", "after")
            })
          else
            ServiceResult.failure("Failed to fetch contacts from HubSpot: #{response.message}")
          end
        end
      rescue => e
        Rails.logger.error "HubSpot contacts sync failed: #{e.message}"
        ServiceResult.failure("Contacts sync failed: #{e.message}")
      end

      # Deal/Opportunity synchronization
      def sync_deals(limit: 100, after: nil)
        with_rate_limiting("hubspot_deals_sync", user_id: integration.user_id) do
          params = build_deals_params(limit, after)
          response = execute_api_request("#{API_BASE_URL}/crm/v3/objects/deals", params)

          if response.success?
            deals_data = response.data["results"]
            sync_results = process_deals_batch(deals_data)

            ServiceResult.success(data: {
              total_records: deals_data.length,
              synced_count: sync_results[:created] + sync_results[:updated],
              created_count: sync_results[:created],
              updated_count: sync_results[:updated],
              errors: sync_results[:errors],
              next_after: response.data.dig("paging", "next", "after")
            })
          else
            ServiceResult.failure("Failed to fetch deals from HubSpot: #{response.message}")
          end
        end
      rescue => e
        Rails.logger.error "HubSpot deals sync failed: #{e.message}"
        ServiceResult.failure("Deals sync failed: #{e.message}")
      end

      # Full sync for all enabled data types
      def full_sync
        sync_results = {
          contacts: { created: 0, updated: 0, errors: [] },
          deals: { created: 0, updated: 0, errors: [] }
        }

        # Sync contacts if enabled
        if integration.sync_contacts?
          contact_result = sync_all_contacts
          if contact_result.success?
            sync_results[:contacts] = contact_result.data
          else
            sync_results[:contacts][:errors] << contact_result.message
          end
        end

        # Sync deals if enabled
        if integration.sync_opportunities?
          deal_result = sync_all_deals
          if deal_result.success?
            sync_results[:deals] = deal_result.data
          else
            sync_results[:deals][:errors] << deal_result.message
          end
        end

        total_synced = sync_results[:contacts][:created] + sync_results[:contacts][:updated] +
                      sync_results[:deals][:created] + sync_results[:deals][:updated]

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
        with_rate_limiting("hubspot_test_connection", user_id: integration.user_id) do
          response = Faraday.get("#{API_BASE_URL}/oauth/v1/access-tokens/#{access_token}") do |req|
            req.headers["Accept"] = "application/json"
          end

          if response.success?
            data = JSON.parse(response.body)
            ServiceResult.success(data: {
              connection_status: "connected",
              hub_id: data["hub_id"],
              hub_domain: data["hub_domain"],
              user_id: data["user_id"]
            })
          else
            ServiceResult.failure("Connection test failed: #{response.status}")
          end
        end
      rescue => e
        ServiceResult.failure("Connection test failed: #{e.message}")
      end

      # Get available properties for object types
      def get_object_properties(object_type)
        with_rate_limiting("hubspot_properties", user_id: integration.user_id) do
          response = Faraday.get("#{API_BASE_URL}/crm/v3/properties/#{object_type}") do |req|
            req.headers["Authorization"] = "Bearer #{access_token}"
            req.headers["Accept"] = "application/json"
          end

          if response.success?
            data = JSON.parse(response.body)
            properties = data["results"].map do |prop|
              {
                name: prop["name"],
                label: prop["label"],
                type: prop["type"],
                required: prop["required"] || false,
                field_type: prop["fieldType"]
              }
            end
            ServiceResult.success(data: { properties: properties })
          else
            ServiceResult.failure("Failed to get properties for #{object_type}: #{response.status}")
          end
        end
      rescue => e
        ServiceResult.failure("Failed to get properties for #{object_type}: #{e.message}")
      end

      # Create or update contact
      def create_or_update_contact(contact_data)
        with_rate_limiting("hubspot_contact_upsert", user_id: integration.user_id) do
          if contact_data[:email].present?
            upsert_contact_by_email(contact_data)
          else
            create_contact(contact_data)
          end
        end
      end

      # Update contact lifecycle stage
      def update_contact_lifecycle_stage(contact_id, lifecycle_stage)
        with_rate_limiting("hubspot_lifecycle_update", user_id: integration.user_id) do
          return ServiceResult.failure("Invalid lifecycle stage") unless LIFECYCLE_STAGES.include?(lifecycle_stage)

          url = "#{API_BASE_URL}/crm/v3/objects/contacts/#{contact_id}"
          body = {
            properties: {
              lifecyclestage: lifecycle_stage
            }
          }

          response = Faraday.patch(url) do |req|
            req.headers["Authorization"] = "Bearer #{access_token}"
            req.headers["Content-Type"] = "application/json"
            req.body = body.to_json
          end

          if response.success?
            ServiceResult.success(data: { updated: true })
          else
            error_data = JSON.parse(response.body) rescue {}
            ServiceResult.failure(error_data["message"] || "Lifecycle stage update failed")
          end
        end
      rescue => e
        ServiceResult.failure("Lifecycle stage update failed: #{e.message}")
      end

      # Analytics and reporting
      def generate_analytics_report(start_date, end_date)
        with_rate_limiting("hubspot_analytics", user_id: integration.user_id) do
          analytics_data = {
            date_range: { start: start_date, end: end_date },
            contacts_metrics: calculate_contacts_metrics(start_date, end_date),
            deals_metrics: calculate_deals_metrics(start_date, end_date),
            lifecycle_metrics: calculate_lifecycle_metrics(start_date, end_date),
            conversion_metrics: calculate_conversion_metrics(start_date, end_date)
          }

          ServiceResult.success(data: analytics_data)
        end
      rescue => e
        ServiceResult.failure("Analytics report generation failed: #{e.message}")
      end

      # Get pipeline information
      def get_pipelines
        with_rate_limiting("hubspot_pipelines", user_id: integration.user_id) do
          response = Faraday.get("#{API_BASE_URL}/crm/v3/pipelines/deals") do |req|
            req.headers["Authorization"] = "Bearer #{access_token}"
            req.headers["Accept"] = "application/json"
          end

          if response.success?
            data = JSON.parse(response.body)
            pipelines = data["results"].map do |pipeline|
              {
                id: pipeline["id"],
                label: pipeline["label"],
                stages: pipeline["stages"].map do |stage|
                  {
                    id: stage["id"],
                    label: stage["label"],
                    display_order: stage["displayOrder"],
                    metadata: stage["metadata"]
                  }
                end
              }
            end
            ServiceResult.success(data: { pipelines: pipelines })
          else
            ServiceResult.failure("Failed to get pipelines: #{response.status}")
          end
        end
      rescue => e
        ServiceResult.failure("Failed to get pipelines: #{e.message}")
      end

      private

      def validate_credentials!
        raise ArgumentError, "Integration is required" unless integration
        raise ArgumentError, "Access token is missing" unless access_token.present?
      end

      def execute_api_request(url, params = {})
        response = Faraday.get(url) do |req|
          req.headers["Authorization"] = "Bearer #{access_token}"
          req.headers["Accept"] = "application/json"
          req.params = params
        end

        if response.success?
          data = JSON.parse(response.body)
          ServiceResult.success(data: data)
        else
          error_data = JSON.parse(response.body) rescue {}
          error_message = error_data["message"] || "Request failed with status #{response.status}"
          ServiceResult.failure(error_message)
        end
      rescue => e
        ServiceResult.failure("API request failed: #{e.message}")
      end

      def build_contacts_params(limit, after)
        params = {
          limit: limit,
          properties: contact_properties.join(",")
        }

        params[:after] = after if after.present?

        # Add filters for incremental sync
        if integration.last_sync_cursor.present?
          params[:filterGroups] = [
            {
              filters: [
                {
                  propertyName: "lastmodifieddate",
                  operator: "GT",
                  value: (integration.last_sync_cursor.to_time.to_i * 1000).to_s
                }
              ]
            }
          ].to_json
        end

        params
      end

      def build_deals_params(limit, after)
        params = {
          limit: limit,
          properties: deal_properties.join(",")
        }

        params[:after] = after if after.present?

        # Add filters for incremental sync
        if integration.last_sync_cursor.present?
          params[:filterGroups] = [
            {
              filters: [
                {
                  propertyName: "hs_lastmodifieddate",
                  operator: "GT",
                  value: (integration.last_sync_cursor.to_time.to_i * 1000).to_s
                }
              ]
            }
          ].to_json
        end

        params
      end

      def contact_properties
        field_mappings = integration.field_mappings_with_defaults["contact"] || {}

        # Base properties we always want
        base_properties = %w[
          firstname lastname email phone company jobtitle
          lifecyclestage hs_lead_status leadstatus
          createdate lastmodifieddate hs_analytics_source
          hs_analytics_source_data_1 hs_analytics_source_data_2
        ]

        # Add mapped custom properties
        custom_properties = field_mappings.values.reject { |prop| base_properties.include?(prop) }
        (base_properties + custom_properties).uniq
      end

      def deal_properties
        field_mappings = integration.field_mappings_with_defaults["deal"] || {}

        # Base properties for deals
        base_properties = %w[
          dealname amount closedate dealstage pipeline
          dealtype hs_deal_source_id createdate
          hs_lastmodifieddate hubspot_owner_id
          hs_analytics_source hs_deal_amount_calculation_preference
        ]

        # Add mapped custom properties
        custom_properties = field_mappings.values.reject { |prop| base_properties.include?(prop) }
        (base_properties + custom_properties).uniq
      end

      def process_contacts_batch(contacts_data)
        created_count = 0
        updated_count = 0
        errors = []

        contacts_data.each do |hubspot_contact|
          begin
            contact_attrs = map_hubspot_contact_to_attributes(hubspot_contact)
            existing_contact = integration.crm_leads.find_by(crm_id: hubspot_contact["id"])

            if existing_contact
              existing_contact.update!(contact_attrs)
              updated_count += 1
            else
              integration.crm_leads.create!(contact_attrs)
              created_count += 1
            end
          rescue => e
            errors << "Contact #{hubspot_contact['id']}: #{e.message}"
            Rails.logger.error "Failed to process HubSpot contact #{hubspot_contact['id']}: #{e.message}"
          end
        end

        # Update sync cursor
        if contacts_data.any?
          latest_modified_times = contacts_data.map do |contact|
            timestamp = contact.dig("properties", "lastmodifieddate")
            timestamp ? Time.at(timestamp.to_i / 1000) : nil
          end.compact

          if latest_modified_times.any?
            latest_modified = latest_modified_times.max
            integration.update!(last_sync_cursor: latest_modified)
          end
        end

        {
          created: created_count,
          updated: updated_count,
          errors: errors
        }
      end

      def process_deals_batch(deals_data)
        created_count = 0
        updated_count = 0
        errors = []

        deals_data.each do |hubspot_deal|
          begin
            deal_attrs = map_hubspot_deal_to_attributes(hubspot_deal)
            existing_deal = integration.crm_opportunities.find_by(crm_id: hubspot_deal["id"])

            if existing_deal
              existing_deal.update!(deal_attrs)
              updated_count += 1
            else
              integration.crm_opportunities.create!(deal_attrs)
              created_count += 1
            end
          rescue => e
            errors << "Deal #{hubspot_deal['id']}: #{e.message}"
            Rails.logger.error "Failed to process HubSpot deal #{hubspot_deal['id']}: #{e.message}"
          end
        end

        # Update sync cursor
        if deals_data.any?
          latest_modified_times = deals_data.map do |deal|
            timestamp = deal.dig("properties", "hs_lastmodifieddate")
            timestamp ? Time.at(timestamp.to_i / 1000) : nil
          end.compact

          if latest_modified_times.any?
            latest_modified = latest_modified_times.max
            integration.update!(last_sync_cursor: latest_modified)
          end
        end

        {
          created: created_count,
          updated: updated_count,
          errors: errors
        }
      end

      def map_hubspot_contact_to_attributes(hubspot_contact)
        props = hubspot_contact["properties"]

        # Map HubSpot lifecycle stage to our standard format
        lifecycle_stage = map_hubspot_lifecycle_stage(props["lifecyclestage"])

        {
          crm_id: hubspot_contact["id"],
          brand: integration.brand,
          first_name: props["firstname"],
          last_name: props["lastname"],
          email: props["email"],
          phone: props["phone"],
          company: props["company"],
          title: props["jobtitle"],
          status: props["hs_lead_status"] || props["leadstatus"],
          lifecycle_stage: lifecycle_stage,
          marketing_qualified: lifecycle_stage == "marketing_qualified_lead",
          sales_qualified: lifecycle_stage == "sales_qualified_lead",
          source: props["hs_analytics_source"],
          original_source: props["hs_analytics_source"],
          original_campaign: props["hs_analytics_source_data_1"],
          utm_parameters: extract_utm_parameters(props),
          crm_created_at: parse_hubspot_timestamp(props["createdate"]),
          crm_updated_at: parse_hubspot_timestamp(props["lastmodifieddate"]),
          last_synced_at: Time.current,
          raw_data: hubspot_contact
        }
      end

      def map_hubspot_deal_to_attributes(hubspot_deal)
        props = hubspot_deal["properties"]

        close_date = parse_hubspot_date(props["closedate"])
        is_closed = %w[closedwon closedlost].include?(props["dealstage"]&.downcase&.gsub(/\s/, ""))
        is_won = props["dealstage"]&.downcase&.gsub(/\s/, "") == "closedwon"

        {
          crm_id: hubspot_deal["id"],
          brand: integration.brand,
          name: props["dealname"],
          amount: props["amount"]&.to_f,
          stage: props["dealstage"],
          type: props["dealtype"],
          close_date: close_date,
          pipeline_id: props["pipeline"],
          owner_id: props["hubspot_owner_id"],
          lead_source: props["hs_analytics_source"],
          original_source: props["hs_analytics_source"],
          is_closed: is_closed,
          is_won: is_won,
          closed_at: is_closed ? Time.current : nil,
          crm_created_at: parse_hubspot_timestamp(props["createdate"]),
          crm_updated_at: parse_hubspot_timestamp(props["hs_lastmodifieddate"]),
          last_synced_at: Time.current,
          raw_data: hubspot_deal
        }
      end

      def map_hubspot_lifecycle_stage(hubspot_stage)
        case hubspot_stage&.downcase
        when "subscriber"
          "subscriber"
        when "lead"
          "lead"
        when "marketingqualifiedlead"
          "marketing_qualified_lead"
        when "salesqualifiedlead"
          "sales_qualified_lead"
        when "opportunity"
          "opportunity"
        when "customer"
          "customer"
        when "evangelist"
          "evangelist"
        else
          "other"
        end
      end

      def extract_utm_parameters(props)
        {
          utm_source: props["hs_analytics_source"],
          utm_medium: props["hs_analytics_source_data_1"],
          utm_campaign: props["hs_analytics_source_data_2"]
        }.compact
      end

      def parse_hubspot_timestamp(timestamp)
        return nil unless timestamp.present?
        Time.at(timestamp.to_i / 1000)
      rescue
        nil
      end

      def parse_hubspot_date(date_string)
        return nil unless date_string.present?
        Date.parse(date_string)
      rescue
        nil
      end

      def sync_all_contacts
        all_results = { created: 0, updated: 0, errors: [] }
        after = nil

        loop do
          result = sync_contacts(limit: 100, after: after)

          if result.success?
            data = result.data
            all_results[:created] += data[:created_count]
            all_results[:updated] += data[:updated_count]
            all_results[:errors].concat(data[:errors])

            after = data[:next_after]
            break unless after.present?
          else
            all_results[:errors] << result.message
            break
          end
        end

        ServiceResult.success(data: all_results)
      end

      def sync_all_deals
        all_results = { created: 0, updated: 0, errors: [] }
        after = nil

        loop do
          result = sync_deals(limit: 100, after: after)

          if result.success?
            data = result.data
            all_results[:created] += data[:created_count]
            all_results[:updated] += data[:updated_count]
            all_results[:errors].concat(data[:errors])

            after = data[:next_after]
            break unless after.present?
          else
            all_results[:errors] << result.message
            break
          end
        end

        ServiceResult.success(data: all_results)
      end

      def calculate_contacts_metrics(start_date, end_date)
        # Use HubSpot's analytics API or custom queries
        # This is a simplified version - you'd want to use HubSpot's reporting API
        {}
      end

      def calculate_deals_metrics(start_date, end_date)
        # Use HubSpot's analytics API for deal metrics
        {}
      end

      def calculate_lifecycle_metrics(start_date, end_date)
        # Calculate lifecycle stage progression metrics
        {}
      end

      def calculate_conversion_metrics(start_date, end_date)
        # Calculate conversion rates between lifecycle stages
        {}
      end

      def create_contact(contact_data)
        url = "#{API_BASE_URL}/crm/v3/objects/contacts"

        response = Faraday.post(url) do |req|
          req.headers["Authorization"] = "Bearer #{access_token}"
          req.headers["Content-Type"] = "application/json"
          req.body = { properties: contact_data }.to_json
        end

        if response.success?
          data = JSON.parse(response.body)
          ServiceResult.success(data: { id: data["id"] })
        else
          error_data = JSON.parse(response.body) rescue {}
          ServiceResult.failure(error_data["message"] || "Contact creation failed")
        end
      rescue => e
        ServiceResult.failure("Contact creation failed: #{e.message}")
      end

      def upsert_contact_by_email(contact_data)
        email = contact_data.delete(:email)
        url = "#{API_BASE_URL}/crm/v3/objects/contacts/#{email}?idProperty=email"

        response = Faraday.patch(url) do |req|
          req.headers["Authorization"] = "Bearer #{access_token}"
          req.headers["Content-Type"] = "application/json"
          req.body = { properties: contact_data }.to_json
        end

        if response.success?
          data = JSON.parse(response.body)
          ServiceResult.success(data: { id: data["id"] })
        else
          # If contact doesn't exist, create it
          if response.status == 404
            create_contact(contact_data.merge(email: email))
          else
            error_data = JSON.parse(response.body) rescue {}
            ServiceResult.failure(error_data["message"] || "Contact upsert failed")
          end
        end
      rescue => e
        ServiceResult.failure("Contact upsert failed: #{e.message}")
      end
    end
  end
end
