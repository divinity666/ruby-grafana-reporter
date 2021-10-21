include GrafanaReporter

describe Configuration do
  context 'set individual parameters' do
    subject { Configuration.new }

    it 'can set single parameters' do
      expect(subject.templates_folder).to eq('./')
      subject.set_param('grafana-reporter:templates-folder', 'test')
      subject.set_param('grafana-reporter:report-retention', 666)
      expect(subject.templates_folder).to eq('test/')
      expect(subject.report_retention).to eq(666)
    end
  end

  context 'with config file' do
    subject do
      obj = Configuration.new
      obj.config = YAML.load_file('./spec/tests/demo_config.txt')
      obj
    end

    it 'is in mode service' do
      expect(subject.mode).to eq(Configuration::MODE_SERVICE)
    end

    it 'reads port' do
      expect(subject.webserver_port).to eq(8050)
    end

    it 'has no template' do
      expect(subject.template).to be_nil
    end

    it 'returns grafana instances' do
      expect(subject.grafana_instances.length).to eq(1)
      expect(subject.grafana_instances[0]).to eq('default')
    end

    it 'returns grafana host' do
      expect(subject.grafana_host).to eq('http://localhost')
    end

    it 'returns reports folder with trailing slash' do
      expect(subject.reports_folder).to eq('./')
    end

    it 'returns templates folder with trailing slash' do
      expect(subject.templates_folder).to eq('./')
    end

    it 'returns images folder' do
      expect(subject.images_folder).to eq('./')
    end

    it 'is valid' do
      allow(subject.logger).to receive(:debug)
      allow(subject.logger).to receive(:info)
      allow(subject.logger).to receive(:warn)
      expect { subject.validate }.not_to raise_error
    end

    it 'raises error if grafana instance does not have a host setting' do
      obj = Configuration.new
      yaml = YAML.load_file('./spec/tests/demo_config.txt')
      yaml['grafana']['default'].delete('host')
      obj.config = yaml
      expect { obj.grafana_host }.to raise_error(GrafanaInstanceWithoutHostError)
      expect { obj.validate }.to raise_error(ConfigurationDoesNotMatchSchemaError)
    end
  end

  context 'without config file' do
    subject { Configuration.new }

    it 'is in mode service' do
      expect(subject.mode).to eq(Configuration::MODE_SERVICE)
    end

    it 'has default port' do
      expect(subject.webserver_port).to eq(8815)
    end

    it 'has no template' do
      expect(subject.template).to be_nil
    end

    it 'returns images folder' do
      expect(subject.images_folder).to eq('./')
    end

    it 'is invalid' do
      allow(subject.logger).to receive(:debug)
      allow(subject.logger).to receive(:info)
      allow(subject.logger).to receive(:warn)
      expect { subject.validate }.to raise_error(ConfigurationDoesNotMatchSchemaError)
    end
  end

  context 'validator' do
    subject { Configuration.new }

    it 'validates required fields' do
      subject.config = {
                            'grafana' => { 'default' => { 'host' => 'test' } },
                            'grafana-reporter' => { 'report-class' => 'GrafanaReporter::Asciidoctor::Report' }
                          }
      expect { subject.validate }.not_to raise_error
    end

    it 'raises error if not supported data type is used' do
      subject.config = {
                            'grafana' => { 'default' => [] },
                            'grafana-reporter' => { 'report-class' => 'GrafanaReporter::Asciidoctor::Report' }
                          }
      expect { subject.validate }.to raise_error(ConfigurationError)
    end

    it 'raises error if wrong data type is used' do
      subject.config = {
                            'grafana' => { 'default' => { 'host' => 5 } },
                            'grafana-reporter' => { 'report-class' => 'GrafanaReporter::Asciidoctor::Report' }
                          }
      expect { subject.validate }.to raise_error(ConfigurationDoesNotMatchSchemaError)
    end

    it 'raises error if folder does not exist' do
      subject.config = {
                            'grafana' => { 'default' => { 'host' => 'test' } },
                            'grafana-reporter' => { 'report-class' => 'GrafanaReporter::Asciidoctor::Report', 'reports-folder' => 'ewfhenwf8' }
                          }
      expect { subject.validate }.to raise_error(FolderDoesNotExistError)
    end

    it 'warns if not evaluated configurations exist' do
      subject.config = {
                            'grafana' => { 'default' => { 'host' => 'test' } },
                            'grafana-reporter' => { 'report-class' => 'GrafanaReporter::Asciidoctor::Report', 'repots-folder' => 'ewfhenwf8' }
                          }
      expect(subject.logger).to receive(:warn).with("Item 'repots-folder' in configuration is unknown to the reporter and will be ignored")
      subject.validate
    end

    it 'deprecation warning if report-class is not specified' do
      subject.config = {
                            'grafana' => { 'default' => { 'host' => 'test' } }
                          }
      expect(subject.logger).to receive(:warn).with(/DEPRECATION WARNING.*report-class./)
      subject.validate
    end
  end

  context 'version checks' do
    subject { Configuration.new }

    it 'returns latest version true if no checks shall be done' do
      expect(subject.latest_version_check_ok?).to be true
    end

    it 'returns latest version true if checks shall be done' do
      subject.set_param('grafana-reporter:check-for-updates', 1)
      expect(subject.latest_version_check_ok?).to be true
    end

    it 'can return latest version false' do
      # modify stubbed request, to ensure that the versions do not match
      stub_request(:get, "https://github.com/divinity666/ruby-grafana-reporter/releases/latest")
      .to_return(status: 302, body: "relocated", headers: {'location' => "https://github.com/divinity666/ruby-grafana-reporter/releases/tag/v0.0.0"})

      subject.set_param('grafana-reporter:check-for-updates', 1)
      expect(subject.latest_version_check_ok?).to be false
    end
  end
end
