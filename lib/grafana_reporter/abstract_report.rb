# frozen_string_literal: true

module GrafanaReporter
  # @abstract Override {#create_report} and {#progress}.
  #
  # This class is used to build a report on basis of a given configuration and
  # template.
  #
  # Objects of this class are also stored in {Application::Application}, unless
  # the retention time is over.
  class AbstractReport
    # Array of supported event callback symbols
    EVENT_CALLBACKS = %i[all on_before_create on_after_cancel on_after_finish].freeze

    # Class variable for storing event listeners
    @@event_listeners = {}
    @@event_listeners.default = []

    # @return [String] path to the template
    attr_reader :template

    # @return [Time] time, when the report generation started
    attr_reader :start_time

    # @return [Time] time, when the report generation ended
    attr_reader :end_time

    # @return [Logger] logger object used during report generation
    attr_reader :logger

    # @return [Boolean] true, if the report is or shall be cancelled
    attr_reader :cancel

    # @return [Boolen] true, if the report generation is finished (successfull or not)
    attr_reader :done

    # @param config [Configuration] configuration object
    def initialize(config)
      @config = config
      @logger = Logger::TwoWayDelegateLogger.new
      @logger.additional_logger = @config.logger
      @grafana_instances = {}

      init_before_create
    end

    # Registers a new event listener object.
    # @param event [Symbol] one of EVENT_CALLBACKS
    # @param listener [Object] object responding to #callback(event_symbol, object)
    def self.add_event_listener(event, listener)
      @@event_listeners[event] = [] if @@event_listeners[event] == []
      @@event_listeners[event].push(listener)
    end

    # Removes all registeres event listener objects
    def self.clear_event_listeners
      @@event_listeners = {}
      @@event_listeners.default = []
    end

    # @param instance [String] requested grafana instance
    # @return [Grafana::Grafana] the requested grafana instance.
    def grafana(instance)
      unless @grafana_instances[instance]
        @grafana_instances[instance] = ::Grafana::Grafana.new(@config.grafana_host(instance),
                                                              @config.grafana_api_key(instance),
                                                              logger: @logger)
      end
      @grafana_instances[instance]
    end

    # Call to request cancelling the report generation.
    # @return [void]
    def cancel!
      @cancel = true
      logger.info('Cancelling report generation invoked.')
      notify(:on_after_cancel)
    end

    # @return [String] path to the report destination file
    def path
      @destination_file_or_path.respond_to?(:path) ? @destination_file_or_path.path : @destination_file_or_path
    end

    # Deletes the report file object.
    # @return [void]
    def delete_file
      if @destination_file_or_path.is_a?(Tempfile)
        @destination_file_or_path.unlink
      elsif @destination_file_or_path.is_a?(File)
        @destination_file_or_path.delete
      end
      @destination_file_or_path = nil
    end

    # @return [Float] time in seconds, that the report generation took
    def execution_time
      return nil if start_time.nil?
      return end_time - start_time unless end_time.nil?

      Time.now - start_time
    end

    # @return [Array] error messages during report generation.
    def error
      @error || []
    end

    # @return [String] status of the report as string, either 'not started', 'in progress', 'cancelling',
    #   'cancelled', 'died' or 'finished'.
    def status
      return 'not started' unless @start_time
      return 'cancelled' if done && cancel
      return 'cancelling' if !done && cancel
      return 'finished' if done && error.empty?
      return 'died' if done && !error.empty?

      'in progress'
    end

    # @return [String] string containing all messages ([Logger::Severity::DEBUG]) of the logger during report
    #   generation.
    def full_log
      logger.internal_messages
    end

    # Is being called to start the report generation.
    # @param template [String] path to the template to be used, trailing +.adoc+ extension may be omitted
    # @param destination_file_or_path [String or File] path to the destination report or file object to use
    # @param custom_attributes [Hash] custom attributes, which shall be merged with priority over the configuration
    # @return [void]
    def create_report(template, destination_file_or_path = nil, custom_attributes = {})
      init_before_create
      @template = template
      @destination_file_or_path = destination_file_or_path
      @custom_attributes = custom_attributes

      # automatically add extension, if a file with adoc extension exists
      @template = "#{@template}.adoc" if File.file?("#{@template}.adoc") && !File.file?(@template.to_s)
      raise MissingTemplateError, @template.to_s unless File.file?(@template.to_s)

      notify(:on_before_create)
      @start_time = Time.new
      logger.info("Report started at #{@start_time}")
    end

    # Used to calculate the progress of a report. By default expects +@total_steps+ to contain the total
    # number of steps, which will be processed with each call of {#next_step}.
    # @return [Integer] number between 0 and 100, representing the current progress of the report creation.
    def progress
      return @current_pos.to_i if @total_steps.to_i.zero?

      @current_pos.to_f / @total_steps
    end

    # Increments the progress.
    # @return [Integer] number of the current progress position.
    def next_step
      @current_pos += 1
      @current_pos
    end

    # @abstract
    # Provided class objects need to implement a method +build_demo_entry(panel)+.
    # @return [Array<Class>] array of class objects, which shall be included in a demo report
    def self.demo_report_classes
      raise NotImplementedError
    end

    private

    # Called, if the report generation has died with an error.
    # @param error [StandardError] occured error
    # @return [void]
    def died_with_error(error)
      @error = [error.message] << [error.backtrace]
      done!
    end

    def init_before_create
      @done = false
      @start_time = nil
      @end_time = nil
      @cancel = false
      @current_pos = 0
    end

    def done!
      return if @done

      @done = true
      @end_time = Time.new
      @start_time = @end_time unless @start_time
      logger.info("Report creation ended after #{@end_time.to_i - @start_time.to_i} seconds with status '#{status}'")
      notify(:on_after_finish)
    end

    def notify(event)
      (@@event_listeners[:all] + @@event_listeners[event]).each do |listener|
        logger.debug("Informing event listener '#{listener.class}' about event '#{event}' for report '#{object_id}'.")
        begin
          res = listener.callback(event, self)
          logger.debug("Event listener '#{listener.class}' for event '#{event}' and report '#{object_id}' returned "\
                       "with result '#{res}'.")
        rescue StandardError => e
          msg = "Event listener '#{listener.class}' for event '#{event}' and report '#{object_id}' returned with "\
                "error: #{e.message} - #{e.backtrace}."
          puts msg
          logger.error(msg)
        end
      end
    end
  end
end
