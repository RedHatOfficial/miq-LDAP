# Gets the minimum LDAP attributes to set for creation of a new LDAP entry.
#
# NOTE: Intended to be overriden by implimentors.
#
# EXPECTED
#   EVM STATE || EVM CURRENT || EVM OBJECT || EVM ROOT || $evm.root['miq_provision']
#     vm - VM the new LDAP entry is for.
#
# SETS
#   EVM OBJECT
#     'ldap_new_entry_attributes' - Array of LDAP attributes to set on the new LDAP entry for the given VM.
#     'ldap_new_entry_dn'         - The DN of the new LDAP entry to create for the given VM.
@DEBUG = false

# IMPLIMENTORS: Update with business logic
#
# Given a VM hostname returns the base attributes required to add a new LDAP entry for that host.
#
# @param vm_hostname Hostname of the VM to get the new LDAP entry attributes for
# @param vm          VM to get the new LDAP entry attributes for
# @param ldap_config LDAP configuration information
#
# @return Hash of LDAP attributes to use to create a new LDAP entry for the given VM hostname
def get_ldap_new_entry_attributes(vm_hostname, vm, ldap_config)
  
  # IMPLIMENTORS: Change as necisary.
  #               This reference works with Red Hat IdM / FreeIPA.
  #
  krb_principal_domain_name = ldap_config['krb_principal_domain_name']
  $evm.log(:info, "krb_principal_domain_name=#{krb_principal_domain_name}") if @DEBUG
  return {
    :cn               => vm_hostname,
    :fqdn             => vm_hostname,
    :objectclass      => ['ipaobject', 'ieee802device', 'nshost', 'ipaservice', 'pkiuser', 'ipahost', 'krbprincipal', 'krbprincipalaux', 'ipasshhost', 'top', 'ipaSshGroupOfPubKeys'],
    :krbPrincipalName => "host/#{vm_hostname}@#{krb_principal_domain_name}",
    :ipaUniqueID      => 'autogenerate'
  }
end

# IMPLIMENTORS: Update with business logic
#
# Returns the DN for a new LDAP entry for the given VM hostname.
#
# @param vm_hostname Hostname of VM to create the DN for the new LDAP entry
# @param ldap_config LDAP configuration information
#
# @return Full DN for a new LDAP entry for the given VM hostname
def get_ldap_new_entry_dn(vm_hostname, ldap_config)
  
  # IMPLIMENTORS: Change as necisary.
  #               This reference works with Red Hat IdM / FreeIPA.
  #
  ldap_treebase = ldap_config['ldap_treebase']
  ldap_hostname_filter = ldap_config['ldap_hostname_filter']
  $evm.log(:info, "ldap_treebase=#{ldap_treebase}")               if @DEBUG
  $evm.log(:info, "ldap_hostname_filter=#{ldap_hostname_filter}") if @DEBUG
  
  ldap_new_entry_dn = "#{ldap_hostname_filter}=#{vm_hostname},#{ldap_treebase}"
  
  return ldap_new_entry_dn
end

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

# IMPLIMENTORS: DO NOT MODIFY
#
# Gets the LDAP connection configuration information.
LDAP_CONFIG_URI = 'Integration/LDAP/Configuration/default'
def get_ldap_config()
  return $evm.instantiate(LDAP_CONFIG_URI)
end

# IMPLIMENTORS: DO NOT MODIFY
#
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

# IMPLIMENTORS: DO NOT MODIFY
begin
  # IMPLIMENTORS: DO NOT MODIFY
  #
  # get the parameters
  if $evm.root['miq_provision']
    $evm.log(:info, "Get VM from $evm.root['miq_provision']") if @DEBUG
    vm = $evm.root['miq_provision'].vm
  else
    $evm.log(:info, "Get VM from paramater") if @DEBUG
    vm = get_param(:vm)
  end
  error("vm parameter not found") if vm.nil?
  $evm.log(:info, "vm=#{vm.name}") if @DEBUG
  
  # IMPLIMENTORS: DO NOT MODIFY
  #
  # determine LDAP treebase and hostname filter
  ldap_config = get_ldap_config()
  error("LDAP Configuration not found") if ldap_config.nil?
  
  # IMPLIMENTORS: DO NOT MODIFY
  #
  # determine the VM hostname
  vm_hostname = get_vm_hostname(vm)
  $evm.log(:info, "vm_hostname='#{vm_hostname}'") if @DEBUG
  
  # IMPLIMENTORS: DO NOT MODIFY
  #
  # get information about the new LDAP entry
  ldap_new_entry_attributes = get_ldap_new_entry_attributes(vm_hostname, vm, ldap_config)
  ldap_new_entry_dn         = get_ldap_new_entry_dn(vm_hostname, ldap_config)
  
  # IMPLIMENTORS: DO NOT MODIFY
  #
  # return new LDAP entry attributes
  $evm.object['ldap_new_entry_attributes'] = ldap_new_entry_attributes
  $evm.log(:info, "$evm.object['ldap_new_entry_attributes']=#{$evm.object['ldap_new_entry_attributes']})") if @DEBUG
  
  # IMPLIMENTORS: DO NOT MODIFY
  #
  # return new LDAP entry DN
  $evm.object['ldap_new_entry_dn'] = ldap_new_entry_dn
  $evm.log(:info, "$evm.object['ldap_new_entry_dn']=#{$evm.object['ldap_new_entry_dn']})") if @DEBUG
end
