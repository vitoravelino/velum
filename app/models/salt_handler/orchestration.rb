# frozen_string_literal: true

# This is a subclass for common logic across Orchestration trigger and result.
class SaltHandler::Orchestration
  attr_reader :salt_event

  ORCHESTRATIONS = ["orch.kubernetes", "orch.update"].freeze

  def self.tag_matcher
    raise "no tag matcher specified"
  end

  def self.can_handle_event?(event)
    return false unless event.tag =~ tag_matcher
    event_data = JSON.parse event.data
    event_data["fun"] == "runner.state.orchestrate" && salt_fun_args_match(event_data)
  end

  def self.salt_fun_args_match(event_data)
    fun_args = event_data["fun_args"]

    ORCHESTRATIONS.each do |o|
      return o if fun_args.first == o || fun_args.first["mods"] == o
    end

    nil
  end

  def initialize(salt_event)
    @salt_event = salt_event
  end
end
