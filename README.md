# miq-LDAP
ManageIQ Automate Domain for reading and writing information from and to LDAP.

# Table of Contents
* [miq-LDAP](#miq-ldap)
* [Table of Contents](#table-of-contents)
* [Features](#features)
* [Dependencies](#dependencies)
  * [Other Datastores](#other-datastores)
* [Automate](#automate)
  * [Override](#override)
  * [Requests](#requests)
  * [State Machines](#state-machines)
  * [Dynamic Dialogs](#dynamic-dialogs)
* [Install](#install)
* [Contributors](#contributors)

# Features
The high level features of this ManageIQ extension.

* Create LDAP entry for a VM
* Delete LDAP entry for a VM
* Update LDAP entry attributes for a VM from a dialog
* Update VM tags and custom attributes based on LDAP entry attributes
* Dynamic dialog methods for populating fields with existing LDAP entry attribute values

# Dependencies
Dependencies of this ManageIQ extensions.

## Other Datastores
These ManageIQ atuomate domains must also be installed for this datastore to function.

* [RedHatConsulting_Utilities](https://github.com/rhtconsulting/miq-Utilities)

# Automate
Information on the provided Automate.

## Override
These are the methods intended to be overriden by implimentors of this domain for providing business logic and configuration.

### Configuration
Full Path: `LDAP/Integration/LDAP/Configuration/default`
Required to Override: **Yes**

### get_ldap_new_entry_attributes
Full Path: `LDAP/Integration/LDAP/Operations/Methods/get_ldap_new_entry_attributes`
Required to Override: **Maybe**
  * If want to create new LDAP entries
  * If not using IdM as LDAP provider

### get_vm_tags_and_attributes_from_ldap_entry
Full Path: `LDAP/Integration/LDAP/Operations/Methods/get_ldap_new_entry_attributes`
Required to Override: **Maybe**
  * If want to update VM tags and custom attributes form LDAP entries

### munge_ldap_entry_attributes
Full Path: `LDAP/Integration/LDAP/Operations/Methods/get_ldap_new_entry_attributes`
Required to Override: **Maybe**
  * If want to update LDAP entriy attributes based on user imput to dialogs.

## Requests
Information on the provided Request entry points.

### delete_ldap_entry
See [DeleteLDAPEntry](#deleteldapentry) state machine.

### update_ldap_entry_attributes
See [UpdateLDAPEntryAttributes](#updateldapentryattributes) state machine.

### update_multiple_vms_tags_and_custom_attributes_from_ldap_entries
See [UpdateMultipleVMsTagsAndCustomAttributesFromLDAPEntries](#updatemultiplevmstagsandcustomattributesfromldapentries) state machine.

### update_vm_tags_and_custom_attributes_based_on_ldap_entries
See [UpdateVMTagsAndCustomAttributesFromLDAPEntries](#updatevmtagsandcustomattributesfromldapentries) state machine.

## State Machines
Information on the provided State machines.

### DeleteLDAPEntry
Deletes an existing LDAP entry for the given VM.

### UpdateLDAPEntryAttributes
Updates the LDAP entry attributes for a given VM by munging the existing LDAP entry attributes with values from dialog fields prefixed with `ldap_entry_attribute_`. If an LDAP entry does not already exist for the given VM then one will be created.

### UpdateMultipleVMsTagsAndCustomAttributesFromLDAPEntries
Updates the tags and custom attributes on a collection of VMs using the LDAP entry attributes for each VM.

For this to work `/LDAP/Integration/LDAP/Operations/Methods/get_vm_tags_and_attributes_from_ldap_entry` must be overwritten with the specifc business logic on which LDAP entry attributes should be syncronized to which VM tags and/or custom attributes.

### UpdateVMTagsAndCustomAttributesFromLDAPEntries
Updates the tlags and custom attributes on a VM using the LDAP entry attributes for that VM.

For this to work `/LDAP/Integration/LDAP/Operations/Methods/get_vm_tags_and_attributes_from_ldap_entry` must be overwritten with the specifc business logic on which LDAP entry attributes should be syncronized to which VM tags and/or custom attributes.

## Dynamic Dialogs
Information on methods provided for use with dynamic dialogs.

### Method: get_ldap_entries_attributes
Gets the current LDAP entry attributes from the given LDAP entries and converts them to YAML for use by other dialog elements.

The purpose of this is to make it so other dialog elements do not need to each find the LDAP entries and can instead reference this YAML stored in a helper hidden dialog element.

See [Instance: get_ldap_entries_attributes](#instance-get_ldap_entries_attributes).

### Method: get_ldap_entry_attribute
Gets the value for the given LDAP entry attribute.

This method depends on the [get_ldap_entries_attributes](#method-get_ldap_entries_attributes) method to be setting the `dialog_ldap_entries_attributes` field with a YAML value of all of the existing LDAP entry attributes to avoid having to query LDAP for the entries for mutliple dialog fields all relying on information from that entry.

### Instance: get_ldap_entries_attributes
A hidden dialog field text area should be configured with the name `ldap_entries_attributes` that calls the this instance  so that the [get_ldap_entry_attribute](#method-get_ldap_entry_attribute) method can reference the output rather then having to make multiple LDAP calls.

### Instance: get_ldap_entry_attribute_description
An example instance to show how to create a dynamic dialog field that is populated with the existing LDAP entry `description` attribute value for a given VM.

Requires that the dialog also has a hidden field that calls the [get_ldap_entries_attributes](#instance-get_ldap_entries_attributes) instance.

# Install
0. Install dependencies
1. Automate -> Import/Export
2. Import Datastore via git
3. Git URL: `https://github.com/rhtconsulting/miq-LDAP.git`
4. Submit
5. Select Branc/Tag to syncronize with
6. Submit
