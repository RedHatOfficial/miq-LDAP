# Returns a dynamic drop down dialog with all of the given LDAP entries using the value of the given attribute names for the drop down values and descriptions.
#
# EXPECTED
#   EVM STATE || EVM CURRENT || EVM OBJECT || EVM ROOT
#     ldap_entries                                 - LDAP entries to display in the dynamic drop down
#     dialog_value_ldap_entry_attribute_name       - LDAP entry attribute to use as the value for the dynamic drop down
#     dialog_description_ldap_entry_attribute_name - LDAP entry attribute to use as the description for the dynamic drop down
#                                                    Optional. Defaults to `dialog_value_ldap_entry_attribute_name` if not specifed. 
#
@DEBUG = false

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

  $evm.log(:info, "get_param: { '#{param}' => '#{param_value}' }") if @DEBUG
  return param_value
end

begin
  # If there isn't a vmdb_object_type yet just exit. The method will be recalled with an vmdb_object_type
  exit MIQ_OK unless $evm.root['vmdb_object_type']
  
  # get the parameters
  ldap_entries = get_param(:ldap_entries)
  $evm.log(:info, "ldap_entries => #{ldap_entries}") if @DEBUG
  
  values = {}
  if ldap_entries
    dialog_value_ldap_entry_attribute_name = get_param(:dialog_value_ldap_entry_attribute_name)
    error("dialog_value_ldap_entry_attribute_name parameter not found") if dialog_value_ldap_entry_attribute_name.nil?
    
    dialog_description_ldap_entry_attribute_name = get_param(:dialog_description_ldap_entry_attribute_name) || dialog_value_ldap_entry_attribute_name
  
    values = {}
    ldap_entries.each do |ldap_entry|
      value         = ldap_entry[dialog_value_ldap_entry_attribute_name.to_sym][0]
      description   = ldap_entry[dialog_description_ldap_entry_attribute_name.to_sym][0]
      values[value] = description
    end
    $evm.log(:info, "values => #{values}") if @DEBUG
    values[nil] = '<Choose>'
  end
  
  dialog_field               = $evm.object
  dialog_field["sort_by"]    = "value"
  dialog_field["sort_order"] = "ascending"
  dialog_field["data_type"]  = "string"
  dialog_field["required"]   = true
  dialog_field["values"]     = values
  
  $evm.log(:info, "dialog_field['values'] => #{dialog_field['values']}") if @DEBUG
end
