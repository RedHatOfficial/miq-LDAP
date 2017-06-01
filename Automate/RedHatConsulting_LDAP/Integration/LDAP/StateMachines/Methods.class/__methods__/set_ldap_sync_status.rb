# Sets the LDAP sync status as Tags and Custom Attributes based on the given input.
# If not input is given the assumption is that the LDAP sync was a failure.
#
# EXPECTED
#   EVM STATE || EVM CURRENT || EVM OBJECT || EVM ROOT
#     :ldap_sync_status     - Status message about the last LDAP sync
#     :ldap_sync_successful - true if the last LDAP sync was a success, false otherwise
#
# SETS
#   EVM OBJECT
#     :ldap_vm_tags              - Hash of Tag Catigories to Tag(s) for the given VM
#     :ldap_vm_custom_attributes - Hash of Custom Attributes to value for the given VM
@DEBUG = false

TAG_CATIGORY_LDAP_SYNC_SUCCESSFUL = "LDAP Sync Successful"
ATTRIBUTE_LAST_LDAP_SYNC          = "Last LDAP Sync Attempt"
ATTRIBUTE_LDAP_SYNC_STATUS        = "LDAP Sync Status"
DEFAULT_LDAP_SYNC_STAUTS          = "Unknown"
DEFAULT_LDAP_SYNC_SUCCESSFUL      = false

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
  # get current list of VM Tags and Custom Attributes
  vm_tags                = get_param(:vm_tags) || {}
  vm_custom_attributes   = get_param(:vm_custom_attributes) || {}
  $evm.log(:info, "Get: vm_tags=#{vm_tags}") if @DEBUG
  $evm.log(:info, "Get: vm_custom_attributes=#{vm_custom_attributes}") if @DEBUG
  
  # determine LDAP sync status
  ldap_sync_successful = get_param(:ldap_sync_successful) || DEFAULT_LDAP_SYNC_SUCCESSFUL
  ldap_sync_status     = get_param(:ldap_sync_status)     || DEFAULT_LDAP_SYNC_STAUTS
  $evm.log(:info, "Get LDAP Sync Status: { :ldap_sync_successful => '#{ldap_sync_successful}', :ldap_sync_status => '#{ldap_sync_status}' }") if @DEBUG
  
  # set LDAP Sync status as tags and attributes
  vm_tags[TAG_CATIGORY_LDAP_SYNC_SUCCESSFUL]       = ldap_sync_successful.to_s
  vm_custom_attributes[ATTRIBUTE_LDAP_SYNC_STATUS] = ldap_sync_status
  vm_custom_attributes[ATTRIBUTE_LAST_LDAP_SYNC]   = "#{Time.new.inspect}"

  # Update the set of VM Tags and Custom Attributes that need to be set on the VM
  $evm.object['vm_tags']              = vm_tags
  $evm.object['vm_custom_attributes'] = vm_custom_attributes
  $evm.log(:info, "Set: $evm.object['vm_tags']=#{$evm.object['vm_tags']}") if @DEBUG
  $evm.log(:info, "Set: $evm.object['vm_custom_attributes'] =#{$evm.object['vm_custom_attributes'] }") if @DEBUG
end
