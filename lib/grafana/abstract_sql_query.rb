# frozen_string_literal: true

module Grafana
  # @abstract
  #
  # Used as a superclass for all queries, which execute SQL queries against {Grafana}.
  #
  # @see AbstractQuery
  class AbstractSqlQuery < AbstractQuery
    attr_reader :sql, :datasource

    # @param raw_sql [String] raw sql statement, as it can be sent to a SQL database
    # @param datasource [AbstractDatasource] datasource object against which the query is run
    def initialize(raw_sql, datasource)
      super()
      @sql = raw_sql
      # TODO: move datasource to Abstract Query?
      @datasource = datasource
    end

    # @return [String] relative URL, where the request has to be sent to.
    def url
      @datasource.url(self)
    end

    # @return [Hash] request, which executes the SQL statement against the specified datasource
    def request
      @datasource.request(self)
    end

    # Replaces all variables in the SQL statement.
    def pre_process(_grafana)
      raise MissingSqlQueryError if @sql.nil?

      # TODO: ensure that this fits to all datasources, or move to datasource class
      @sql = replace_variables(@sql, grafana_variables)
    end
  end
end
