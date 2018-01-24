# For every VM in a given container of VMs update the VM's Tags and Custom Attributes based on the LDAP record for that VM.
#
# EXPECTED
#   EVM ROOT
#     ext_management_system, ems_cluster, host - One of these is expected to be set as the parent of the group of VMs to update.
#
@DEBUG = false

DEFAULT_VMS_BATCH_SIZE = 10
LDAP_CONFIG_URI        = 'Integration/LDAP/Configuration/default'

# Log an error and exit.
#
# @param msg Message to error with
def error(msg)
  $evm.log(:error, msg)
  $evm.root['ae_result'] = 'error'
  $evm.root['ae_reason'] = msg.to_s
  exit MIQ_STOP
end

def dump_current
  $evm.log("info", "Listing Current Object Attributes:") 
  $evm.current.attributes.sort.each { |k, v| $evm.log("info", "\t#{k}: #{v}") }
  $evm.log("info", "===========================================") 
end

def dump_root
  $evm.log("info", "Listing Root Object Attributes:") 
  $evm.root.attributes.sort.each { |k, v| $evm.log("info", "\t#{k}: #{v}") }
  $evm.log("info", "===========================================") 
end

def dump_object(object_string, object)
  $evm.log("info", "Listing #{object_string} Attributes:") 
  object.attributes.sort.each { |k, v| $evm.log("info", "\t#{k}: #{v}") }
  $evm.log("info", "===========================================") 
end

# Gets the LDAP connection configuration information.
def get_ldap_config()
  return $evm.instantiate(LDAP_CONFIG_URI)
end

# Updates the Tags and Custom Attributes from LDAP for a batch of VMs.
#
# @param vm_ids IDs of the VMs to update the Tags and Custom Attributes for from LDAP.
def update_tags_and_custom_attributes_from_ldap_entries_for_batch_of_vms(vm_ids)
  attrs = {
    'vm_ids' => vm_ids.join(',')
  }

  options = {}
  options[:namespace]     = 'Integration/LDAP/StateMachines'
  options[:class_name]    = 'Methods'
  options[:instance_name] = 'update_tags_and_custom_attributes_from_ldap_entries_for_batch_of_vms'
  options[:user_id]       = $evm.root['user'].id
  options[:attrs]         = attrs
  approving_user = 'admin'
  auto_approve   = true

  $evm.log(:info, "Execute: #{options}") if @DEBUG
  $evm.execute('create_automation_request', options, approving_user, auto_approve)
end

begin
  # determine the VMs to update
  vmdb_object_type = $evm.root['vmdb_object_type']
  if (vmdb_object_type == 'ext_management_system') || (vmdb_object_type == 'automation_task' && !$evm.root['ext_management_system'].nil?)
    ems = $evm.root['ext_management_system']
    $evm.log(:info, "ems=#{ems.name}") if @DEBUG
    
    vms = ems.vms
  elsif (vmdb_object_type == 'ems_cluster') || (vmdb_object_type == 'automation_task' && !$evm.root['ems_cluster'].nil?)
    cluster = $evm.root['ems_cluster']
    $evm.log(:info, "cluster=#{cluster.name}") if @DEBUG
    
    vms = cluster.vms
  elsif (vmdb_object_type == 'host') || (vmdb_object_type == 'automation_task' && !$evm.root['host'].nil?)
    host = $evm.root['host']
      $evm.log(:info, "host=#{host.name}") if @DEBUG
    
      vms = host.vms
  else
    error("$evm.root['vmdb_object_type']=#{$evm.root['vmdb_object_type']} is not one of expected ['ext_management_system', 'ems_cluster', 'host','automation_task'].")
  end
  
  # determine the size of each batch of VMs to process
  ldap_config = get_ldap_config()
  vms_batch_size = ldap_config['vms_batch_size']
  vms_batch_size ||= DEFAULT_VMS_BATCH_SIZE
  
  # update the VMs in asyncronous batches
  $evm.log(:info, "VMs to Update in Batches: { vms => #{vms.collect { |vm| vm.name }} }") if @DEBUG
  vms.each_slice(vms_batch_size) do |vms_batch|
    vm_ids = vms_batch.collect { |vm| vm.id }
    update_tags_and_custom_attributes_from_ldap_entries_for_batch_of_vms(vm_ids)
  end
end
