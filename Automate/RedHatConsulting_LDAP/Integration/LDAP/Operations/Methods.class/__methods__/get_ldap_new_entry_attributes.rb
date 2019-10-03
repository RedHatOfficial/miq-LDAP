# Gets the minimum LDAP attributes to set for creation of a new LDAP entry.
#
# NOTE: Intended to be overriden by implementers.
#
# EXPECTED
#   EVM STATE || EVM CURRENT || EVM OBJECT || EVM ROOT || $evm.root['miq_provision']
#     vm - VM the new LDAP entry is for.
#
# SETS
#   EVM OBJECT
#     'ldap_new_entry_attributes' - Array of LDAP attributes to set on the new LDAP entry for the given VM.
#     'ldap_new_entry_dn'         - The DN of the new LDAP entry to create for the given VM.

# / Integration / LDAP / Operations / Methods / get_ldap_new_entry_attributes
module RedHatConsulting_LDAP
  module Integration
    module LDAP
      module Operations
        module Methods
          class GetLDAPNewEntryAttributes

            include RedHatConsulting_Utilities::StdLib::Core

            # IMPLEMENTERS: DO NOT MODIFY
            def initialize(handle = $evm)
              @handle = handle
              @DEBUG = false
            end

            # IMPLEMENTERS: Update with business logic
            #
            # Given a VM hostname returns the base attributes required to add a new LDAP entry for that host.
            #
            # @param vm_hostname       Hostname of the VM to get the new LDAP entry attributes for
            # @param vm                VM to get the new LDAP entry attributes for
            # @param dialog_attributes Dialog attributes which can be used to set the base attributes,
            #                          required to create the new LDAP entry
            # @param ldap_config       LDAP configuration information
            #
            # @return Hash of LDAP attributes to use to create a new LDAP entry for the given VM hostname
            def get_ldap_new_entry_attributes(vm_hostname, vm, dialog_attributes, ldap_config)

              # IMPLEMENTERS: Change as necessary.
              #               This reference works with Red Hat IdM / FreeIPA.
              #
              krb_principal_domain_name = ldap_config['krb_principal_domain_name']
              log(:info, "krb_principal_domain_name=#{krb_principal_domain_name}") if @DEBUG
              return {
                :cn               => vm_hostname,
                :fqdn             => vm_hostname,
                :objectclass      => ['ipaobject', 'ieee802device', 'nshost', 'ipaservice', 'pkiuser', 'ipahost', 'krbprincipal', 'krbprincipalaux', 'ipasshhost', 'top', 'ipaSshGroupOfPubKeys'],
                :krbPrincipalName => "host/#{vm_hostname}@#{krb_principal_domain_name}",
                :ipaUniqueID      => 'autogenerate'
                }
            end

            # IMPLEMENTERS: Update with business logic
            #
            # Returns the DN for a new LDAP entry for the given VM hostname.
            #
            # @param vm_hostname       Hostname of VM to create the DN for the new LDAP entry
            # @param vm                VM to create the DN for the new LDAP entry
            # @param dialog_attributes Dialog attributes which can be used to create the DN for the new LDAP entry
            # @param ldap_config       LDAP configuration information
            #
            # @return Full DN for a new LDAP entry for the given VM hostname
            def get_ldap_new_entry_dn(vm_hostname, vm, dialog_attributes, ldap_config)

              # IMPLEMENTERS: Change as necessary.
              #               This reference works with Red Hat IdM / FreeIPA.
              #
              ldap_treebase = ldap_config['ldap_treebase']
              ldap_hostname_filter = ldap_config['ldap_hostname_filter']
              log(:info, "ldap_treebase=#{ldap_treebase}")               if @DEBUG
              log(:info, "ldap_hostname_filter=#{ldap_hostname_filter}") if @DEBUG

              ldap_new_entry_dn = "#{ldap_hostname_filter}=#{vm_hostname},#{ldap_treebase}"

              return ldap_new_entry_dn
            end

            def main
              begin
                # IMPLEMENTERS: DO NOT MODIFY
                #
                # get the parameters

                # get the VM to get the new LDAP entry attributes for and
                # get the service dialog attributes associated with that VM
                vm, dialog_attributes = get_vm_and_options()
                error("vm parameter not found")                              if vm.blank?
                log(:info, "vm => #{vm.name}")                          if @DEBUG
                log(:info, "dialog_attributes => #{dialog_attributes}") if @DEBUG

                # IMPLEMENTERS: DO NOT MODIFY
                #
                # determine LDAP treebase and hostname filter
                ldap_config = get_ldap_config()
                error("LDAP Configuration not found") if ldap_config.nil?

                # IMPLEMENTERS: DO NOT MODIFY
                #
                # determine the VM hostname
                vm_hostname = get_vm_hostname(vm)
                log(:info, "vm_hostname => '#{vm_hostname}'") if @DEBUG

                # IMPLEMENTERS: DO NOT MODIFY
                #
                # get information about the new LDAP entry
                ldap_new_entry_attributes = get_ldap_new_entry_attributes(vm_hostname, vm, dialog_attributes, ldap_config)
                ldap_new_entry_dn         = get_ldap_new_entry_dn(vm_hostname, vm, dialog_attributes, ldap_config)

                # IMPLEMENTERS: DO NOT MODIFY
                #
                # return new LDAP entry attributes
                @handle.object['ldap_new_entry_attributes'] = ldap_new_entry_attributes
                log(:info, "$evm.object['ldap_new_entry_attributes']=#{@handle.object['ldap_new_entry_attributes']})") if @DEBUG

                # IMPLEMENTERS: DO NOT MODIFY
                #
                # return new LDAP entry DN
                @handle.object['ldap_new_entry_dn'] = ldap_new_entry_dn
                log(:info, "$evm.object['ldap_new_entry_dn']=#{@handle.object['ldap_new_entry_dn']})") if @DEBUG
              end      
            end

            # IMPLEMENTERS: DO NOT MODIFY
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

            # IMPLEMENTERS: DO NOT MODIFY
            #
            # Gets the LDAP connection configuration information.
            LDAP_CONFIG_URI = 'Integration/LDAP/Configuration/default'
            def get_ldap_config()
              return @handle.instantiate(LDAP_CONFIG_URI)
            end

          end
        end
      end
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  RedHatConsulting_LDAP::Integration::LDAP::Operations::Methods::GetLDAPNewEntryAttributes.new.main
end
