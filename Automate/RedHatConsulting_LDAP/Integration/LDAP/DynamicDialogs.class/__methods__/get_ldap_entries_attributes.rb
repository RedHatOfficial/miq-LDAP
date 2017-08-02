# Gets the current LDAP entry attributes from the given LDAP entries and
# converts them to YAML for use by other dialog elements.
#
# The purpose of this is to make it so other dialog elements do not need to each
# find the LDAP entries and can instead reference this YAML stored in a helper hidden dialog element.
#
# EXPECTED
#   EVM STATE || EVM CURRENT || EVM OBJECT || EVM ROOT
#     :ldap_entries - LDAP entries to get the attributes of and return as YAML
#
@DEBUG = false

require 'rubygems'
require 'net/ldap'
require 'yaml'

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
# This function checks all of them in priorty order as well as checking for symbol or string.
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
  # get the parameters
  ldap_entries = get_param(:ldap_entries)
  error("ldap_entries parameter not found") if ldap_entries.nil?
  
  ldap_entries_attributes = []
  ldap_entries.each do |ldap_entry|
    ldap_entry_attributes = {}
    ldap_entry.each do |ldap_attribute, ldap_attribute_values|
      ldap_entry_attributes[ldap_attribute] = ldap_attribute_values
    end
    
    ldap_entries_attributes.push(ldap_entry_attributes)
  end
  $evm.log(:info, "ldap_entries_attributes => #{ldap_entries_attributes}") if @DEBUG
  
  dialog_field              = $evm.object
  dialog_field["data_type"] = 'string'
  dialog_field["read_only"] = true
  dialog_field["visible"]   = true
  dialog_field["value"]     = ldap_entries_attributes.to_yaml
end
