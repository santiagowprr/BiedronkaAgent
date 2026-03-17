import { LightningElement, api, wire, track } from 'lwc';
import getRelatedAccounts from '@salesforce/apex/AccountDomainMatcherController.getRelatedAccountsByDomain';

const COLUMNS = [
    { label: 'Account Name', fieldName: 'Name' },
    { label: 'Industry', fieldName: 'Industry' },
    { label: 'Owner', fieldName: 'OwnerName' }
];

export default class AccountDomainMatcher extends LightningElement {
    @api recordId;
    @track accounts = [];
    @track columns = COLUMNS;
    isLoading = true;

    @wire(getRelatedAccounts, { currentAccountId: '$recordId' })
    wiredAccounts({ error, data }) {
        this.isLoading = false;
        if (data) {
            // Flattening data for the table
            this.accounts = data.map(record => ({
                ...record,
                OwnerName: record.Owner ? record.Owner.Name : ''
            }));
        } else if (error) {
            console.error('Error:', error);
        }
    }

    get hasData() {
        return this.accounts && this.accounts.length > 0;
    }
}