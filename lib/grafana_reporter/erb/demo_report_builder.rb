# frozen_string_literal: true

module GrafanaReporter
  module ERB
    # This class builds a demo report for ERB templates
    class DemoReportBuilder
      # This method is called if a demo report shall be built for the given {Grafana::Panel}.
      # @param panel [Grafana::Panel] panel object, for which a demo entry shall be created.
      # @return [String] String containing the entry, or nil if not possible for given panel
      def build_demo_entry(panel)
        return nil unless panel
        return nil unless panel.model['type'].include?('table')

        ref_id = nil
        panel.model['targets'].each do |item|
          if !item['hide'] && !panel.query(item['refId']).to_s.empty?
            ref_id = item['refId']
            break
          end
        end
        return nil unless ref_id

        <<~DEMO_ERB_TEMPLATE
          <%
          dashboard = '#{panel.dashboard.id}'
          instance = 'default'
          # load the panel object from grafana instance
          panel = @report.grafana(instance).dashboard(dashboard).panel(#{panel.id})
          # build a complete attributes hash, including the variables set for this report call
          # e.g. including command line parameters etc.
          attrs = @attributes.merge({ 'result_type' => 'panel_table', 'query' => '#{ref_id}' })
          query = QueryValueQuery.new(panel, variables: attrs)
          %>

          This is a test table for panel <%= panel.id %>:

          <%= query.execute %>

          For detailed API documentation you may start with:
            1) the AbstractReport (https://rubydoc.info/gems/ruby-grafana-reporter/GrafanaReporter/AbstractReport), or
            2) subclasses of the AbstractQuery (https://rubydoc.info/gems/ruby-grafana-reporter/GrafanaReporter/AbstractQuery)
        DEMO_ERB_TEMPLATE
      end
    end
  end
end
