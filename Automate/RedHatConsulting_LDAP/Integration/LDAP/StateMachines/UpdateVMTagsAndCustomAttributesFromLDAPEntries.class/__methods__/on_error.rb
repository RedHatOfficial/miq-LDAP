# This gracefully handles the case where no LDAP entry is found for the current VM.
#
# EXPECTED
#   INPUT PARAMETERS
#     message - Error message describing the error.
#
# SETS
#   OBJECT
#     :ldap_sync_status     - Will be set to the given message.
#     :ldap_sync_successful - Always False since this is an error condition.
@DEBUG = false

NEXT_STEP = 'SetLDAPSyncStatus'

begin
  # set the tags and attributes for the LDAP sync failure
  message = $evm.inputs['message']

  # Set the LDAP Sync Status
  $evm.root['ldap_sync_status']     = message
  $evm.root['ldap_sync_successful'] = false

  # Skip processing LDAP entry and go directly to setting the Tags and Attributes
  $evm.log(:info, "Skip to State: #{NEXT_STEP}") if @DEBUG
  $evm.root['ae_result']     = 'continue'
  $evm.root['ae_next_state'] = NEXT_STEP
end
