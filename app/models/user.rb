require "net/ldap/dn"
require "velum/ldap"

# User represents administrators in this application.
# rubocop:disable ClassLength
class User < ApplicationRecord
  enabled_devise_modules = [:ldap_authenticatable, :registerable, :rememberable, :trackable,
                            :validatable].freeze

  devise(*enabled_devise_modules)

  before_create :create_ldap_user

  protected

  # rubocop:disable AbcSize,CyclomaticComplexity,MethodLength,PerceivedComplexity
  def create_ldap_user
    # add to OpenLDAP - this should be disabled when using any other LDAP server!

    # Behavior:
    # 1) make sure the People org unit exists, if not, create it
    # 2) make sure the Administrators groupOfUniqueNames exists, if not, create it
    # 3) check if the new user created is a member of the Administrators group, if not, add it
    # 4) check if the user exists, if not, add it

    # check to see if this is because the LDAP auth succeeded, or if we're coming from registration
    # we do this by performing an LDAP search for the new user. If it fails, we need to create the
    # user in LDAP
    ldap_config = Velum::LDAP.ldap_config

    conn_params = {
      host: ldap_config["host"],
      port: ldap_config["port"],
      auth: {
        method:   :simple,
        username: ldap_config["admin_user"],
        password: ldap_config["admin_password"]
      }
    }

    Velum::LDAP.configure_ldap_tls!(ldap_config, conn_params)

    ldap = Net::LDAP.new(**conn_params)

    uid = email[0, email.index("@")]
    user_dn = "uid=#{uid},#{ldap_config["base"]}"

    # first, look for the People org unit
    treebase = ldap_config["base"]
    found = false
    ldap.search(base: treebase, scope: Net::LDAP::SearchScope_BaseObject) do |_entry|
      found = true
    end

    unless found
      people_dn = Net::LDAP::DN.new(treebase).to_a

      attrs = {
        ou:          people_dn[1],
        objectclass: ["top", "organizationalUnit"]
      }

      result = ldap.add(dn: treebase, attributes: attrs)
      op_msg = ldap.get_operation_result.message
      msg = "Unable to create People organizational unit in LDAP: #{op_msg}"
      Velum::LDAP.fail_if_with(result, msg)
    end

    # next, look for the group base
    treebase = ldap_config["group_base"]
    group_found = false
    ldap.search(base: treebase, scope: Net::LDAP::SearchScope_BaseObject) do |_entry|
      group_found = true
    end

    unless group_found
      group_dn = Net::LDAP::DN.new(treebase).to_a

      attrs = {
        ou:          group_dn[1],
        objectclass: ["top", "organizationalUnit"]
      }

      result = ldap.add(dn: treebase, attributes: attrs)
      op_msg = ldap.get_operation_result.message
      msg = "Unable to create Group organizational unit in LDAP: #{op_msg}"
      Velum::LDAP.fail_if_with(result, msg)
    end

    # next, look for the Administrators group in the group base
    treebase = ldap_config["required_groups"][0]
    group_found = false
    member_found = false
    ldap.search(base: treebase, scope: Net::LDAP::SearchScope_BaseObject) do |entry|
      if (entry[:uniquemember].is_a?(Array) && entry[:uniquemember].include?(user_dn)) \
        || entry[:uniquemember].eql?(user_dn)
        member_found = true
      end
      group_found = true
    end

    if !group_found
      admin_dn = Net::LDAP::DN.new(treebase).to_a

      attrs = {
        cn:           admin_dn[1],
        objectclass:  ["top", "groupOfUniqueNames"],
        uniqueMember: user_dn
      }

      result = ldap.add(dn: treebase, attributes: attrs)
      op_msg = ldap.get_operation_result.message
      msg = "Unable to create Administrators group of unique names in LDAP: #{op_msg}"
      Velum::LDAP.fail_if_with(result, msg)
    elsif !member_found
      # if the group already exists, make sure this user is in there
      ops = [
        [:add, :uniqueMember, user_dn]
      ]
      result = ldap.modify(dn: treebase, operations: ops)
      op_msg = ldap.get_operation_result.message
      msg = "Unable to add user to Administrators group in LDAP: #{op_msg}"
      Velum::LDAP.fail_if_with(result, msg)
    end

    filter = Net::LDAP::Filter.eq(ldap_config["attribute"], email)
    treebase = ldap_config["base"]
    found = false
    ldap.search(base: treebase, filter: filter) do |_entry|
      found = true
    end

    return if found

    attrs = {
      cn:           "A User",
      objectclass:  ["person", "inetOrgPerson"],
      uid:          uid,
      userPassword: (password.blank? ? "{CRYPT}#{encrypted_password}" : password),
      givenName:    "A",
      sn:           "User",
      mail:         email
    }

    result = ldap.add(dn: user_dn.to_s, attributes: attrs)
    op_msg = ldap.get_operation_result.message
    msg = "Unable to create Person in LDAP: #{op_msg}"
    Velum::LDAP.fail_if_with(result, msg)
  end
  # rubocop:enable AbcSize,CyclomaticComplexity,MethodLength,PerceivedComplexity
end
# rubocop:enable ClassLength
