# Given a list of LDAP entries for a given VM collects a hash of Tag Catigories to Tag(s) and Custom Attributes to assign to that VM.
#
# NOTE: Not meant to be overriden by implimentors.
#
# EXPECTED
#   EVM STATE || EVM CURRENT || EVM OBJECT || EVM ROOT || $evm.root['miq_provision']
#     :vm - set to VM to get LDAP entries for
#
#   EVM STATE || EVM CURRENT || EVM OBJECT || EVM ROOT
#     :ldap_entries - the ldap entries found for the given VM
#
# SETS
#   EVM OBJECT
#     'ldap_vm_tags'              - Hash of Tag Catigories to Tag(s) for the given VM
#     'ldap_vm_custom_attributes' - Hash of Custom Attributes to value for the given VM
#     'ldap_sync_status'          - If this method completes succesfully then this is always 'Succesfull'.
#     'ldap_sync_successful'      - If this method completes succesfully then this is always True.
@DEBUG = false

require 'rubygems'
require 'net/ldap'

GET_VM_TAGS_FROM_LDAP_ENTRY_URI = 'Integration/LDAP/Operations/Methods/get_vm_tags_and_attributes_from_ldap_entry'

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

# Gets VM Tags and Custom Attributes to apply to the VM based on an LDAP entry for that VM
#
# @param ldap_entry LDAP etnry to get the VM Tags and Custom Attributes for
#
# @return ldap_vm_tags              VM Tags to apply based on the given LDAP entry
#         ldap_vm_custom_attributes VM Custom Attributes to apply based on the given LDAP entry
def get_vm_tags_and_attributes_from_ldap_entry(vm, ldap_entry)
  $evm.log(:info, "{ vm => '#{vm.name}', ldap_entry='#{ldap_entry}'") if @DEBUG
  
  # set params
  $evm.root[:vm]         = vm
  $evm.root[:ldap_entry] = ldap_entry
  
  # call method
  result = $evm.instantiate("#{GET_VM_TAGS_FROM_LDAP_ENTRY_URI}")
  
  # clean up params
  $evm.root[:vm]         = nil
  $evm.root[:ldap_entry] = nil
  
  # return result
  return result[:ldap_vm_tags], result[:ldap_vm_custom_attributes]
end

begin
  # get the parameters
  ldap_entries = get_param(:ldap_entries)
  error("ldap_entries parameter not found") if ldap_entries.nil?
  
  if $evm.root['miq_provision']
    vm = $evm.root['miq_provision'].vm
  else
    vm = get_param(:vm)
  end
  error("vm parameter not found") if vm.nil?

  # Collect all of the Tags and Custom Attributes to apply to the VM
  ldap_vm_tags = {}
  ldap_vm_custom_attributes = {}
  ldap_entries.each do |ldap_entry|
    # get the VM Tags and Attributes for the given VM and LDAP entry
    entry_ldap_vm_tags, entry_ldap_vm_custom_attributes = get_vm_tags_and_attributes_from_ldap_entry(vm, ldap_entry)
    $evm.log(:info, "entry_ldap_vm_tags=#{entry_ldap_vm_tags}")                           if @DEBUG
    $evm.log(:info, "entry_ldap_vm_custom_attributes=#{entry_ldap_vm_custom_attributes}") if @DEBUG
    
    # if multiple values for the same Tag Catigory join the multiple values into any array
    ldap_vm_tags.merge!(entry_ldap_vm_tags) { |tag_catigory, existing_tag, new_tag|
      existing_tag = [existing_tag] if !existing_tag.kind_of?(Array)
      new_tag      = [new_tag]      if !new_tag.kind_of?(Array)         
      existing_tag.concat(new_tag)
    }
        
    # if multiple values for the same Custom Attribute conact the string with commas
    ldap_vm_custom_attributes.merge!(entry_ldap_vm_custom_attributes) { |custom_attribute, existing_value, new_value|
      "#{existing_value}, #{new_value}"
    }
  end
  
  # Set the LDAP Sync Status
  $evm.object['ldap_sync_status']     = "Successful"   
  $evm.object['ldap_sync_successful'] = true
  
  # set the VM Tags and Custom Attributes that need to be set on the VM
  $evm.object['vm_tags']              = ldap_vm_tags
  $evm.object['vm_custom_attributes'] = ldap_vm_custom_attributes
  $evm.log(:info, "$evm.object['vm_tags'] = #{$evm.object['vm_tags']}") if @DEBUG
  $evm.log(:info, "$evm.object['vm_custom_attributes'] = #{$evm.object['vm_custom_attributes']}") if @DEBUG
end
