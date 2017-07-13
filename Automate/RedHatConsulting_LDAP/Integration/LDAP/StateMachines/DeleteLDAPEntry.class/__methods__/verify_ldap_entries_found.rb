# Verify if there are any LDAP entries found. If not skip the current state.
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

begin
  if $evm.root['ldap_no_entries_found']
    $evm.root['ae_result'] = 'skip'
    $evm.create_notification(:level => 'warning', :message => "No LDAP entries found to delete for VM [#{$evm.root['vm'].name}]")
    $evm.log(:info, "Set new ae_result: #{$evm.root['ae_result']}")
  end
end
