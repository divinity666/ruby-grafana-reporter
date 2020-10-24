module GrafanaReporter
  module Asciidoctor
    # This class is used to query properties from a {Grafana::Panel}, such as +description+,
    # +title+ etc.
    class PanelPropertyQuery < ::Grafana::AbstractPanelQuery
      include QueryMixin

      # @param panel [Grafana::Panel] panel object, for which the property shall be retrieved
      # @param property [String] queried property, e.g. +title+
      def initialize(panel, property)
        super(panel)
        @property = property
      end

      # Overrides the default method, as the query does not have to run against a SQL table,
      # but rather against the panel model.
      # @param grafana [Grafana::Grafana] grafana instance against which the panel property is queried
      # @return [String] fetched property
      def execute(grafana)
        return @result unless @result.nil?

        pre_process(grafana)
        @result = panel.field(@property)
        post_process
        @result

        # TODO: handle text (markdown and similar) properly
      end

      # Prepare query. Mainly here nothing special has to take place.
      def pre_process(_grafana)
        @from = nil
        @to = nil
      end

      # Replaces variables in the property field, if any are available.
      def post_process
        @result = replace_variables(@result, grafana_variables)
      end
    end
  end
end
