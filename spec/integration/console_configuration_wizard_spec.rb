include GrafanaReporter

describe ConsoleConfigurationWizard do
  context 'adoc config wizard' do
    subject { GrafanaReporter::ConsoleConfigurationWizard.new }
    let(:folder) { './test_templates' }
    let(:config_file) { 'test.config' }

    before do
      File.delete(config_file) if File.exist?(config_file)
      File.delete("#{folder}/demo_report.adoc") if File.exist?("#{folder}/demo_report.adoc")
      Dir.delete(folder) if Dir.exist?(folder)
      @config = ["\n", "http://localhost\n", "a\n", "#{STUBS[:key_admin]}\n", "i\n", "#{folder}\n", "c\n", ".\n", ".\n", "\n", "\n"]
      allow(subject).to receive(:puts)
      allow(subject).to receive(:print)
      allow_any_instance_of(Logger).to receive(:debug)
      allow_any_instance_of(Logger).to receive(:info)
      allow_any_instance_of(Logger).to receive(:warn)
    end

    after do
      File.delete(config_file) if File.exist?(config_file)
      File.delete("#{folder}/demo_report.adoc") if File.exist?("#{folder}/demo_report.adoc")
      Dir.delete(folder) if Dir.exist?(folder)
    end

    it 'can create configured folders' do
      allow(subject).to receive(:gets).and_return(*@config)
      subject.start_wizard(config_file, Configuration.new)
      expect(Dir.exist?(folder)).to be true
    end

    it 'creates config file properly' do
      allow(subject).to receive(:gets).and_return(*@config)
      subject.start_wizard(config_file, Configuration.new)
      expect(File.exist?(config_file)).to be true
      expect(File.exist?("#{folder}/demo_report.adoc")).to be false
      expect(YAML.load_file(config_file)).to eq({'grafana' => {'default' => {'host' => @config[1].strip, 'api_key' => STUBS[:key_admin]}}, 'grafana-reporter' => {'check-for-updates' => 'always', 'report-class' => 'GrafanaReporter::Asciidoctor::Report', 'templates-folder' => folder, 'reports-folder' => '.', 'report-retention' => 24, 'webservice-port' => 8815}, 'default-document-attributes' => {'imagesdir' => '.'}})
    end

    it 'creates valid config file without working access' do
      @config.slice!(2,2)
      allow(subject).to receive(:gets).and_return(*@config)
      subject.start_wizard(config_file, Configuration.new)
      expect(File.exist?(config_file)).to be true
    end

    it 'asks before overwriting config file' do
      allow(subject).to receive(:gets).and_return(*@config)
      subject.start_wizard(config_file, Configuration.new)
      expect(File.exist?(config_file)).to be true
      modify_date = File.mtime(config_file)
      #try to create config again
      @config = ["\n"]
      allow(subject).to receive(:gets).and_return(*@config)
      subject.start_wizard(config_file, Configuration.new)
      expect(File.mtime(config_file)).to eq(modify_date)
    end

    it 'warns if grafana instance could not be accessed' do
      @config.insert(1, "http://blabla:9999\n", "r\n")
      allow(subject).to receive(:gets).and_return(*@config)
      WebMock.disable_net_connect!(allow: ['http://blabla:9999'])
      subject.start_wizard(config_file, Configuration.new)
      WebMock.enable!
      expect(File.exist?(config_file)).to be true
    end

    it 'can create a proper demo report' do
      @config.slice!(10,1)
      @config.insert(10, "y\n")
      allow_any_instance_of(DemoReportWizard).to receive(:puts)
      allow_any_instance_of(DemoReportWizard).to receive(:print)
      allow(subject).to receive(:gets).and_return(*@config)
      subject.start_wizard(config_file, Configuration.new)

      # TODO: test that the demo report can be rendered properly
      expect(File.exist?("#{folder}/demo_report.adoc")).to be true
    end
  end
end
