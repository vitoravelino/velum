require "rails_helper"

describe SaltEvent do
  describe ".process_next_event" do
    let(:leftover_event) do
      # not timed out
      FactoryGirl.create(
        :salt_event, worker_id: "this_worker", processed_at: nil,
        taken_at: (SaltEvent::PROCESS_TIMEOUT_MIN - 2).minutes.ago
      )
    end

    let(:timedout_event) do
      FactoryGirl.create(
        :salt_event, worker_id: "other_worker", processed_at: nil,
        taken_at: (SaltEvent::PROCESS_TIMEOUT_MIN + 2).minutes.ago
      )
    end

    let(:new_minion_event) do
      event_data = {
        "_stamp" => "2017-01-24T13:30:20.794326",
        "pretag" => nil, "cmd" => "_minion_event", "tag" => "minion_start",
        "data" => "Minion 3bcb66a2e50646dcabf779e50c6f3232 started at Tue Jan 24 13:30:20 2017",
        "id" => "3bcb66a2e50646dcabf779e50c6f3232"
      }.to_json

      FactoryGirl.create(:salt_event, tag: "minion_start", data: event_data)
    end

    # rubocop:disable RSpec/ExampleLength
    it "processes new-minion events" do
      new_minion_event

      VCR.use_cassette("salt/minion_list", record: :none) do
        expect do
          described_class.process_next_event(worker_id: "MyWorker")
        end.to change { Minion.where(minion_id: "3bcb66a2e50646dcabf779e50c6f3232").count }.by(1)
      end
    end
    # rubocop:enable RSpec/ExampleLength

    it "processes irrelevant events" do
      FactoryGirl.create(:salt_event, tag: "nobody_cares_about_this_event")

      expect do
        described_class.process_next_event(worker_id: "MyWorker")
      end.to change { described_class.where(processed_at: nil).count }.from(1).to(0)
    end

    it "processes events not assigned to any worker" do
      event = FactoryGirl.create(:salt_event, worker_id: nil)
      expect do
        described_class.process_next_event(worker_id: "MyWorker")
      end.to change { event.reload.processed_at }.from(nil).to(Time)
    end

    it "processes events assigned to the same worker (leftovers from dying?)" do
      expect do
        described_class.process_next_event(worker_id: "this_worker")
      end.to change { leftover_event.reload.processed_at }.from(nil).to(Time)
    end

    it "processes events assigned to any worker but not completed for more"\
      "than PROCESS_TIMEOUT_MIN minutes" do
      expect { described_class.process_next_event(worker_id: "this_worker") }
        .to change { timedout_event.reload.processed_at }.from(nil).to(Time)

      expect(timedout_event.worker_id).to eq("this_worker")
    end
  end

  describe "#process" do
    let(:salt_event) do
      FactoryGirl.create(:salt_event, processed_at: nil)
    end

    it "updates the processed_at column" do
      expect { salt_event.process! }
        .to change { salt_event.processed_at }.from(nil).to(Time)
    end
  end

  describe "parsed_data" do
    let(:salt_event) { FactoryGirl.create(:salt_event) }

    it "parses the data as JSON" do
      parsed_data = salt_event.parsed_data

      expect(parsed_data.keys).to eq(["_stamp", "pretag", "cmd", "tag", "data", "id"])
    end
  end

  describe "handler" do
    it "must return an instance of SaltHandler::MinionStart when the tag is 'minion_start'" do
      handler = described_class.new(tag: "minion_start", data: "{}").handler

      expect(handler).to be_an_instance_of(SaltHandler::MinionStart)
    end

    it "must return an instance of SaltHandler::MinionHighstate" do
      salt_event = described_class.new(
        tag:  "salt/job/12345/ret/MyMinion",
        data: { fun: "state.highstate" }.to_json
      )

      expect(salt_event.handler).to be_an_instance_of(SaltHandler::MinionHighstate)
    end

    it "must return an instance of SaltHandler::OrchestrationTrigger for orch.kubernetes" do
      salt_event = described_class.new(
        tag:  "salt/run/12345/new",
        data: { fun: "runner.state.orchestrate", fun_args: ["orch.kubernetes"] }.to_json
      )

      expect(salt_event.handler).to be_an_instance_of(SaltHandler::OrchestrationTrigger)
    end

    it "must return an instance of SaltHandler::OrchestrationTrigger for orch.update" do
      salt_event = described_class.new(
        tag:  "salt/run/12345/new",
        data: { fun: "runner.state.orchestrate", fun_args: ["orch.update"] }.to_json
      )

      expect(salt_event.handler).to be_an_instance_of(SaltHandler::OrchestrationTrigger)
    end

    it "must return an instance of SaltHandler::OrchestrationResult for orch.kubernetes" do
      salt_event = described_class.new(
        tag:  "salt/run/12345/ret",
        data: { fun: "runner.state.orchestrate", fun_args: ["orch.kubernetes"] }.to_json
      )

      expect(salt_event.handler).to be_an_instance_of(SaltHandler::OrchestrationResult)
    end

    it "must return an instance of SaltHandler::OrchestrationResult for orch.update" do
      salt_event = described_class.new(
        tag:  "salt/run/12345/ret",
        data: { fun: "runner.state.orchestrate", fun_args: ["orch.update"] }.to_json
      )

      expect(salt_event.handler).to be_an_instance_of(SaltHandler::OrchestrationResult)
    end

    # rubocop:disable RSpec/ExampleLength
    it "must not return an instance of SaltHandler::MinionOrchestration for"\
      " orch.update_etc_hosts" do
      salt_event = described_class.new(
        tag:  "salt/run/12345/ret",
        data: {
          fun:      "runner.state.orchestrate",
          fun_args: [{ mods: "orch.update_etc_hosts" }]
        }.to_json
      )

      expect(salt_event.handler).not_to be_an_instance_of(SaltHandler::OrchestrationResult)
    end
    # rubocop:enable RSpec/ExampleLength

  end
end
