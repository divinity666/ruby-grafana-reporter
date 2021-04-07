# frozen_string_literal: true

module GrafanaReporter
  class DemoReportWizard
    def initialize(query_classes)
      @query_classes = query_classes
    end

    def build(grafana)
      results = {}

      grafana.dashboard_ids.shuffle.first(15).each do |dashboard_id|
        print "Evaluating dashboard '#{dashboard_id}' for building a demo report..."
        dashboard = grafana.dashboard(dashboard_id)

        dashboard.panels.shuffle.each do |panel|
          (@query_classes - results.keys).each do |query_class|
            begin
              result = query_class.build_demo_entry(panel)
              results[query_class] = result if result
            rescue NotImplementedError
              results[query_class] = "Method 'build_demo_entry' not implemented for #{query_class.name}"
            rescue StandardError => e
              puts "#{e.message}\n#{e.backtrace.join("\n")}"
            end
          end
        end

        puts "done - #{(@query_classes - results.keys).length} examples not yet found"
        break if (@query_classes - results.keys).empty?
      end

      (@query_classes - results.keys).each do |query_class|
        results[query_class] = "No example found for #{query_class.name} in the dashboards."
      end

      format_results(results)
    end

    private

    def format_results(raw_results)
      results = "= Demo report\n\n"\
                "Created by `+ruby-grafana-reporter+` version #{GRAFANA_REPORTER_VERSION.join(".")}\n\n"\
                "== Examples"
      
      @query_classes.each do |k|
        v = raw_results[k]
        next unless v

        if v =~ /^[A-Z]/
          results = "#{results}\n\n=== #{k.to_s.gsub(/.*::/, '')}\n\n#{v}"
        else
          results = "#{results}\n\n=== #{k.to_s.gsub(/.*::/, '')}\n\nSample call:\n\n #{v.gsub(/\n/, "\n ")}\n\nResult:\n\n#{v}"
        end
      end

      # TODO: move this to the configuration caller
      results = "#{results}\n\ninclude::grafana_environment[]"

      results
    end
  end
end
