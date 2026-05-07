# frozen_string_literal: true

require "async"
require "tmpdir"

RSpec.describe SynthWorld::Synthetic::Processor do
  let(:tmpdir) { Dir.mktmpdir("synth_processor_test") }
  after { FileUtils.rm_rf(tmpdir) }

  # Literal::Data freezes instances, so we can't set instance vars after super.
  # Capture test state in closure variables instead.
  let(:results) { [] }
  let(:ticks)   { [] }

  let(:synthetic) do
    SynthWorld::Synthetic.new(
      name: "test", biography: "test", workspace: tmpdir,
      rules: {gatekeeper_input_rule: "", gatekeeper_output_rule: ""},
      processors: {}
    )
  end

  let(:processor_class) do
    r = results
    t = ticks
    Class.new(described_class) do
      action(:greet) { |name| r << "Hello, #{name}!" }
      action(:add)   { |a, b| r << a + b }
      every(0.05)    { t << Time.now }
    end
  end

  subject(:processor) { processor_class.new(synthetic: synthetic) }

  def drain(count)
    Async do
      count.times do
        action, args = processor.queue.pop
        processor.instance_exec(*args, &action)
      end
    end
  end

  describe ".action" do
    it "defines a public method on the subclass" do
      expect(processor).to respond_to(:greet)
    end

    it "executes the implementation within the processor" do
      processor.greet("Cher")
      drain(1)
      expect(results).to include("Hello, Cher!")
    end

    it "passes arguments through to the implementation" do
      processor.add(3, 4)
      drain(1)
      expect(results).to include(7)
    end

    it "processes actions in order" do
      processor.greet("Cher")
      processor.greet("Dionne")
      drain(2)
      expect(results).to eq(["Hello, Cher!", "Hello, Dionne!"])
    end
  end

  describe ".every" do
    it "fires the timer block repeatedly at the given interval" do
      Async do |task|
        processor.call
        task.sleep(0.5)
        expect(ticks.length).to be >= 3
      end
    end
  end

  describe ".timers" do
    it "is scoped to each subclass independently" do
      sibling = Class.new(described_class) { every(1) {} }
      expect(processor_class.timers.length).to eq(1)
      expect(sibling.timers.length).to eq(1)
      expect(processor_class.timers).not_to eq(sibling.timers)
    end
  end
end
