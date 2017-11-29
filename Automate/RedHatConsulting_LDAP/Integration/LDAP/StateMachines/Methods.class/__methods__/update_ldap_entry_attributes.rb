# Adds an LDAP entry for a given VM.
#
# EXPECTED
#   EVM STATE || EVM CURRENT || EVM OBJECT || EVM ROOT || $evm.root['miq_provision']
#     :vm                    - VM to add an LDAP entry for
#
#   EVM STATE || EVM CURRENT || EVM OBJECT || EVM ROOT
#     :ldap_entries          - LDAP entry for the given VM
#     :ldap_entry_attributes - New LDAP entry attributes to set
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
  
  # narrow down to a single LDAP entry in the off chance there is more then one
  error("More then one existing LDAP_entry for VM (#{vm.name}) was found, unsure how to handle this case.") if ldap_entries.length > 1
  ldap_entry = ldap_entries[0]
  $evm.log(:info, "ldap_entry => #{ldap_entry}") if @DEBUG
  
  # get the LDAP entry attributes to set
  ldap_entry_attributes = get_param(:ldap_entry_attributes)
  error('ldap_entry_attributes parameter not found') if ldap_entry_attributes.nil?
  
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
  
  # calculate LDAP operations based on current LDAP attributes and the given LDAP entry attributes
  ldap_attribute_operations = []
  ldap_entry_attributes.each do |ldap_attribute, ldap_attribute_values|
    $evm.log(:info, "{ ldap_attribute => '#{ldap_attribute}', new_value => #{ldap_attribute_values}, current_value => #{ldap_entry[ldap_attribute]} }") if @DEBUG
    
    # if remove existing attribute
    # else if add new attribute
    # else if update existing attribute
    # else error
    if ldap_attribute_values.blank? && !ldap_entry[ldap_attribute].blank?
      ldap_attribute_operations.push([:delete, ldap_attribute, nil])
    elsif !ldap_attribute_values.blank? && ldap_entry[ldap_attribute].blank?
      # All values get added individually instead of multiple entries to the same :add operation.
      if ldap_attribute_values.kind_of?(Array) && ldap_attribute_values.size > 1
        ldap_attribute_values.each do |value|
          value = value.strip if value.is_a?(String)
          ldap_attribute_operations.push([:add, ldap_attribute, value])
        end
      else
        ldap_attribute_values = ldap_attribute_values.strip if ldap_attribute_values.is_a?(String)
        ldap_attribute_operations.push([:add, ldap_attribute, ldap_attribute_values])
      end
    elsif ldap_attribute_values == ldap_entry[ldap_attribute]
      # do nothing since existing and new value are already equal
      $evm.log(:info, "No op for LDAP entry attribute (#{ldap_attribute}) since existing value already equals new value.") if @DEBUG
    elsif !ldap_attribute_values.blank? && !ldap_entry[ldap_attribute].blank?
      ldap_attribute_values = ldap_attribute_values.strip if ldap_attribute_values.is_a?(String)
      ldap_attribute_operations.push([:replace, ldap_attribute, ldap_attribute_values])
    else
      error("Could not calculate LDAP operation for LDAP entry attribute (#{ldap_attribute}). This should never happen.")
    end
  end
  $evm.log(:info, "ldap_attribute_operations => #{ldap_attribute_operations}") if @DEBUG

  # if there are LDAP operations to perform, do so
  if !ldap_attribute_operations.blank?
    # if able to bind to LDAP
    # else error binding
    $evm.log(:info, "LDAP bind to #{ldap_server} as #{ldap_username}") if @DEBUG
    if ldap.bind
      $evm.log(:info, "LDAP bound to #{ldap_server} as #{ldap_username}") if @DEBUG
    
      $evm.log(:info, "Modify LDAP entry attributes: { :dn => #{ldap_entry.dn} }") if @DEBUG
      modify_success = ldap.modify(:dn => ldap_entry.dn, :operations => ldap_attribute_operations)
      
      if modify_success
        $evm.log(:info, "Modified LDAP entry attributes: { :dn => #{ldap_entry.dn}, ldap_attribute_operations => #{ldap_attribute_operations} }")
      else
        error("Failed to perform LDAP entry attribute operations. LDAP Error = #{ldap.get_operation_result.to_s}")
      end
    else
      error("LDAP could not bind to #{ldap_server} as #{ldap_username}.  LDAP Error = #{ldap.get_operation_result.to_s}")
    end
  else
    $evm.log(:info, "No LDAP entry attribute operations to perform on DN: #{ldap_entry.dn}")
  end
end
