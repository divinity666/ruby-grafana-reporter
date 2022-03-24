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

      @datasource_uid_or_name = @model['datasource']
      if @model['datasource'].is_a?(Hash)
        @datasource_uid_or_name = @model['datasource']['uid']
      end
    end

    # @return [String] content of the requested field or +''+ if not found
    def field(field)
      return @model[field] if @model.key?(field)

      nil
    end

    # @return [String] panel ID
    def id
      @model['id']
    end

    # This method should always be called before the +datasource+ method of a
    # panel is invoked, to ensure that the variable names in the datasource
    # field are resolved.
    #
    # @param variables [Hash] variables hash, which should be use to resolve variable datasource
    def resolve_variable_datasource(variables)
      @datasource_uid_or_name = AbstractDatasource.new(nil).replace_variables(@datasource_uid_or_name, variables, 'raw')
    end

    # @return [Datasource] datasource object specified for the current panel
    def datasource
      if datasource_kind_is_uid?
        dashboard.grafana.datasource_by_uid(@datasource_uid_or_name)
      else
        dashboard.grafana.datasource_by_name(@datasource_uid_or_name)
      end
    end

    # @return [String] query string for the requested query letter
    def query(query_letter)
      query_item = @model['targets'].select { |item| item['refId'].to_s == query_letter.to_s }.first
      raise QueryLetterDoesNotExistError.new(query_letter, self) unless query_item

      datasource.raw_query_from_panel_model(query_item)
    end

    # @return [String] relative rendering URL for the panel, to create an image out of it
    def render_url
      "/render/d-solo/#{@dashboard.id}?panelId=#{@model['id']}"
    end

    private

    def datasource_kind_is_uid?
      if @model['datasource'].is_a?(Hash)
        return true
      end
      false
    end
  end
end
