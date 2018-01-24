# Updates the VM Tags and Attributes for a given batch of VMs.
#
# This is needed because of the 10 minute timeout on any Automate Method. This way if needing to update 1000s of VMs
# they can be done in asyncrounous batches that can complete in under the 10 minute timeout.
#
# EXPECTED
#   EVM STATE || EVM CURRENT || EVM OBJECT || EVM ROOT
#     :vm_ids - Array of VM IDs to update as a batch when updating the VM Tags and Custom Attributes of a large set of VMs
#
@DEBUG = false

UPDATE_VM_TAGS_AND_CUSTOM_ATTRIBUTES_FROM_LDAP_ENTRIES_URI = 'Integration/LDAP/StateMachines/UpdateVMTagsAndCustomAttributesFromLDAPEntries/Default'

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

# Updates the VM Tags and Custom Attributes based on LDAP entries
#
# @param vm VM to update the Tags and Custom Attributes for based on LDAP entries
#
# @return true if succesfully updated Tags and Custom Attributes based on LDAP entries,
#         false if there was any error in the state machine to update the Tags and Custom Attributes for the given VM
def update_vm_tags_and_custom_attributes_from_ldap_entries(vm)
  $evm.log(:info, "START: Update VM Tags and Custom Attributes based on LDAP records for { vm => #{vm.name} }") if @DEBUG
  
  begin
    # instantiate the state machine to update a single VM
    $evm.root['vm'] = vm
    $evm.instantiate(UPDATE_VM_TAGS_AND_CUSTOM_ATTRIBUTES_FROM_LDAP_ENTRIES_URI)
    success = true
  ensure
    success = $evm.root['ae_result'] == nil || $evm.root['ae_result'] == 'ok'
    success = $evm.root['ae_reason'] if !success
    
    # clean up root
    $evm.root['ae_result']            = nil
    $evm.root['ae_reason']            = nil
    
    $evm.root['vm']                   = nil
    $evm.root['ldap_entries']         = nil
    $evm.root['ldap_sync_status']     = nil
    $evm.root['ldap_sync_successful'] = nil
    $evm.root['vm_tags']              = nil
    $evm.root['vm_custom_attributes'] = nil
  end
  
  $evm.log(:info, "END: Updated VM Tags and Custom Attributes based on LDAP records for { vm => #{vm.name} }") if @DEBUG
  return success
end

begin
  # get parameters
  vm_ids = get_param(:vm_ids)
  vm_ids = vm_ids.split(',') if vm_ids.is_a?(String)
  error("vm_ids parameter not found") if vm_ids.nil?
  $evm.log(:info, "{ :vm_ids => #{vm_ids} }") if @DEBUG
  
  # update each VM in the current container of VMs
  $evm.log(:info, "START: Update VM Tags and Custom Attributes from LDAP Entries for: { :vm_ids => #{vm_ids} }")
  update_results = {}
  vm_ids.each do |vm_id|
    vm = $evm.vmdb('vm').find_by_id(vm_id)
    update_results[vm.name] = update_vm_tags_and_custom_attributes_from_ldap_entries(vm)
  end
  $evm.log(:info, "END: Update VM Tags and Custom Attributes from LDAP Entries for: { :vm_ids => #{vm_ids} }")
  
  $evm.log(:info, "{ update_results => #{update_results} }") if @DEBUG
end
