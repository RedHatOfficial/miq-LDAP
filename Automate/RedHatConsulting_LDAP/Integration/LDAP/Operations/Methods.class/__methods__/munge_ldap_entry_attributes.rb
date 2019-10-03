# Determine the set of LDAP entry attributes to set on the LDAP entry.
# This can be done with a combination of attributes from the existing LDAP entry,
# information about the VM from CloudForms, user input, or any other source of information the implmentor chooses.
#
# IMPLEMENTERS: Intended to be overriden by implementers.
#
# EXPECTED
#   EVM STATE || EVM CURRENT || EVM OBJECT || EVM ROOT || $evm.root['miq_provision']
#     vm - VM the new LDAP entry is for.
#
#   EVM STATE || EVM CURRENT || EVM OBJECT || EVM ROOT
#     ldap_entries - Array of existing LDAP entries with existing LDAP entry attributes
#
# SETS
#   EVM OBJECT
#     'ldap_entry_attributes' - Hash of LDAP attributes to set on the LDAP entry for the given VM.
#

require 'rubygems'
require 'net/ldap'
require 'json'


# / Integration / LDAP / Operations / Methods / munge_ldap_entry_attributes
module RedHatConsulting_LDAP
  module Integration
    module LDAP
      module Operations
        module Methods
          class MungeLDAPEntryAttributes

            include RedHatConsulting_Utilities::StdLib::Core

            # IMPLEMENTERS: DO NOT MODIFY
            #
            # return munged LDAP entry attributes
            def initialize(handle = $evm)
              @handle = handle
              @DEBUG  = false
            end

            def main
              begin
                dump_root() if @DEBUG

                ldap_entry_attributes = {}

                #If retiring else if provisioning or updating
                if @handle.root['vmdb_object_type'] == 'vm_retire_task' or ( @handle.root['vmdb_object_type'] == 'vm' and @handle.root['event_type'] == 'request_vm_retire' )
                  # IMPLIMENTORS: Modify as necessary
                  # Use this section to define any LDAP modifications that should occur on retirement
                  #
                  #ldap_entry_attributes['sample_key'] = 'sample_value'
                else
                  # Depending on the vmdb_object_type get the required information from different sources
                  #   * get the VM to get the LDAP entry attributes for and
                  #   * get the service dialog attributes associated with that VM
                  vm, dialog_attributes = get_vm_and_options
                  error("vm parameter not found")      if vm.blank?
                  error("dialog attributes not found") if dialog_attributes.blank?

                  dialog_attributes = dialog_attributes.symbolize_keys
                  log(:info, "vm => #{vm.name}")                          if @DEBUG
                  log(:info, "dialog_attributes => #{dialog_attributes}") if @DEBUG

                  # IMPLIMENTORS: Modify as necessary
                  #               Additional parameters verification

                  # get the existing LDAP entries for the given VM
                  ldap_entries = get_param(:ldap_entries)
                  error("ldap_entries parameter not found") if ldap_entries.blank?

                  # narrow down to a single LDAP entry in the off chance there is more then one
                  error("More then one existing LDAP_entry for VM (#{vm.name}) was found, unsure how to handle this case.") if ldap_entries.length > 1
                  ldap_entry = ldap_entries[0]
                  log(:info, "ldap_entry => #{ldap_entry}") if @DEBUG

                  # IMPLEMENTERS: Modify as necessary
                  #               This implementation returns the existing LDAP entry attributes without modification
                  #
                  ldap_entry_attributes = {}
                  ldap_entry.each do |ldap_attribute, ldap_attribute_values|
                    ldap_entry_attributes[ldap_attribute.to_sym] = ldap_attribute_values
                    log(:info, "Set LDAP entry attribute to existing value: { ldap_attribute => #{ldap_attribute}, ldap_attribute_values => #{ldap_attribute_values} }") if @DEBUG
                  end
                  log(:info, "after merging in existing LDAP entry attributes: ldap_entry_attributes => #{ldap_entry_attributes}") if @DEBUG

                  # IMPLEMENTERS: Modify as necessary
                  #               This implementation overrides any existing LDAP entry attributes with values from dialog elements with names that
                  #               start with 'dialog_ldap_entry_attribute_'.
                  #               All values are split on "\n" in case it is ment to be an array of values.
                  #
                  # for each LDAP entry attribute dialog element
                  dialog_attributes.select { |k, v| k.to_s.start_with?('dialog_ldap_entry_attribute_') }.each do |dialog_ldap_entry_attribute, dialog_ldap_entry_attribute_value|
                    log(:info, "LDAP entry attribute dialog element: { dialog_ldap_entry_attribute => #{dialog_ldap_entry_attribute}, dialog_ldap_entry_attribute_value => #{dialog_ldap_entry_attribute_value} }") if @DEBUG
                    dialog_ldap_entry_attribute_name = dialog_ldap_entry_attribute.to_s.match(/dialog_ldap_entry_attribute_(.*)/i).captures[0]
                    ldap_entry_attributes[dialog_ldap_entry_attribute_name] = dialog_ldap_entry_attribute_value.split("\n")
                    log(:info, "Set LDAP entry attribute to value from dialog: { ldap_attribute => #{dialog_ldap_entry_attribute_name}, ldap_attribute_values => #{ldap_entry_attributes[dialog_ldap_entry_attribute_name]} }") if @DEBUG
                  end
                end

                # IMPLEMENTERS: DO NOT MODIFY
                #
                # return munged LDAP entry attributes
                @handle.object['ldap_entry_attributes'] = ldap_entry_attributes
                log(:info, "$evm.object['ldap_entry_attributes'] => #{@handle.object['ldap_entry_attributes']})") if @DEBUG
              end         
            end

          end
        end
      end
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  RedHatConsulting_LDAP::Integration::LDAP::Operations::Methods::MungeLDAPEntryAttributes.new.main
end
