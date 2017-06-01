# Adds an LDAP entry for a given VM.
#
# EXPECTED
#   EVM STATE || EVM CURRENT || EVM OBJECT || EVM ROOT || $evm.root['miq_provision']
#     vm - VM to add the LDAP entry for
#
#   EVM STATE || EVM CURRENT || EVM OBJECT || EVM ROOT
#     'ldap_new_entry_attributes' - Attributes to set on the new LDAP entry
#     'ldap_new_entry_dn'         - DN of new LDAP entry
#
# SETS
#   EVM OBJECT
#     ldap_entries - Array with the LDAP entry created for the given VM
@DEBUG = false

require 'rubygems'
require 'net/ldap'

# Gets the LDAP connection configuration information.
LDAP_CONFIG_URI = 'Integration/LDAP/Configuration/default'
def get_ldap_config()
  return $evm.instantiate(LDAP_CONFIG_URI)
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

  $evm.log(:info, "{ '#{param}' => '#{param_value}' }") if @DEBUG
  return param_value
end

# Get the hostname for a given VM.
#
# @param vm VM to get the hostname for
#
# @return Hostname of the VM or vm.name if a hostname can not be found
def get_vm_hostname(vm)
  hostname = vm.hardware.hostnames.first rescue nil
  hostname = vm.name if hostname.blank?
  return hostname
end

begin
  # get parameters
  if $evm.root['miq_provision']
    vm = $evm.root['miq_provision'].vm
  else
    vm = get_param(:vm)
  end
  error("vm parmaeter not found") if vm.nil?
  
  ldap_new_entry_attributes = get_param(:ldap_new_entry_attributes)
  error('ldap_new_entry_attributes parameter not found') if ldap_new_entry_attributes.nil?
  
  ldap_new_entry_dn = get_param(:ldap_new_entry_dn)
  error('ldap_new_entry_dn parameter not found') if ldap_new_entry_dn.nil?
  
  # determine the LDAP connection configuration information
  ldap_config = get_ldap_config()
  error("LDAP Configuration not found") if ldap_config.nil?
  ldap_server          = ldap_config['ldap_server']
  ldap_username        = ldap_config['ldap_username']
  ldap_password        = ldap_config.decrypt('ldap_password')
  ldap_port            = ldap_config['ldap_port']
  ldap_encryption      = ldap_config['ldap_encryption']
  ldap_treebase        = ldap_config['ldap_treebase']
  ldap_hostname_filter = ldap_config['ldap_hostname_filter']
  $evm.log(:info, "ldap_server=#{ldap_server}")                   if @DEBUG
  $evm.log(:info, "ldap_username=#{ldap_username}")               if @DEBUG
  $evm.log(:info, "ldap_port=#{ldap_port}")                       if @DEBUG
  $evm.log(:info, "ldap_encryption=#{ldap_encryption}")           if @DEBUG
  $evm.log(:info, "ldap_treebase=#{ldap_treebase}")               if @DEBUG
  $evm.log(:info, "ldap_hostname_filter=#{ldap_hostname_filter}") if @DEBUG

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
    $evm.log(:info, "LDAP bound to #{ldap_server} as #{ldap_username}") if @DEBUG
    
    # add the new LDAP entry
    add_success = ldap.add( :dn => ldap_new_entry_dn, :attributes => ldap_new_entry_attributes )
    $evm.log(:info, "LDAP added entry: { :dn => #{ldap_new_entry_dn}, :attributes => #{ldap_new_entry_attributes}, add_success => #{add_success} }") if @DEBUG
    
    # if succesfully added new entry, get that entry and "return it" by setting it on $evm.object
    if add_success
      # determine the VM hostname
      vm_hostname = get_vm_hostname(vm)
      $evm.log(:info, "vm_hostname='#{vm_hostname}'") if @DEBUG
      
      filter       = Net::LDAP::Filter.eq(ldap_hostname_filter, vm_hostname)
      ldap_entries = ldap.search( :base => ldap_treebase, :filter => filter, :return_result => true )
   
      # if found new LDAP entry
      # else error
      if ldap_entries.size > 0
        $evm.object['ldap_entries'] = ldap_entries
      else
        # this should never happen...
        error("LDAP could not find the newly created entry for: { :dn => #{dn} }")
      end
    else
      error("Unable to add LDAP entry for #{dn}. This is typically either a permisisons issue or a missing required attribute issue. See LDAP server error logs for details.")
    end
  else
    error("LDAP could not bind to #{ldap_server} as #{ldap_username}")
  end
end
