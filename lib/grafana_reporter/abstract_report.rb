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
    EVENT_CALLBACKS= [:all, :on_before_create, :on_after_cancel, :on_after_finish]

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
    # @param template [String] path to the template to be used
    # @param destination_file_or_path [String or File] path to the destination report or file object to use
    # @param custom_attributes [Hash] custom attributes, which shall be merged with priority over the configuration
    def initialize(config, template, destination_file_or_path = nil, custom_attributes = {})
      @config = config
      @logger = Logger::TwoWayDelegateLogger.new
      @logger.additional_logger = @config.logger
      @done = false
      @template = template
      @destination_file_or_path = destination_file_or_path
      @custom_attributes = custom_attributes
      @start_time = nil
      @end_time = nil
      @cancel = false
      raise MissingTemplateError, @template.to_s unless File.exist?(@template.to_s)
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

    # @return [String] status of the report, one of 'in progress', 'cancelled', 'died' or 'finished'.
    def status
      return 'cancelled' if done && cancel
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
    # @return [void]
    def create_report
      @start_time = Time.new
      notify(:on_before_create)
    end

    # @abstract
    # @return [Integer] number between 0 and 100, representing the current progress of the report creation.
    def progress
      raise NotImplementedError
    end

    private

    def done!
      @done = true
      @end_time = Time.new
      logger.info("Report creation #{status} after #{@end_time - @start_time} seconds")
      notify(:on_after_finish)
    end

    def notify(event)
      (@@event_listeners[:all] + @@event_listeners[event]).each do |listener|
        listener.callback(event, self)
      end
    end
  end
end
