module Grafana
  # Representation of one specific panel in a {Dashboard} instance.
  class Panel
    # @return [Dashboard] parent {Dashboard} object
    attr_reader :dashboard

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

    # @return [String] SQL query string for the requested query letter
    def query(query_letter)
      query_item = @model['targets'].select { |item| item['refId'].to_s == query_letter.to_s }.first
      raise QueryLetterDoesNotExistError.new(query_letter, self) if query_item.nil?

      query_item['rawSql']
    end

    # @return [String] relative rendering URL for the panel, to create an image out of it
    def render_url
      "/render/d-solo/#{@dashboard.id}?panelId=#{@model['id']}"
    end
  end
end