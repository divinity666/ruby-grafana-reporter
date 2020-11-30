# frozen_string_literal: true

module GrafanaReporter
  # This module contains special extensions for use in the reporter.
  module Logger
    # This logger enables a special use case, so that one and the same log
    # will automatically be send to two different logger destinations.
    #
    # One destination is the set {#additional_logger=} which respects the
    # configured severity. The other destination is an internal logger, which
    # will always log all messages in mode Logger::Severity::Debug. All messages
    # of the internal logger can easily be retrieved, by using the
    # {#internal_messages} method.
    #
    # Except the {#level=} setting, all calls to the logger will immediately
    # be delegated to the internal logger and the configured {#additional_logger=}.
    # By having this behavior, the class can be used wherever the standard Logger
    # can also be used.
    class TwoWayDelegateLogger
      def initialize
        @internal_messages = StringIO.new
        @internal_logger = ::Logger.new(@internal_messages)
        @internal_logger.level = ::Logger::Severity::DEBUG
        @additional_logger = ::Logger.new(nil)
      end

      # Sets the severity level of the additional logger to the given severity.
      # @param severity one of {Logger::Severity}
      def level=(severity)
        @additional_logger.level = severity
      end

      # @return [String] all messages of the internal logger.
      def internal_messages
        @internal_messages.string
      end

      # Used to set the additional logger in this class to an already existing
      # logger.
      # @param logger [Logger] sets the additional logger to the given value.
      def additional_logger=(logger)
        @additional_logger = logger || ::Logger.new(nil)
      end

      # Delegates all not configured calls to the internal and the additional logger.
      def method_missing(method, *args)
        @internal_logger.send(method, *args)
        @additional_logger.send(method, *args)
      end

      # Registers all methods to which the internal logger responds.
      def respond_to_missing?(method, *_args)
        super
        @internal_logger.respond_to?(method)
      end
    end
  end
end
