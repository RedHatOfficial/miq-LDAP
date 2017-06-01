# Given a list of LDAP entries for a given VM collects a hash of Tag Catigories to Tags and a hash of Custom Attributes to assign to that VM.
#
# NOTE: Intended to be overriden by implimentors.
#       When overriding should only need to modify `get_vm_tags_and_attributes_from_ldap_attribute`
#
# EXPECTED
#   EVM STATE || EVM CURRENT || EVM OBJECT || EVM ROOT || $evm.root['miq_provision']
#     vm - set to VM to get LDAP entries for
#
#   EVM STATE || EVM CURRENT || EVM OBJECT || EVM ROOT
#     ldap_entries - LDAP entires to get the Tag Catigory(s) and Tag(s) for. 
#
# SETS
#   EVM OBJECT
#     :ldap_vm_tags - Hash of Tag Catigories to Tag(s) to assign to the given VM.
#                     If multiple Tags for a given Tag Catigory then an array value is returned.
#                     EX:
#                       { 'catigory1' => 'hello world',    # EXAMPLE of single tag for a tag catigory
#                         'catigory2' => ['foo', 'bar'] }  # EXAMPLE of multiple tags for a tag catigory
#
#     :ldap_vm_custom_attributes - Hash of Custom Attributes to assign to the given VM.
#                               EX:
#                                 { 'custom_attr1' => 'hello world',
#                                   'custom_attr2' => 'foo bar' }
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

# !!!!! IMPLIMENTOR TODO: Impliment business logic here !!!!!!
#
# Given an LDAP attribute returns the VM Tags and VM Custom Attributes for that LDAP attribute
#
# NOTE: This is the business logic that is intended to be overriden by implimentors.
#
# @param ldap_attribute       LDAP attribute to get the VM Tags and VM Custom Attributes for
# @param ldap_attribute_value LDAP attribute value to get the VM Tags and VM Custom Attributes for
#
# @return ldap_vm_tags              VM Tags to apply based on the given LDAP attribute
#         ldap_vm_custom_attributes VM Custom Attributes to apply based on the given LDAP attribute
def get_vm_tags_and_attributes_from_ldap_attribute(vm, ldap_attribute, ldap_attribute_value)
  ldap_attribute_vm_tags = {}
  ldap_attribute_vm_custom_attributes = {}
  
  # IMPLIMENTOR TODO:
  # Business logic
  $evm.log(:warn, "This method is itended to be overriden by an implimentor's namespace. "\
                  "The default implimentation does not assign any Tag Catigories, Tags, or Custom Attributes to the given VM. "\
                  "{ 'vm' => '#{vm.name}', 'ldap_attribute' => '#{ldap_attribute}', 'ldap_attribute_value' => '#{ldap_attribute_value}' }")

  return ldap_attribute_vm_tags, ldap_attribute_vm_custom_attributes
end

# IMPLIMENTORS: DO NOT MODIFY
#
# @see: get_vm_tags_and_attributes_from_ldap_attribute
begin
  # get the parameters
  if $evm.root['miq_provision']
    vm = $evm.root['miq_provision'].vm
  else
    vm = get_param(:vm)
  end
  error("vm parameter not found") if vm.nil?
  $evm.log(:info, "vm=#{vm.name}") if @DEBUG
  
  ldap_entry = get_param(:ldap_entry)
  error("ldap_entry parameter not found") if ldap_entry.nil?
  $evm.log(:info, "ldap_entry=#{ldap_entry}") if @DEBUG
  
  # collect all of the VM Tags and VM Custom Attributes based on the LDAP attributes in the given LDAP entry
  ldap_vm_tags = {}
  ldap_vm_custom_attributes = {}
  ldap_entry.each do |ldap_attribute, ldap_attribute_values|
    ldap_attribute_values.each do |ldap_attribute_value|
      ldap_attribute_vm_tags, ldap_attribute_vm_custom_attributes = get_vm_tags_and_attributes_from_ldap_attribute(
        vm,
        ldap_attribute,
        ldap_attribute_value
      )
      $evm.log(:info, "ldap_attribute_vm_tags=#{ldap_attribute_vm_tags}")                           if @DEBUG
      $evm.log(:info, "ldap_attribute_vm_custom_attributes=#{ldap_attribute_vm_custom_attributes}") if @DEBUG
        
      # if multiple values for the same Tag Catigory join the multiple values into any array
      ldap_vm_tags.merge!(ldap_attribute_vm_tags) { |tag_catigory, existing_tag, new_tag|
        existing_tag = [existing_tag] if !existing_tag.kind_of?(Array)
        new_tag      = [new_tag]      if !new_tag.kind_of?(Array)         
        existing_tag.concat(new_tag)
      }
        
      # if multiple values for the same Custom Attribute conact the string with commas
      ldap_vm_custom_attributes.merge!(ldap_attribute_vm_custom_attributes) { |custom_attribute, existing_value, new_value|
        "#{existing_value}, #{new_value}"
      }    
    end
  end
  
  # return Tag Catigories and associated Tag(s) for the given LDAP entry and the given VM
  #   EX:
  #     { 'catigory1' => 'hello world',    # EXAMPLE of single tag for a tag catigory
  #       'catigory2' => ['foo', 'bar'] }  # EXAMPLE of multiple tags for a tag catigory
  $evm.object[:ldap_vm_tags] = ldap_vm_tags
  $evm.log(:info, "$evm.object[:ldap_vm_tags]=#{$evm.object[:ldap_vm_tags]})") if @DEBUG
  
  # return Custom Attributes for the given LDAP entry and the given VM
  #   EX:
  #     { 'custom_attr1' => 'hello world',
  #       'custom_attr2' => 'foo bar' }
  $evm.object[:ldap_vm_custom_attributes] = ldap_vm_custom_attributes
  $evm.log(:info, "$evm.object[:ldap_vm_custom_attributes]=#{$evm.object[:ldap_vm_custom_attributes]})") if @DEBUG
end
