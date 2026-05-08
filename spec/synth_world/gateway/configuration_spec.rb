# frozen_string_literal: true

require "tmpdir"

RSpec.describe SynthWorld::Gateway::Configuration do
  describe "defaults" do
    subject(:config) { described_class.new }

    it "binds to 127.0.0.1 by default" do
      expect(config.bind).to eq("127.0.0.1")
    end

    it "listens on port 7000 by default" do
      expect(config.port).to eq(7000)
    end
  end

  describe ".from_file" do
    let(:tmpdir) { Dir.mktmpdir("synth_config_test") }
    after { FileUtils.rm_rf(tmpdir) }

    def write_config(yaml)
      path = "#{tmpdir}/gateway.yml"
      File.write(path, yaml)
      path
    end

    it "defaults bind to 127.0.0.1 when not specified" do
      path = write_config("port: 7000\n")
      expect(described_class.from_file(path).bind).to eq("127.0.0.1")
    end

    it "reads bind from the file" do
      path = write_config("port: 7000\nbind: 0.0.0.0\n")
      expect(described_class.from_file(path).bind).to eq("0.0.0.0")
    end
  end
end
