# frozen_string_literal: true

require "fileutils"

RSpec.describe SynthWorld::CLI::Server do
  let(:tmpdir) { Dir.mktmpdir("synth_world_test") }
  let(:config) do
    SynthWorld::Gateway::Configuration.new(
      port: 7001,
      socket_dir: "#{tmpdir}/sockets",
      pid_file: "#{tmpdir}/synth.pid",
      log_file: "#{tmpdir}/synth.log",
      synthetics: []
    )
  end
  # An existing file so the File.exist? guard in `start` passes
  let(:fixture_config) { "spec/fixtures/gateway.yml" }

  before { allow(SynthWorld::Gateway::Configuration).to receive(:from_file).and_return(config) }
  after { FileUtils.rm_rf(tmpdir) }

  # Invoke a subcommand via Thor's class-level .start
  def run(*args)
    described_class.start(args)
  end

  describe "#start" do
    context "when the config file does not exist" do
      it "exits without forking" do
        expect(Process).not_to receive(:fork)
        expect { run("start", "--config", "#{tmpdir}/missing.yml") }.to raise_error(SystemExit)
      end
    end

    context "when the gateway is already running" do
      before { File.write(config.pid_file, Process.pid.to_s) }

      it "exits without forking" do
        expect(Process).not_to receive(:fork)
        expect { run("start", "--config", fixture_config) }.to raise_error(SystemExit)
      end
    end

    context "when starting fresh" do
      let(:fake_pid) { 99_999 }

      before do
        allow(Process).to receive(:fork).and_return(fake_pid)
        allow(Process).to receive(:detach)
      end

      it "forks a process" do
        run("start", "--config", fixture_config)
        expect(Process).to have_received(:fork)
      end

      it "detaches from the forked process" do
        run("start", "--config", fixture_config)
        expect(Process).to have_received(:detach).with(fake_pid)
      end

      it "writes the PID to the pid file" do
        run("start", "--config", fixture_config)
        expect(File.read(config.pid_file).strip).to eq(fake_pid.to_s)
      end

      it "reports the port and PID" do
        expect { run("start", "--config", fixture_config) }
          .to output(/#{config.port}.*#{fake_pid}/m).to_stdout
      end
    end
  end

  describe "#status" do
    context "when the gateway is running" do
      before { File.write(config.pid_file, Process.pid.to_s) }

      it "reports running with the PID" do
        expect { run("status", "--config", fixture_config) }
          .to output(/running.*#{Process.pid}/i).to_stdout
      end
    end

    context "when no PID file exists" do
      it "reports not running" do
        expect { run("status", "--config", fixture_config) }
          .to output(/not running/i).to_stdout
      end
    end

    context "when the PID file is stale" do
      let(:stale_pid) { 98_765 }

      before do
        File.write(config.pid_file, stale_pid.to_s)
        allow(Process).to receive(:kill).with(0, stale_pid).and_raise(Errno::ESRCH)
      end

      it "reports not running" do
        expect { run("status", "--config", fixture_config) }
          .to output(/not running/i).to_stdout
      end
    end
  end

  describe "#stop" do
    context "when no PID file exists" do
      it "reports not running" do
        expect { run("stop", "--config", fixture_config) }
          .to output(/not running/i).to_stdout
      end
    end

    context "when the gateway is running" do
      let(:fake_pid) { 99_999 }

      before do
        File.write(config.pid_file, fake_pid.to_s)
        allow(Process).to receive(:kill).with("TERM", fake_pid)
      end

      it "sends SIGTERM to the process" do
        run("stop", "--config", fixture_config)
        expect(Process).to have_received(:kill).with("TERM", fake_pid)
      end

      it "removes the PID file" do
        run("stop", "--config", fixture_config)
        expect(File.exist?(config.pid_file)).to be false
      end

      it "reports stopped" do
        expect { run("stop", "--config", fixture_config) }
          .to output(/stopped.*#{fake_pid}/i).to_stdout
      end
    end

    context "when the PID file is stale" do
      let(:stale_pid) { 98_765 }

      before do
        File.write(config.pid_file, stale_pid.to_s)
        allow(Process).to receive(:kill).with("TERM", stale_pid).and_raise(Errno::ESRCH)
      end

      it "removes the stale PID file" do
        run("stop", "--config", fixture_config)
        expect(File.exist?(config.pid_file)).to be false
      end

      it "reports that the gateway was not running" do
        expect { run("stop", "--config", fixture_config) }
          .to output(/not running|stale/i).to_stdout
      end
    end
  end
end
