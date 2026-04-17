/**
 * Default settings values
 */
export const KEYFIELD = 'name';

/**
 * Columns definition
 * :: valid basic version
 */
export const COLUMNS_DEFINITION_BASIC = [
    {
        type: 'text',
        fieldName: 'name',
        label: 'Account Name',
    },
    {
        type: 'phone',
        fieldName: 'phone',
        label: 'Phone Number',
    },
    {
        type: 'phone',
        fieldName: 'phone',
        label: 'Phone Number',
    },
    {
        type: 'phone',
        fieldName: 'phone',
        label: 'Phone Number',
    },
];

/**
 * Columns definition
 * :: with non-whitelisted column keys
 */
export const COLUMNS_DEFINITION_NONWHITELIST = [
    {
        type: 'text',
        fieldName: 'accountName',
        label: 'Account Name',
    },
    {
        type: 'phone',
        fieldName: 'phone',
        label: 'Phone Number',
        sortable: true,
    },
];

/**
 * Columns definition
 * :: used in examples
 */
export const EXAMPLES_COLUMNS_DEFINITION_BASIC = [
    {
        type: 'text',
        fieldName: 'name',
        label: 'Share Class',
    },
    {
        type: 'text',
        fieldName: 'fundName',
        label: 'Fund Code',
    }
];

/**
 * Sample data
 * :: used by examples
 */
export const EXAMPLES_DATA_BASIC = [
    {
        name: '123555',
        shareClass: 'Share Class 1',
        employees: 3100,
        phone: '837-555-0100',
        accountOwner: 'http://salesforce.com/fake/url/jane-doe',
        accountOwnerName: 'Jane Doe',
        billingCity: 'Phoeniz, AZ',
    },
    {
        name: '123553',
        shareClass: 'Share Class 2',
        employees: 3100,
        phone: '837-555-0100',
        accountOwner: 'http://salesforce.com/fake/url/jane-doe',
        accountOwnerName: 'Jane Doe',
        billingCity: 'Phoeniz, AZ',
    },
    {
        name: '123554',
        shareClass: 'Share Class 3',
        employees: 3100,
        phone: '837-555-0100',
        accountOwner: 'http://salesforce.com/fake/url/jane-doe',
        accountOwnerName: 'Jane Doe',
        billingCity: 'Phoeniz, AZ',
    },
    {
        name: '123556',
        shareClass: 'Share Class 4',
        employees: 3100,
        phone: '837-555-0100',
        accountOwner: 'http://salesforce.com/fake/url/jane-doe',
        accountOwnerName: 'Jane Doe',
        billingCity: 'Phoeniz, AZ',
    }
];