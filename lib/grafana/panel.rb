# frozen_string_literal: true

module Grafana
  # Representation of one specific panel in a {Dashboard} instance.
  class Panel
    # @return [Dashboard] parent {Dashboard} object
    attr_reader :dashboard
    attr_reader :model

    # @param model [Hash] converted JSON Hash of the panel
    # @param dashboard [Dashboard] parent {Dashboard} object
    def initialize(model, dashboard)
      @model = model
      @dashboard = dashboard
    end

    # @return [String] content of the requested field or +''+ if not found
    def field(field)
      return @model[field] if @model.key?(field)

      ''
    end

    # @return [String] panel ID
    def id
      @model['id']
    end

    # @return [Datasource] datasource object specified for the current panel
    def datasource
      dashboard.grafana.datasource_by_name(@model['datasource'])
    end

    # @return [String] query string for the requested query letter
    def query(query_letter)
      query_item = @model['targets'].select { |item| item['refId'].to_s == query_letter.to_s }.first
      raise QueryLetterDoesNotExistError.new(query_letter, self) unless query_item

      begin
        datasource.raw_query_from_panel_model(query_item)
      rescue DatasourceDoesNotExistError
        nil
      rescue StandardError => e
        puts e.backtrace
        nil
      end
    end

    # @return [String] relative rendering URL for the panel, to create an image out of it
    def render_url
      "/render/d-solo/#{@dashboard.id}?panelId=#{@model['id']}"
    end
  end
end
