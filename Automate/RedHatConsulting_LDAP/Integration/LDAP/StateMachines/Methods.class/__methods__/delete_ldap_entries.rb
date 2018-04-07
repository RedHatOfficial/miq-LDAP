# Deletes the LDAP entry for a given VM.
#
# EXPECTED
#   EVM STATE || EVM CURRENT || EVM OBJECT || EVM ROOT || $evm.root['miq_provision']
#     :vm                    - VM to add an LDAP entry for
#
#   EVM STATE || EVM CURRENT || EVM OBJECT || EVM ROOT
#     :ldap_entries          - Existing LDAP entry for the given VM
#
@DEBUG = false

require 'rubygems'
require 'net/ldap'

# Gets the LDAP connection configuration information.
LDAP_CONFIG_URI = 'Integration/LDAP/Configuration/default'
def get_ldap_config()
  return $evm.instantiate(LDAP_CONFIG_URI)
end

# Log an error and exit.
#
# @param msg Message to error with
def error(msg)
  $evm.log(:error, msg)
  $evm.root['ae_result'] = 'error'
  $evm.root['ae_reason'] = msg.to_s
  exit MIQ_STOP
end

# There are many ways to attempt to pass parameters in Automate.
# This function checks all of them in priority order as well as checking for symbol or string.
#
# Order:
#   1. Current
#   2. Object
#   3. Root
#   4. State
#
# @return Value for the given parameter or nil if none is found
def get_param(param)  
  # else check if current has been set for given param
  param_value ||= $evm.current[param.to_sym]
  param_value ||= $evm.current[param.to_s]
 
  # else cehck if current has been set for given param
  param_value ||= $evm.object[param.to_sym]
  param_value ||= $evm.object[param.to_s]
  
  # else check if param on root has been set for given param
  param_value ||= $evm.root[param.to_sym]
  param_value ||= $evm.root[param.to_s]
  
  # check if state has been set for given param
  param_value ||= $evm.get_state_var(param.to_sym)
  param_value ||= $evm.get_state_var(param.to_s)

  $evm.log(:info, "{ '#{param}' => '#{param_value}' }") if @DEBUG
  return param_value
end

begin
  # get VM to set the LDAP entry attributes for
  if $evm.root['miq_provision']
    vm = $evm.root['miq_provision'].vm
  else
    vm = get_param(:vm)
  end
  error("vm parmaeter not found") if vm.nil?
  
  # get the existing LDAP entries for the given VM
  ldap_entries = get_param(:ldap_entries)
  error("ldap_entries parameter not found") if ldap_entries.blank?

  # determine the LDAP connection configuration information
  ldap_config = get_ldap_config()
  error("LDAP Configuration not found") if ldap_config.nil?
  ldap_server          = ldap_config['ldap_server']
  ldap_username        = ldap_config['ldap_username']
  ldap_password        = ldap_config.decrypt('ldap_password')
  ldap_port            = ldap_config['ldap_port']
  ldap_encryption      = ldap_config['ldap_encryption']
  ldap_treebase        = ldap_config['ldap_treebase']
  ldap_hostname_filter = ldap_config['ldap_hostname_filter']
  $evm.log(:info, "ldap_server=#{ldap_server}")                   if @DEBUG
  $evm.log(:info, "ldap_username=#{ldap_username}")               if @DEBUG
  $evm.log(:info, "ldap_port=#{ldap_port}")                       if @DEBUG
  $evm.log(:info, "ldap_encryption=#{ldap_encryption}")           if @DEBUG
  $evm.log(:info, "ldap_treebase=#{ldap_treebase}")               if @DEBUG
  $evm.log(:info, "ldap_hostname_filter=#{ldap_hostname_filter}") if @DEBUG

  # create the LDAP connection
  ldap = Net::LDAP.new(
    :host => ldap_server,
    :port => ldap_port,
    :auth => {
      :method => :simple,
      :username => ldap_username,
      :password => ldap_password
    },
    :encryption => ldap_encryption
  )

  $evm.log(:info, "LDAP bind to #{ldap_server} as #{ldap_username}") if @DEBUG
  if ldap.bind
    $evm.log(:info, "LDAP bound to #{ldap_server} as #{ldap_username}") if @DEBUG
    
    deletion_errors = []
    ldap_entries.each do |ldap_entry|
      $evm.log(:info, "Delete LDAP entry: { :dn => #{ldap_entry[:dn]} }") if @DEBUG
      delete_success = ldap.delete(:dn => ldap_entry[:dn])
      
      if delete_success
        $evm.log(:info, "Successfully deleted LDAP entry: { :dn => #{ldap_entry[:dn]} }")
      else
        # collect errors
        deletion_errors << "Failed to deleted LDAP entry: { :dn => #{ldap_entry[:dn]} }. This is typically either a permisisons issue. See LDAP server error logs for details."
      end
    end
    
    # if had any errors, error now.
    if !deletion_errors.empty?
      error(deletion_errors.join(" "))
    end
  else
    error("LDAP could not bind to #{ldap_server} as #{ldap_username}")
  end
end
