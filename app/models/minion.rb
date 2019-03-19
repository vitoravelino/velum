require "velum/salt_minion"

# Minion represents the minions that have been registered in this application.
class Minion < ApplicationRecord
  scope :assigned_role, -> { where.not role: nil }
  scope :cluster_role, -> { where role: [Minion.roles[:master], Minion.roles[:worker]] }
  scope :unassigned_role, -> { where role: nil }
  scope :needs_update, -> { where "tx_update_reboot_needed = true or tx_update_failed = true" }

  enum highstate: [:not_applied, :pending, :failed, :applied, :pending_removal, :removal_failed]
  enum role: [:master, :worker, :admin]

  validates :minion_id, presence: true, uniqueness: true
  validates :fqdn, presence: true

  # override the json formatter to include the cloud_framework method
  def as_json(options = {})
    options[:methods] ||= []
    options[:methods] << :cloud_framework
    super
  end

  # Update all minions grains
  def self.update_grains
    # rubocop:disable Lint/HandleExceptions, SkipsModelValidations
    Minion.all.find_each do |minion|
      begin
        minion_grains = minion.salt.info
        online = minion_grains.present?
        # update minion early as minion_grains can't be accessed
        minion.update_columns online: false && next unless online

        tx_update_reboot_needed = minion_grains["tx_update_reboot_needed"] || false
        tx_update_failed = minion_grains["tx_update_failed"] || false
        minion.update_columns fqdn:                    minion_grains["fqdn"],
                              online:                  online,
                              tx_update_reboot_needed: tx_update_reboot_needed,
                              tx_update_failed:        tx_update_failed
      rescue StandardError
      end
    end
    # rubocop:enable Lint/HandleExceptions, SkipsModelValidations
  end

  # Example:
  #   Minion.assign_roles(
  #     roles: {
  #       master: [1],
  #       worker: [2, 3]
  #     },
  #     default_role: :dns
  #   )
  def self.assign_roles(roles: {}, default_role: nil, remote: false)
    # Lookup selected masters and workers
    masters = Minion.select_role_members(roles: roles, role: :master)
    minions = Minion.select_role_members(roles: roles, role: :worker)

    # assign roles to each master and worker
    {}.tap do |ret|
      masters.find_each do |master|
        ret[master.minion_id] = master.assign_role(:master, remote: remote)
      end

      minions.find_each do |minion|
        ret[minion.minion_id] = minion.assign_role(:worker, remote: remote)
      end

      # assign default role if there is any minion left with no role
      if default_role
        Minion.where(role: nil).find_each do |minion|
          ret[minion.minion_id] = minion.assign_role(default_role, remote: remote)
        end
      end
    end
  end

  # Prepares an ActiveRecord relation which will return all the members
  # assigned to given role.
  def self.select_role_members(roles: {}, role: nil)
    Minion.where id: (roles.key?(role) ? roles[role].map(&:to_i) : [])
  end

  # rubocop:disable SkipsModelValidations
  # Assigns a role to this minion locally in the database, and send that role
  # to salt subsystem if remote is true.
  def assign_role(new_role, remote: false)
    Minion.transaction do
      # We set highstate to pending only if we are gonna call salt
      highstate = remote ? :pending : :not_applied
      success   = update_columns role:      Minion.roles[new_role],
                                 highstate: Minion.highstates[highstate]
      if success && remote
        salt.assign_role
      else
        success
      end
    end
  rescue Velum::SaltApi::SaltConnectionException
    errors.add :base, "Failed to apply role #{new_role} to #{minion_id}"
    false
  end
  # rubocop:enable SkipsModelValidations

  # rubocop:disable Rails/SkipsModelValidations
  # Updates all nodes with a grain of `tx_update_reboot_needed: True` with a
  # highstate = pending, and persists it to the database
  def self.mark_pending_update
    Minion.cluster_role.where(tx_update_reboot_needed: true)
          .update_all highstate: Minion.highstates[:pending]
  end
  # rubocop:enable SkipsModelValidations

  # rubocop:disable Rails/SkipsModelValidations
  # Forcefully updates all nodes to a pending highstate
  def self.mark_pending_bootstrap
    Minion.cluster_role.update_all highstate: Minion.highstates[:pending]
  end
  # rubocop:enable Rails/SkipsModelValidations

  # rubocop:disable Rails/SkipsModelValidations
  # Updates the provided `minion_ids` to be in `pending_removal` status
  def self.mark_pending_removal(minion_ids: [])
    Minion.where(minion_id: minion_ids).update_all highstate: Minion.highstates[:pending_removal]
  end
  # rubocop:enable Rails/SkipsModelValidations

  def self.remove_minion(minion_id)
    Minion.delete_all(minion_id: minion_id)
  end

  # Returns the proxy for the salt minion
  def salt
    @salt ||= Velum::SaltMinion.new minion: self
  end

  # The framework where this minion is running
  # (currently all minions must be in the same framework)
  def cloud_framework
    Pillar.value(pillar: :cloud_framework)
  end
end
