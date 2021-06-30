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

        <<~EOS
        <%
        dashboard = '#{panel.dashboard.id}'
        instance = 'default'
        panel = @report.grafana(instance).dashboard(dashboard).panel(#{panel.id})
        query = QueryValueQuery.new(panel, variables: { 'result_type' => 'panel_table', 'query' => '#{ref_id}', 'column_divider' => ', ' })
        %>

        This is a test table for panel <%= panel.id %>:

        <%= query.execute.join("\\n") %>

        For detailed API documentation you may start with:
          1) the AbstractReport (https://rubydoc.info/gems/ruby-grafana-reporter/GrafanaReporter/AbstractReport), or
          2) subclasses of the AbstractQuery (https://rubydoc.info/gems/ruby-grafana-reporter/GrafanaReporter/AbstractQuery)
        EOS
      end
    end
  end
end
