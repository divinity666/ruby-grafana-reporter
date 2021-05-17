# frozen_string_literal: true

class MyUnknownDatasource < ::Grafana::AbstractDatasource
  def self.handles?(model)
    model['type'] == 'UnknownDatasource'
  end

  def request(query_description)
    { header: ['I am handled'], content: [[1000]] }
  end
end
