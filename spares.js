// file path: force-app/main/default/lwc/productItemList/productItemList.js

import { LightningElement, api, wire, track } from 'lwc';
import getProductItemsForWorkOrderLineItem from '@salesforce/apex/ServiceAppointmentController.getProductItemsForWorkOrderLineItem';
import requestProductItems from '@salesforce/apex/ServiceAppointmentController.requestProductItems';
import { refreshApex } from '@salesforce/apex';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class ProductItemList extends LightningElement {
    @api recordId;
    @track productItems = [];
    @track filteredProductItems = [];
    @track searchKey = '';
    error;

    wiredProductItemsResult;

    @wire(getProductItemsForWorkOrderLineItem, { workOrderLineItemId: '$recordId' })
    wiredProductItems(result) {
        this.wiredProductItemsResult = result;
        if (result.data) {
            this.productItems = result.data.map(item => ({ ...item, requestQuantity: 0 }));
            this.filteredProductItems = [...this.productItems];
            this.error = undefined;
        } else if (result.error) {
            this.error = result.error;
            this.productItems = undefined;
            this.filteredProductItems = undefined;
        }
    }

    handleSearch(event) {
        const searchTerm = event.target.value.toLowerCase();
        if (searchTerm) {
            this.filteredProductItems = this.productItems.filter(item =>
                item.Name.toLowerCase().includes(searchTerm)
            );
        } else {
            this.filteredProductItems = [...this.productItems];
        }
    }

    handleRequestChange(event) {
        const id = event.target.dataset.id;
        const value = event.target.value;
        this.filteredProductItems = this.filteredProductItems.map(item => {
            if (item.Id === id) {
                return { ...item, requestQuantity: value };
            }
            return item;
        });

        this.productItems = this.productItems.map(item => {
            if (item.Id === id) {
                return { ...item, requestQuantity: value };
            }
            return item;
        });
    }

    handleRequestItems() {
        let validationError = false;

        const requestedItems = this.productItems.reduce((map, item) => {
            if (item.requestQuantity > 0) {
                if (item.requestQuantity > item.QuantityOnHand) {
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Error',
                            message: `Requested quantity for ${item.Name} exceeds quantity on hand`,
                            variant: 'error',
                        })
                    );
                    validationError = true;
                } else {
                    map[item.Product2Id] = item.requestQuantity;
                }
            }
            return map;
        }, {});

        if (validationError) {
            return;
        }

        if (Object.keys(requestedItems).length === 0) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'No items requested. Please enter a quantity for at least one item.',
                    variant: 'error',
                })
            );
            return;
        }

        requestProductItems({ requestedItems, recordId: this.recordId })
            .then(() => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Product items requested successfully',
                        variant: 'success',
                    })
                );
                // Reset the input values
                this.productItems = this.productItems.map(item => ({ ...item, requestQuantity: 0 }));
                this.filteredProductItems = [...this.productItems];
            })
            .catch(error => {
                this.error = error;
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: 'An error occurred while requesting product items',
                        variant: 'error',
                    })
                );
            });
    }

    handleRefresh() {
        refreshApex(this.wiredProductItemsResult)
            .then(() => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Product items refreshed successfully',
                        variant: 'success',
                    })
                );
            })
            .catch(error => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: 'An error occurred while refreshing product items',
                        variant: 'error',
                    })
                );
                this.error = error;
            });
    }
}
