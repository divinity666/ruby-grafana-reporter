# frozen_string_literal: true

module Grafana
  # Implements the interface to image rendering datasources.
  class ImageRenderingDatasource < AbstractDatasource
    # +:raw_query+ needs to contain a Hash with the following structure:
    #
    #   {
    #     panel: {Panel} which shall be rendered
    #   }
    # @see AbstractDatasource#request
    def request(query_description)
      panel = query_description[:raw_query][:panel]

      webrequest = query_description[:prepared_request]
      webrequest.relative_url = panel.render_url + url_params(query_description)
      webrequest.options.merge!({ accept: 'image/png' })

      result = webrequest.execute(query_description[:timeout])

      raise ImageCouldNotBeRenderedError, panel if result.body.include?('<html')

      { header: ['image'], content: [result.body] }
    end

    private

    def url_params(query_desc)
      url_vars = query_desc[:variables].select { |k, _v| k =~ /^(?:timeout|scale|height|width|theme|fullscreen|var-.+)$/ }
      url_vars = default_vars.merge(url_vars)
      url_vars['from'] = Variable.new(query_desc[:from])
      url_vars['to'] = Variable.new(query_desc[:to])
      result = URI.encode_www_form(url_vars.map { |k, v| [k, v.raw_value.to_s] })

      return '' if result.empty?

      "&#{result}"
    end

    def default_vars
      {
        'fullscreen' => Variable.new(true),
        'theme' => Variable.new('light'),
        'timeout' => Variable.new(60)
      }
    end
  end
end
