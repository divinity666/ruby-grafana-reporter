# frozen_string_literal: true

module Grafana
  # @abstract
  #
  # Used as a superclass for all queries, which execute SQL queries against {Grafana}.
  #
  # @see AbstractQuery
  class AbstractSqlQuery < AbstractQuery
    attr_reader :sql, :datasource_id

    # @param raw_sql [String] raw sql statement, as it can be sent to a SQL database
    # @param datasource_id [Integer] ID of the datasource against which the query is run
    def initialize(raw_sql, datasource_id)
      super()
      @sql = raw_sql
      @datasource_id = datasource_id
    end

    # @return [String] relative URL, where the request has to be sent to.
    def url
      '/api/tsdb/query'
    end

    # @return [Hash] request, which executes the SQL statement against the specified datasource
    def request
      {
        body: {
          from: @from,
          to: @to,
          queries: [rawSql: @sql, datasourceId: @datasource_id.to_i, format: 'table']
        }.to_json,
        request: Net::HTTP::Post
      }
    end

    # Replaces all variables in the SQL statement.
    def pre_process(grafana)
      raise MissingSqlQueryError if @sql.nil?
      unless grafana.datasource_id_exists?(@datasource_id.to_i)
        raise DatasourceDoesNotExistError.new('id', @datasource_id)
      end

      @sql = replace_variables(@sql, grafana_variables)
      # remove comments in query
      @sql.gsub!(/--[^\r\n]*(?:[\r\n]+|$)/, ' ')
      @sql.gsub!(/\r\n/, ' ')
      @sql.gsub!(/\n/, ' ')
    end
  end
end
