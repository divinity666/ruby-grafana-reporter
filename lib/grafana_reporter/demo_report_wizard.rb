# frozen_string_literal: true

module GrafanaReporter
  # This class is used to build a demo report based on a real grafana instance. Therefore
  # it checks available grafana dashboards and panels and returns a final template file as
  # string, which can then be used as a template.
  class DemoReportWizard
    # @param query_classes [Array] class objects, for which a demo report shall be created
    def initialize(query_classes)
      @query_classes = query_classes
    end

    # Invokes the build process for the given +grafana+ object. Progress is printed to
    # STDOUT.
    # @param grafana [Grafana] grafana instance, for which the demo report shall be built
    # @return [String] demo template as string
    def build(grafana)
      results = {}

      grafana.dashboard_ids.sample(15).each do |dashboard_id|
        print "Evaluating dashboard '#{dashboard_id}' for building a demo report..."
        dashboard = grafana.dashboard(dashboard_id)

        results = evaluate_dashboard(dashboard, @query_classes - results.keys).merge(results)

        puts "done - #{(@query_classes - results.keys).length} examples to go"
        break if (@query_classes - results.keys).empty?
      end

      if grafana.dashboard_ids.length > 15 && !(@query_classes - results.keys).empty?
        puts 'Aborting evaluating further dashboards after 15 samples.'
      end

      unless (@query_classes - results.keys).empty?
        puts "For #{(@query_classes - results.keys).length} reporter functionalities no appropriate "\
             'examples could be found in the configured grafana instance.'
      end

      format_results(default_result(@query_classes - results.keys).merge(results))
    end

    private

    def default_result(query_classes)
      results = {}

      query_classes.each do |query_class|
        results[query_class] = "No example found for #{query_class.name} in the dashboards."
      end

      results
    end

    def evaluate_dashboard(dashboard, query_classes)
      results = {}

      dashboard.panels.shuffle.each do |panel|
        begin
          next if panel.datasource.is_a?(Grafana::UnsupportedDatasource)
        rescue Grafana::DatasourceDoesNotExistError
          next
        end

        query_classes.each do |query_class|
          unless query_class.public_instance_methods.include?(:build_demo_entry)
            results[query_class] = "Method 'build_demo_entry' not implemented for #{query_class.name}"
            next
          end

          begin
            result = query_class.new.build_demo_entry(panel)
            results[query_class] = result if result
          rescue Grafana::DatasourceDoesNotExistError
            # properly catch DatasourceDoesNotExist errors here, as they don't lead to a real issue
            # during demo report creation
            # This may e.g. happen if a panel asks e.g. for datasource '-- Dashboard --' which is
            # currently not allowed
          rescue StandardError => e
            puts "#{e.message}\n#{e.backtrace.join("\n")}"
          end
        end
      end

      results
    end

    # TODO: move this method to Asciidoctor::Report
    def format_results(raw_results)
      results = ['= Demo report',
                 "Created by `+ruby-grafana-reporter+` version #{GRAFANA_REPORTER_VERSION.join('.')}",
                 '== Examples']

      raw_results.each do |k, v|
        results += if v =~ /^[A-Z]/
                     ["=== #{k.to_s.gsub(/.*::/, '')}", v.to_s]
                   else
                     ["=== #{k.to_s.gsub(/.*::/, '')}", 'Sample call:', " #{v.gsub(/\n/, "\n ")}",
                      'Result:', v.to_s]
                   end
      end

      results.join("\n\n")
    end
  end
end
