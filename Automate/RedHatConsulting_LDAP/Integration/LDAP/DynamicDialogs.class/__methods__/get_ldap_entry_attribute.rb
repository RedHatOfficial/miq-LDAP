# Creates a dialog field for a given LDAP entry attribute.
#
# NOTE:
#   This method depends on the `get_ldap_entries_attributes` method to be setting the `dialog_ldap_entries_attributes`
#   field with a YAML value of all of the existing LDAP entry attributes to avoid having to query LDAP for the entries
#   for mutliple dialog fields all relying on information from that entry.
#
# EXPECTED
#   EVM STATE || EVM CURRENT || EVM OBJECT || EVM ROOT
#     dialog_value_ldap_entry_attribute_name        - LDAP entry attribute name to get the value for
#     dialog_value_ldap_entry_attribute_value_regex - Optional. Regex with a single capture group used to filter and parse the values of the matched LDAP entry attribute name
#
#   EVM ROOT
#     dialog_ldap_entries_attributes - Dialog element that has all of the existing LDAP entry attributes in YAML format.
#     additional_options             - Optional. Additional options to use when creating dialog field. Makes the dialog field a drop down list if set.
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

  $evm.log(:info, "{ '#{param}' => '#{param_value}' }") if @DEBUG
  return param_value
end

begin
  # If there isn't a vmdb_object_type yet just exit. The method will be recalled with an vmdb_object_type
  exit MIQ_OK unless $evm.root['vmdb_object_type']
  
  $evm.log(:info, "$evm.root => #{$evm.root}")                            if @DEBUG
  $evm.root.attributes.each { |k,v| $evm.log(:info, "  #{k} => #{v}") }   if @DEBUG
  $evm.log(:info, "$evm.object => #{$evm.object}")                        if @DEBUG
  $evm.object.attributes.each { |k,v| $evm.log(:info, "  #{k} => #{v}") } if @DEBUG
  
  ldap_entry_attribute_name = get_param(:dialog_value_ldap_entry_attribute_name)
  error("ldap_entry_attribute_name parameter not set") if ldap_entry_attribute_name.blank?
  $evm.log(:info, "ldap_entry_attribute_name => #{ldap_entry_attribute_name}") if @DEBUG
  
  ldap_entry_attribute_value_regex = get_param(:dialog_value_ldap_entry_attribute_value_regex)
  $evm.log(:info, "ldap_entry_attribute_value_regex => #{ldap_entry_attribute_value_regex}") if @DEBUG
  
  ldap_entries_attributes = get_param(:dialog_ldap_entries_attributes)
  $evm.log(:info, "ldap_entries_attributes => #{ldap_entries_attributes}") if @DEBUG
  
  # if no ldap entry attributes to pull attribute values from then just exit until filled
  # else create the dialog field
  if ldap_entries_attributes.blank?
    $evm.log(:info, "exiting since ldap_entries_attributes is currenlty blank")
    exit MIQ_OK
  else
    ldap_entries_attributes = YAML.load(ldap_entries_attributes)
    
    if ldap_entries_attributes.length == 1
      dialog_field_value = ldap_entries_attributes[0][ldap_entry_attribute_name.to_sym]
      $evm.log(:info, "pre mutation: dialog_field_value => #{dialog_field_value}") if @DEBUG
      
      if !dialog_field_value.blank?
        # if value regex given then select only the values matching the given regex
        if !ldap_entry_attribute_value_regex.blank?
          dialog_field_value = dialog_field_value.map { |value| value =~ /#{ldap_entry_attribute_value_regex}/i; $1 if $1 }.compact
          $evm.log(:info, "post regex map: dialog_field_value => #{dialog_field_value}") if @DEBUG
        end
        
        if dialog_field_value.length == 1
          dialog_field_value = dialog_field_value[0]
        else
          dialog_field_value = dialog_field_value.join("\n")
        end
      else
        dialog_field_value = ''
      end
    else
      dialog_field_value = ''
    end
  end
  $evm.log(:info, "post mutation: dialog_field_value => #{dialog_field_value}") if @DEBUG
  
  additional_options = get_param(:additional_options)
  $evm.log(:info, "additional_options => #{additional_options}") if @DEBUG
  
  # if no additional options then just create a single value dialog field
  # else create a multiple value dialog field
  if additional_options.blank?
    dialog_field              = $evm.object
    dialog_field["data_type"] = "string"
    dialog_field["value"]     = dialog_field_value
    
    $evm.log(:info, "dialog_field['value'] => #{dialog_field['value']}") if @DEBUG
  else
    values = additional_options.dup
    values[dialog_field_value] = dialog_field_value
    
    dialog_field                  = $evm.object
    dialog_field["data_type"]     = "string"
    dialog_field["values"]        = values
    dialog_field["default_value"] = dialog_field_value
    
    $evm.log(:info, "dialog_field['values'] => #{dialog_field['values']}") if @DEBUG
  end
end
