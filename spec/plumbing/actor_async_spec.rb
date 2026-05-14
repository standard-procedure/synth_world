# frozen_string_literal: true

require "plumbing/actor/async"
require "async"

RSpec.describe Plumbing::Actor::Async do
  before do
    Plumbing::Actor.register :async do |actor|
      Plumbing::Actor::Async.new(actor: actor)
    end
    Plumbing::Actor.uses :async
  end

  after do
    Plumbing::Actor.uses :inline
    Plumbing::Actor.worker_types.delete(:async)
  end

  describe "configuration" do
    it "produces actors backed by an Async worker" do
      klass = Class.new do
        include Plumbing::Actor

        async(:noop) { returns { :ok } }
      end
      expect(klass.new.worker).to be_a(Plumbing::Actor::Async)
    end
  end

  describe "dispatch" do
    let(:greeter) do
      Class.new do
        include Plumbing::Actor

        async :greet do
          param :name, String
          returns { |name:| "Hello #{name}" }
        end
      end
    end

    it "returns an Async::Message (not yet delivered)" do
      Sync do
        actor = greeter.new
        actor.worker.call
        message = actor.greet(name: "X")
        expect(message).to be_a(Plumbing::Actor::Async::Message)
      end
    end

    it "delivers the message and returns the result via .await" do
      Sync do
        actor = greeter.new
        actor.worker.call
        expect(actor.greet(name: "Cher").await).to eq "Hello Cher"
      end
    end

    it "works with the Kernel#await block form" do
      Sync do
        actor = greeter.new
        actor.worker.call
        expect(await { actor.greet(name: "World") }).to eq "Hello World"
      end
    end

    it "marks the message as :done after delivery" do
      Sync do
        actor = greeter.new
        actor.worker.call
        message = actor.greet(name: "X")
        message.await
        expect(message.status).to eq :done
      end
    end

    it "delivers multiple messages enqueued from the test" do
      klass = Class.new do
        include Plumbing::Actor

        attr_reader :seen

        def initialize
          super
          @seen = []
        end

        async :record do
          param :n, Integer
          returns do |n:|
            @seen << n
            n
          end
        end
      end

      Sync do
        actor = klass.new
        actor.worker.call
        messages = (1..5).map { |n| actor.record(n: n) }
        messages.each(&:await)
        expect(actor.seen).to contain_exactly(1, 2, 3, 4, 5)
      end
    end
  end

  describe "type validation" do
    let(:typed) do
      Class.new do
        include Plumbing::Actor

        async :greet do
          param :name, String
          param :age, _Integer(0..120), default: 42
          returns { |name:, age:| "#{name} is #{age}" }
        end
      end
    end

    it "applies defaults when params are omitted" do
      Sync do
        actor = typed.new
        actor.worker.call
        expect(await { actor.greet(name: "Alice") }).to eq "Alice is 42"
      end
    end

    it "raises Literal::TypeError on type mismatch" do
      Sync do
        actor = typed.new
        actor.worker.call
        expect { await { actor.greet(name: 123) } }.to raise_error(Literal::TypeError)
      end
    end

    it "raises Literal::TypeError on range violation" do
      Sync do
        actor = typed.new
        actor.worker.call
        expect { await { actor.greet(name: "A", age: 200) } }.to raise_error(Literal::TypeError)
      end
    end

    it "raises ArgumentError when a required param is missing" do
      Sync do
        actor = typed.new
        actor.worker.call
        expect { await { actor.greet } }.to raise_error(ArgumentError, /missing keyword/)
      end
    end
  end

  describe "exception propagation" do
    it "re-raises the implementation exception when awaited" do
      klass = Class.new do
        include Plumbing::Actor

        async(:boom) { returns { raise "Kaboom!" } }
      end

      Sync do
        actor = klass.new
        actor.worker.call
        message = actor.boom
        expect { message.await }.to raise_error(RuntimeError, "Kaboom!")
        expect(message.status).to eq :error
        expect(message.exception).to be_a(RuntimeError)
      end
    end
  end

  describe "current_sender" do
    let(:probe) do
      Class.new do
        include Plumbing::Actor

        async(:who_sent) { returns { current_sender } }
      end
    end

    let(:other) do
      Class.new do
        include Plumbing::Actor

        async(:noop) { returns { :ok } }
      end
    end

    it "is nil when no sender is given" do
      Sync do
        actor = probe.new
        actor.worker.call
        expect(await { actor.who_sent }).to be_nil
      end
    end

    it "is the actor that sent the message" do
      Sync do
        a = probe.new
        b = other.new
        a.worker.call
        b.worker.call
        expect(await { a.who_sent(sender: b) }).to be(b)
      end
    end

    it "does not leak between concurrent message deliveries" do
      # Each async dispatch runs in its own Async::Task fiber; the fiber-local
      # used for current_sender is naturally scoped per-fiber.
      Sync do
        a = probe.new
        b1 = other.new
        b2 = other.new
        a.worker.call
        b1.worker.call
        b2.worker.call
        m1 = a.who_sent(sender: b1)
        m2 = a.who_sent(sender: b2)
        expect(m1.await).to be(b1)
        expect(m2.await).to be(b2)
      end
    end
  end
end
