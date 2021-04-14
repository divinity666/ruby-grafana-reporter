# frozen_string_literal: true

module Grafana
  # Implements the datasource interface to grafana model properties.
  class GrafanaPropertyDatasource < AbstractDatasource
    # +:raw_query+ needs to contain a Hash with the following structure:
    #
    #   {
    #     property_name: Name of the queried property as String
    #     panel:         {Panel} object to query
    #   }
    # @see AbstractDatasource#request
    def request(query_description)
      raise MissingSqlQueryError if query_description[:raw_query].nil?

      panel = query_description[:raw_query][:panel]
      property_name = query_description[:raw_query][:property_name]

      {
        header: [query_description[:raw_query][:property_name]],
        content: [replace_variables(panel.field(property_name), query_description[:variables])]
      }
    end
  end
end
