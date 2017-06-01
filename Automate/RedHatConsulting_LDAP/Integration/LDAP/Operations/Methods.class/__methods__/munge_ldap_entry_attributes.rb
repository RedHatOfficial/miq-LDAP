# Determine the set of LDAP entry attributes to set on the LDAP entry.
# This can be done with a combination of attributes from the existing LDAP entry,
# information about the VM from CloudForms, user input, or any other source of information the implmentor chooses.
#
# IMPLIMENTORS: Intended to be overriden by implimentors.
#
# EXPECTED
#   EVM STATE || EVM CURRENT || EVM OBJECT || EVM ROOT || $evm.root['miq_provision']
#     vm - VM the new LDAP entry is for.
#
#   EVM STATE || EVM CURRENT || EVM OBJECT || EVM ROOT
#     ldap_entries - Array of existing LDAP entries with existing LDAP entry attributes
#
# SETS
#   EVM OBJECT
#     'ldap_entry_attributes' - Hash of LDAP attributes to set on the LDAP entry for the given VM.
#
@DEBUG = false

require 'rubygems'
require 'net/ldap'

# IMPLIMENTORS: DO NOT MODIFY
#
# Log an error and exit.
#
# @param msg Message to error with
def error(msg)
  $evm.log(:error, msg)
  $evm.root['ae_result'] = 'error'
  $evm.root['ae_reason'] = msg.to_s
  exit MIQ_STOP
end

# IMPLIMENTORS: DO NOT MODIFY
#
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
  $evm.log(:info, "START: EVM Root Dump") if @DEBUG
  $evm.root.attributes.each { |k, v| $evm.log(:info, "  #{k} => #{v}") } if @DEBUG
  $evm.log(:info, "END: EVM Root Dump") if @DEBUG
  
  # get the VM to get the LDAP entry attributes for and
  # get the service dialog attributes associated with that VM
  if $evm.root['miq_provision']
    miq_provision     = $evm.root['miq_provision']
    vm                = miq_provision.vm
    dialog_attributes = miq_provision.options
  else
    vm                = get_param(:vm)
    dialog_attributes = $evm.root.attributes
  end
  error("vm parameter not found")      if vm.blank?
  error("dialog attributes not found") if dialog_attributes.blank?
  $evm.log(:info, "vm => #{vm.name}")                          if @DEBUG
  $evm.log(:info, "dialog_attributes => #{dialog_attributes}") if @DEBUG
  
  # get the existing LDAP entries for the given VM
  ldap_entries = get_param(:ldap_entries)
  error("ldap_entries parameter not found") if ldap_entries.blank?
  
  # narrow down to a single LDAP entry in the off chance there is more then one
  error("More then one existing LDAP_entry for VM (#{vm.name}) was found, unsure how to handle this case.") if ldap_entries.length > 1
  ldap_entry = ldap_entries[0]
  $evm.log(:info, "ldap_entry => #{ldap_entry}") if @DEBUG
  
  # IMPLIMENTORS: Modify as neciessary
  #               This implimentation returns the existing LDAP entry attributes without modification
  #
  ldap_entry_attributes = {}
  ldap_entry.each do |ldap_attribute, ldap_attribute_values|
    ldap_entry_attributes[ldap_attribute] = ldap_attribute_values
    $evm.log(:info, "Set LDAP entry attribute to existing value: { ldap_attribute => #{ldap_attribute}, ldap_attribute_values => #{ldap_attribute_values} }") if @DEBUG
  end
  
  # IMPLIMENTORS: Modify as neciessary
  #               This implimentation overrides any existing LDAP entry attributes with values from dialog elements with names that
  #               start with 'dialog_ldap_entry_attribute_'.
  #               All values are split on "\n" in case it is ment to be an array of values.
  #
  # for each LDAP entry attribute dialog element
  dialog_attributes.select { |k, v| k.to_s.start_with?('dialog_ldap_entry_attribute_') }.each do |dialog_ldap_entry_attribute, dialog_ldap_entry_attribute_value|
    dialog_ldap_entry_attribute_name = dialog_ldap_entry_attribute.to_s.match(/dialog_ldap_entry_attribute_(.*)/i).captures[0]
    ldap_entry_attributes[dialog_ldap_entry_attribute_name] = dialog_ldap_entry_attribute_value.split("\n")
    $evm.log(:info, "Set LDAP entry attribute to value from dialog: { ldap_attribute => #{dialog_ldap_entry_attribute_name}, ldap_attribute_values => #{ldap_entry_attributes[dialog_ldap_entry_attribute_name]} }") if @DEBUG
  end
  
  # IMPLIMENTORS: DO NOT MODIFY
  #
  # return munged LDAP entry attributes
  $evm.object['ldap_entry_attributes'] = ldap_entry_attributes
  $evm.log(:info, "$evm.object['ldap_entry_attributes']=#{$evm.object['ldap_entry_attributes']})") if @DEBUG
end
