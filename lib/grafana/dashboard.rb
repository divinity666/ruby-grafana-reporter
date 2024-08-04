# frozen_string_literal: true

module Grafana
  # Representation of one specific dashboard in a {Grafana} instance.
  class Dashboard
    # @return [Grafana] parent {Grafana} object
    attr_reader :grafana
    attr_reader :panels, :variables

    # @param model [Hash] converted JSON Hash of the grafana dashboard
    # @param grafana [Grafana] parent {Grafana} object
    def initialize(model, grafana)
      @grafana = grafana
      @model = model

      init_panels
      init_variables
    end

    # @return [String] +from+ time configured in the dashboard.
    def from_time
      return @model['time']['from'] if @model['time']

      nil
    end

    # @return [String] +to+ time configured in the dashboard.
    def to_time
      @model['time']['to'] if @model['time']
      nil
    end

    # @return [String] dashboard UID
    def id
      @model['uid']
    end

    # @return [String] dashboard title
    def title
      @model['title']
    end

    # @return [Panel] panel for the specified ID
    def panel(id)
      panels = @panels.select { |item| item.field('id') == id.to_i }
      raise PanelDoesNotExistError.new(id, self) if panels.empty?

      panels.first
    end

    private

    # store variables in array as objects of type Variable
    def init_variables
      @variables = []
      return unless @model.key?('templating')

      list = @model['templating']['list']
      return unless list.is_a? Array

      list.each do |item|
        begin
          @variables << Variable.new(item, self)
        rescue => e
          @grafana.logger.warn(e.message)
        end
      end
    end

    # read panels
    def init_panels
      @panels = []
      return unless @model.key?('panels')

      @model['panels'].each do |panel|
        if panel.key?('panels')
          panel['panels'].each do |subpanel|
            @panels << Panel.new(subpanel, self)
          end
        else
          @panels << Panel.new(panel, self)
        end
      end
    end
  end
end
