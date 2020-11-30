# frozen_string_literal: true

module Grafana
  # Query, which allows to render a {Panel} as a PNG image.
  class PanelImageQuery < AbstractPanelQuery
    # Returns the URL for rendering the panel. Uses {Panel#render_url} and sets additional url
    # parameters according {https://grafana.com/docs/grafana/latest/reference/share_panel Grafana Share Panel}.
    #
    # @see AbstractQuery#url
    # @return [String] string for rendering the panel
    def url
      @panel.render_url + url_parameters
    end

    # Changes the result of the request to be of type +image/png+.
    #
    # @see AbstractQuery#request
    def request
      { accept: 'image/png' }
    end

    # Adds default variables for querying the image.
    #
    # @see AbstractQuery#pre_process
    def pre_process(_grafana)
      @variables['fullscreen'] = Variable.new(true)
      @variables['theme'] = Variable.new('light')
      @variables['timeout'] = Variable.new(timeout) if timeout
      @variables['timeout'] ||= Variable.new(60)
    end

    # Checks if the rendering has been performed properly.
    # If so, the resulting image is stored in the @result variable, otherwise an error is raised.
    #
    # @see AbstractQuery#post_process
    def post_process
      raise ImageCouldNotBeRenderedError, @panel if @result.body.include?('<html')
    end

    private

    def url_parameters
      url_vars = variables.select { |k, _v| k =~ /^(?:timeout|height|width|theme|fullscreen)/ || k =~ /^var-.+/ }
      url_vars['from'] = Variable.new(@from) if @from
      url_vars['to'] = Variable.new(@to) if @to
      url_params = URI.encode_www_form(url_vars.map { |k, v| [k, v.raw_value.to_s] })
      return '' if url_params.empty?

      "&#{url_params}"
    end
  end
end
