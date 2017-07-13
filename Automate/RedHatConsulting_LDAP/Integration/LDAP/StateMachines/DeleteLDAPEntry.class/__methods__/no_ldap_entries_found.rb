# If no LDAP entries found to delete then just continue on.
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
  # Set new result
  $evm.root['ldap_no_entries_found'] = true
  $evm.root['ae_result']             = 'continue'
  $evm.log(:info, "Set new ae_result: #{$evm.root['ae_result']}")
end
