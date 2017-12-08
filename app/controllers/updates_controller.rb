require "velum/salt"

# UpdatesController handles all the interaction with the updates of all nodes.
class UpdatesController < ApplicationController
  before_action :admin_needs_update, only: :create

  # Reboot the admin node.
  def create
    ::Velum::Salt.call(
      action:  "cmd.run",
      targets: "admin",
      arg:     "systemctl reboot"
    )

    render json: { status: Minion.statuses[:rebooting] }
  end

  protected

  def admin_needs_update
    needed, failed = ::Velum::Salt.update_status(targets: "*", cached: true)
    status = Minion.computed_status("admin", needed, failed)

    return if [Minion.statuses[:update_needed], Minion.statuses[:update_failed]].include? status

    render json: { status: Minion.statuses[:unknown] }
  end
end
