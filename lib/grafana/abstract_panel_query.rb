# frozen_string_literal: true

require_relative 'abstract_query'

module Grafana
  # @abstract
  #
  # Used as a superclass for all queries, which rely on a {Panel} object.
  #
  # @see AbstractQuery
  class AbstractPanelQuery < AbstractQuery
    attr_reader :panel

    # Initializes the variables of the query using {AbstractQuery#extract_dashboard_variables}.
    # @param panel [Panel] panel for which the query shall be executed
    def initialize(panel)
      super()
      @panel = panel
      extract_dashboard_variables(@panel.dashboard)
    end
  end
end
