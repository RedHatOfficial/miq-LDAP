# Updates the LDAP entry attributes given batch of VMs.
#
# This is needed because of the 10 minute timeout on any Automate Method. This way if needing to update 1000s of VMs
# they can be done in asyncrounous batches that can complete in under the 10 minute timeout.
#
# EXPECTED
#   EVM STATE || EVM CURRENT || EVM OBJECT || EVM ROOT
#     :vm_ids - Array of VM IDs to update as a batch when updating the LDAP entry attributes of a large set of VMs
#
@DEBUG = false

UPDATE_LDAP_ENTRY_ATTRIBUTES_URI = 'Integration/LDAP/StateMachines/UpdateLDAPEntryAttributes/Default'

# Log an error and exit.
#
# @param msg Message to error with
def error(msg)
  $evm.log(:error, msg)
  $evm.root['ae_result'] = 'error'
  $evm.root['ae_reason'] = msg.to_s
  exit MIQ_STOP
end

# IMPLEMENTORS: DO NOT MODIFY
def dump_root
  $evm.log("info", "Listing Root Object Attributes:") 
  $evm.root.attributes.sort.each { |k, v| $evm.log("info", "\t#{k}: #{v}") }
  $evm.log("info", "===========================================") 
end

# IMPLEMENTORS: DO NOT MODIFY
def dump_object(object_string, object)
  $evm.log("info", "Listing #{object_string} Attributes:") 
  object.attributes.sort.each { |k, v| $evm.log("info", "\t#{k}: #{v}") }
  $evm.log("info", "===========================================") 
end

# IMPLEMENTORS: DO NOT MODIFY
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

# Updates the LDAP entry attributes for a given VM.
#
# @param vm      VM to update the LDAP entry attributes for
# @param options Set these options in options on evm.root for the instantiated method to take advantage of
#
# @return true if succesfully updated the LDAP entry attributes,
#         false if there was any error in the state machine to update the LDAP entry attributes
def update_ldap_entry_attributes(vm, options)
  $evm.log(:info, "START: Update LDAP entry attributes for { vm => #{vm.name} }") if @DEBUG

  saved_vm = $evm.root['vm']

  begin
    # instantiate the state machine to update a single VM
    $evm.root['vm']      = vm
    $evm.root['options'] = options
    $evm.instantiate(UPDATE_LDAP_ENTRY_ATTRIBUTES_URI)
    success = true
  ensure
    success = $evm.root['ae_result'] == nil || $evm.root['ae_result'] == 'ok'
    success = $evm.root['ae_reason'] if !success
    
    # clean up root
    $evm.root['ae_result']    = nil
    $evm.root['ae_reason']    = nil
    
    $evm.root['vm']           = saved_vm
    $evm.root['options']      = nil
    $evm.root['ldap_entries'] = nil
  end
  
  $evm.log(:info, "END: Update LDAP entry attributes for { vm => #{vm.name} }") if @DEBUG
  return success
end

begin
  dump_root() if @DEBUG
  
  # get parameters
  vm_ids = get_param(:vm_ids)
  vm_ids = vm_ids.split(',') if vm_ids.is_a?(String)
  error("vm_ids parameter not found") if vm_ids.nil?
  $evm.log(:info, "vm_ids => #{vm_ids}") if @DEBUG
  
  options = get_param(:options)
  $evm.log(:info, "options => #{options}") if @DEBUG
  
  # update each VM in the current container of VMs
  $evm.log(:info, "START: Update LDAP entry attributes for: { :vm_ids => #{vm_ids} }")
  update_results = {}
  vm_ids.each do |vm_id|
    vm = $evm.vmdb('vm').find_by_id(vm_id)
    update_results[vm.name] = update_ldap_entry_attributes(vm, options)
  end
  $evm.log(:info, "END: Update LDAP entry attributes for: { :vm_ids => #{vm_ids} }")
  
  $evm.log(:info, "{ update_results => #{update_results} }") if @DEBUG
end
