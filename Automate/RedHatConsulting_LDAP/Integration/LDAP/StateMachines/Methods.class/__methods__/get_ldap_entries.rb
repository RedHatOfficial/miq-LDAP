# Gets all of the LDAP entries for a given VM.
#
# EXPECTED
#   EVM STATE || EVM CURRENT || EVM OBJECT || EVM ROOT || $evm.root['miq_provision']
#     vm                    - VM to get the LDAP entries for.
#                             Required if `ldap_filter_value` is not specified.
#     ldap_treebase         - LDAP treebase to search for LDAP entries.
#                             Optional. If not specified then `ldap_treebase` is used from the `Integration/LDAP/Configuration/default` configuration.
#     ldap_filter_attribute - LDAP filter attribute to search for LDAP entries with.
#                             Optional. If not specified then `ldap_hostname_filter` is used from the `Integration/LDAP/Configuration/default` configuration.
#     ldap_filter_value     - LDAP filter value to search for LDAP entries with.
#                             Required if `vm` is not specified.
#     ldap_search_scope     - LDAP search scope.
#                             Optional, defaults to 2/SearchScope_WholeSubtree.
#                             Values:
#                               0 => SearchScope_BaseObject
#                               1 => SearchScope_SingleLevel
#                               2 => SearchScope_WholeSubtree
#
# SETS
#   EVM OBJECT
#     ldap_entries - the ldap entries found for the given VM
@DEBUG = false

require 'rubygems'
require 'net/ldap'

# Gets the LDAP connection configuration information.
LDAP_CONFIG_URI = 'Integration/LDAP/Configuration/default'
def get_ldap_config()
  return $evm.instantiate(LDAP_CONFIG_URI)
end

# Get the hostname for a given VM.
#
# @return Hostname of the VM or vm.name if a hostname can not be found
def get_vm_hostname()
  # get parameters
  if $evm.root['miq_provision']
    vm = $evm.root['miq_provision'].vm
  else
    vm = get_param(:vm)
  end
  error("vm parmaeter not found") if vm.nil?
  
  hostname = vm.hardware.hostnames.first rescue nil
  hostname = vm.name if hostname.blank?
  return hostname
end

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
  # determine the LDAP connection configuration information
  ldap_config = get_ldap_config()
  error("LDAP Configuration not found") if ldap_config.nil?
  ldap_server           = ldap_config['ldap_server']
  ldap_username         = ldap_config['ldap_username']
  ldap_password         = ldap_config.decrypt('ldap_password')
  ldap_port             = ldap_config['ldap_port']
  ldap_encryption       = ldap_config['ldap_encryption']
  ldap_treebase         = get_param('ldap_treebase')         || ldap_config['ldap_treebase']
  ldap_filter_attribute = get_param('ldap_filter_attribute') || ldap_config['ldap_hostname_filter']
  ldap_filter_value     = get_param('ldap_filter_value')     || get_vm_hostname()
  ldap_search_scope     =
    case get_param('ldap_search_scope')
      when 0 || '0'
        Net::LDAP::SearchScope_BaseObject
      when 1 || '1'
        Net::LDAP::SearchScope_SingleLevel
      when 2 || '2'
        Net::LDAP::SearchScope_WholeSubtree
      else
        Net::LDAP::SearchScope_WholeSubtree
    end
  $evm.log(:info, "ldap_server           => #{ldap_server}")           if @DEBUG
  $evm.log(:info, "ldap_username         => #{ldap_username}")         if @DEBUG
  $evm.log(:info, "ldap_port             => #{ldap_port}")             if @DEBUG
  $evm.log(:info, "ldap_encryption       => #{ldap_encryption}")       if @DEBUG
  $evm.log(:info, "ldap_treebase         => #{ldap_treebase}")         if @DEBUG
  $evm.log(:info, "ldap_filter_attribute => #{ldap_filter_attribute}") if @DEBUG
  $evm.log(:info, "ldap_filter_value     => #{ldap_filter_value}")     if @DEBUG
  $evm.log(:info, "ldap_search_scope     => #{ldap_search_scope}")     if @DEBUG

  # create the LDAP connection
  ldap = Net::LDAP.new(
    :host => ldap_server,
    :port => ldap_port,
    :auth => {
      :method => :simple,
      :username => ldap_username,
      :password => ldap_password
    },
    :encryption => ldap_encryption
  )

  # if able to bind to LDAP
  # else error binding
  $evm.log(:info, "LDAP bind to #{ldap_server} as #{ldap_username}") if @DEBUG
  if ldap.bind
    $evm.log(:info, "LDAB bound to #{ldap_server} as #{ldap_username}") if @DEBUG
    
    # get the LDAP entires
    filter = Net::LDAP::Filter.eq(ldap_filter_attribute, ldap_filter_value)
    ldap_entries = ldap.search(:base => ldap_treebase, :filter => filter, :return_result => true, :scope => ldap_search_scope)
   
    # if found LDAP entries
    # else error
    if ldap_entries.size > 0
      $evm.object['ldap_entries'] = ldap_entries
      $evm.log(:info, "ldap_entries => #{ldap_entries}")
    else
      error("LDAP could not find any entries for #{ldap_filter_attribute}=#{ldap_filter_value}")
    end
  else
    error("LDAP could not bind to #{ldap_server} as #{ldap_username}")
  end
end
