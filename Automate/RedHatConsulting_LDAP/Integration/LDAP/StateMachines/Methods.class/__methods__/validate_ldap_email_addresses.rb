# Validates that there is an LDAP entry for each given E-Maill address and then returns which
# given E-Mail addresses are valid and which are not.
#
# EVM STATE || EVM CURRENT || EVM OBJECT || EVM ROOT
#   email_addresses       - E-Mail addresses to validate that there is an assoicated LDAP entry for
#   ldap_treebase         - LDAP treebase to search for LDAP entries.
#   ldap_filter_attribute - LDAP filter attribute to search for LDAP entries with.
#
# SETS
#   EVM OBJECT
#     valid_ldap_emails   - E-Mail addresses that have an associated LDAP entry
#     invalid_ldap_emails - E-Mail addresses that do not have an associated LDAP entry
#
@DEBUG = false

require 'rubygems'
require 'net/ldap'

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

# Gets all of the Tags in a given Tag Category
#
# @param category Tag Category to get all of the Tags for
#
# @return Hash of Tag names mapped to Tag descriptions
#
# @source https://pemcg.gitbooks.io/mastering-automation-in-cloudforms-4-2-and-manage/content/using_tags_from_automate/chapter.html#_getting_the_list_of_tags_in_a_category
def get_category_tags(category)
  classification = $evm.vmdb(:classification).find_by_name(category)
  tags = {}
  $evm.vmdb(:classification).where(:parent_id => classification.id).each do |tag|
    tags[tag.name] = tag.description
  end

  return tags
end

# Create a Tag in a given Category if it does not already exist
#
# @param category Tag Category to create the Tag in
# @param tag      Tag to create in the given Tag Category
#
# @source https://pemcg.gitbooks.io/mastering-automation-in-cloudforms-4-2-and-manage/content/using_tags_from_automate/chapter.html
def create_tag(category, tag)
  create_tag_category(category)
  tag_name = to_tag_name(tag)
  unless $evm.execute('tag_exists?', category, tag_name)
    $evm.execute('tag_create',
                 category,
                 :name => tag_name,
                 :description => tag)
  end
end

# Create a Tag  Category if it does not already exist
#
# @param category     Tag Category to create
# @param description  Tag Category description.
#                     Optional
#                     Defaults to the `category`
# @param single_value True if a resource can only have one tag from this category,
#                     False if a resource can have multiple tags from this category.
#                     Optional.
#                     Defaults to `false`
#
# @source https://pemcg.gitbooks.io/mastering-automation-in-cloudforms-4-2-and-manage/content/using_tags_from_automate/chapter.html
def create_tag_category(category, description = nil, single_value = false)
  category_name = to_tag_name(category)
  unless $evm.execute('category_exists?', category_name)
    $evm.execute('category_create',
                 :name => category_name,
                 :single_value => single_value,
                 :perf_by_tag => false,
                 :description => description || category)
  end
end

# Takes a string and makes it a valid tag name
#
# @param str String to turn into a valid Tag name
#
# @return Given string transformed into a valid Tag name
def to_tag_name(str)
  return str.downcase.gsub(/[^a-z0-9_]+/,'_')
end

# Validates that there is an LDAP entry for a given treebase, attribute, and attribute value.
#
# @param ldap_treebase         Search this treebase for LDAP entires with the given LDAP attribute value
# @param ldap_filter_attribute Search for LDAP entry with this LDAP attribute with the given `ldap_filter_value`
# @param ldap_filter_value     Find LDAP entry with this LDAP attribute value
#
# @return true if there is an LDAP entry for the given LDAP entry value, false otherwise
def validate_ldap_entry_exists_for_ldap_attribute_value(ldap_treebase, ldap_filter_attribute, ldap_filter_value)
	valid_email_category_name = "valid_emails"

  #If we have already validated this email address, we assume it is still valid
  #Else validate using LDAP and cache result if valid
  if $evm.execute('tag_exists?', valid_email_category_name, to_tag_name(ldap_filter_value))
    return true
  else
    $evm.log(:info, "ldap_filter_value => #{ldap_filter_value}") if @DEBUG
 
    # set instantiate paramaters
    $evm.root[:ldap_treebase]         = ldap_treebase
    $evm.root[:ldap_filter_attribute] = ldap_filter_attribute
    $evm.root[:ldap_filter_value]     = ldap_filter_value

    # instantiate
    begin
      $evm.instantiate('/Integration/LDAP/StateMachines/GetLDAPEntries/Default')
    ensure
      # cleanup root
      $evm.root['ae_result']            = nil
      $evm.root['ae_reason']            = nil
 
      $evm.root[:ldap_treebase]         = nil
      $evm.root[:ldap_filter_attribute] = nil
      $evm.root[:ldap_filter_value]     = nil
    end

    # get results
    ldap_entries = get_param('ldap_entries')
    $evm.log(:info, "ldap_entries => #{ldap_entries}") if @DEBUG
 
    is_valid = ldap_entries && !ldap_entries.empty?
    if is_valid
      create_tag(valid_email_category_name, ldap_filter_value)
    end

    return is_valid
  end
end

begin
  # get params
  email_addresses       = get_param(:email_addresses)
  ldap_treebase         = get_param(:ldap_treebase)
  ldap_filter_attribute = get_param(:ldap_filter_attribute)
  error('email_addresses parameter not found')       if email_addresses.blank?
  error('ldap_treebase parameter not found')         if ldap_treebase.blank?
  error('ldap_filter_attribute parameter not found') if ldap_filter_attribute.blank?
  $evm.log(:info, "email_addresses       => #{email_addresses}")       if @DEBUG
  $evm.log(:info, "ldap_treebase         => #{ldap_treebase}")         if @DEBUG
  $evm.log(:info, "ldap_filter_attribute => #{ldap_filter_attribute}") if @DEBUG
  
  # validate each email
  valid_ldap_emails   = []
  invalid_ldap_emails = []
  
  email_addresses.each do |email|
    valid = validate_ldap_entry_exists_for_ldap_attribute_value(ldap_treebase, ldap_filter_attribute, email)
    
    if valid
      valid_ldap_emails.push(email)
    else
      invalid_ldap_emails.push(email)
    end
  end

  # record valid and invalid emails
  $evm.object['valid_ldap_emails']   = valid_ldap_emails
  $evm.object['invalid_ldap_emails'] = invalid_ldap_emails
  
  $evm.log(:info, "valid_ldap_emails => #{valid_ldap_emails}")     if @DEBUG
  $evm.log(:info, "invalid_ldap_emails => #{invalid_ldap_emails}") if @DEBUG
end
