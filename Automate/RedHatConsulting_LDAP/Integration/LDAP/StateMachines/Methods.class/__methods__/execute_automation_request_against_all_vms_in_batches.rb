# Collect all the VMs in a given container of VMs and execute a given automation request against batches of those VMs.
#
# EXPECTED
#   EVM INPUTS
#     automation_request_instance_name         - Automation instance name to invoke for each batch of VMs.
#
#   EVM ROOT
#     ext_management_system, ems_cluster, host - One of these is expected to be set as the parent of the group of VMs to update.
#
@DEBUG = false

require 'json'

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

# Execute a given automation request for a given batch of VMs.
#
# @param vm_ids                           IDs of the VMs to execute the automation request for.
# @param automation_request_instance_name Instance name to execute.
# @param additional_attrs                 Additional attributes to pass when executing the automation request.
def execute_automation_request_for_batch_of_vms(vm_ids, automation_request_instance_name, additional_attrs)
  attrs = {
    'vm_ids' => vm_ids.join(',')
  }
  attrs = additional_attrs.merge(attrs) if additional_attrs

  options = {}
  options[:namespace]     = 'Integration/LDAP/StateMachines'
  options[:class_name]    = 'Methods'
  options[:instance_name] = automation_request_instance_name
  options[:user_id]       = $evm.root['user'].id
  options[:attrs]         = attrs
  approving_user = 'admin'
  auto_approve   = true

  $evm.log(:info, "Execute: #{options}") if @DEBUG
  $evm.execute('create_automation_request', options, approving_user, auto_approve)
end

begin
  dump_root() if @DEBUG
  
  # determine the VMs to execute the automation request against
  vmdb_object_type = $evm.root['vmdb_object_type']
  if (vmdb_object_type == 'ext_management_system') || (vmdb_object_type == 'automation_task' && !$evm.root['ext_management_system'].nil?)
    ems = $evm.root['ext_management_system']
    $evm.log(:info, "ems => #{ems.name}") if @DEBUG
    
    vms = ems.vms
  elsif (vmdb_object_type == 'ems_cluster') || (vmdb_object_type == 'automation_task' && !$evm.root['ems_cluster'].nil?)
    cluster = $evm.root['ems_cluster']
    $evm.log(:info, "cluster => #{cluster.name}") if @DEBUG
    
    vms = cluster.vms
  elsif (vmdb_object_type == 'host') || (vmdb_object_type == 'automation_task' && !$evm.root['host'].nil?)
    host = $evm.root['host']
    $evm.log(:info, "host => #{host.name}") if @DEBUG
    
    vms = host.vms
  elsif (vmdb_object_type == 'service_reconfigure_task')
    service_reconfigure_task = $evm.root['service_reconfigure_task']
    dump_object("service_reconfigure_task", service_reconfigure_task) if @DEBUG
    
    # get the service
    service_id = service_reconfigure_task.source_id
    service = $evm.vmdb(:service).find_by_id(service_id)
    
    # get the additional otpions
    additional_attrs = {
      :options => service_reconfigure_task.options.to_json # hash wont survive all the passing through executes so turn it to json to be transformed later
    }
    
    # get the VMs
    vms = service.vms
  else
    error("$evm.root['vmdb_object_type']='#{$evm.root['vmdb_object_type']}' is not one of expected " +
          "['ext_management_system', 'ems_cluster', 'host', 'service_reconfigure_task', 'automation_task'].")
  end
  
  # get the automation request to invoke in batches
  automation_request_instance_name = $evm.inputs['automation_request_instance_name']
  error("automation_request_instance_name must be specified") if automation_request_instance_name.blank?
  $evm.log(:info, "automation_request_instance_name = #{automation_request_instance_name}") if @DEBUG
  
  # determine the size of each batch of VMs to process
  ldap_config = get_ldap_config()
  vms_batch_size = ldap_config['vms_batch_size']
  vms_batch_size ||= DEFAULT_VMS_BATCH_SIZE
  
  # update the VMs in asyncronous batches
  $evm.log(:info, "VMs to Update in Batches: { vms => #{vms.collect { |vm| vm.name }} }") if @DEBUG
  vms.each_slice(vms_batch_size) do |vms_batch|+  error("automation_request_instance_name msut be specified") if automation_request_instance_name.blank?
    vm_ids = vms_batch.collect { |vm| vm.id }
    execute_automation_request_for_batch_of_vms(vm_ids, automation_request_instance_name, additional_attrs)
  end
end
