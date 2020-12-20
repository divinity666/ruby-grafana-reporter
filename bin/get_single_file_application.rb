module Kernel
  alias orig_req_rel require_relative

  def require_relative(str)
    cur_file = File.expand_path(File.join([File.dirname(caller_locations.first.absolute_path), str]))
    cur_file = File.expand_path(str) if str.include?(File.dirname(caller_locations.first.absolute_path))

    @base_path ||= File.dirname(cur_file)
    if cur_file.include?(@base_path)
      @my_files ||= []
      cur_file.gsub!(/\.rb$/, '')
      pos = @my_files.index(caller_locations.first.absolute_path.gsub(/\.rb$/, '')) || -1
      if pos.positive?
        @my_files.insert(pos, cur_file) unless @my_files.include?(cur_file)
      else
        @my_files << cur_file unless @my_files.include?(cur_file)
      end
    end
    orig_req_rel(cur_file)
  end

  def required_contents
    content = ''
    @my_files.each { |file| content += File.read(file.end_with?('.rb') ? file : "#{file}.rb") + "\n" }
    content.gsub(/[^\n]*require_relative[^\n]*\n/, '')
  end
end

def get_result(type)
  unless @result
    require_relative '/../lib/ruby-grafana-reporter'
    @result = [File.read('./LICENSE').gsub(/^/, '# '), required_contents]
  end

  return (@result + ['GrafanaReporter::Application::Application.new.configure_and_run(ARGV)']).join("\n") if type == 'bin'

  @result.join("\n")
end
