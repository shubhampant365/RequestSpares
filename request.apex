public with sharing class ServiceAppointmentController {
    @AuraEnabled(cacheable=true)
    public static List<ProductItemWrapper> getProductItemsForWorkOrderLineItem(Id workOrderLineItemId) {
        List<ProductItemWrapper> productItemWrappers = new List<ProductItemWrapper>();
        
        try {
            // Query to get the ServiceAppointment associated with the WorkOrderLineItem
            ServiceAppointment serviceAppointment = [
                SELECT Id, Account__c 
                FROM ServiceAppointment 
                WHERE ParentRecordId = :workOrderLineItemId
                LIMIT 1
            ];
            
            if (serviceAppointment != null && serviceAppointment.Account__c != null) {
                // Query to get the AssociatedLocation using the AccountId from the ServiceAppointment
                AssociatedLocation associatedLocation = [
                    SELECT Id, LocationId, ParentRecordId 
                    FROM AssociatedLocation 
                    WHERE ParentRecordId = :serviceAppointment.Account__c
                    LIMIT 1
                ];
                
                if (associatedLocation != null && associatedLocation.LocationId != null) {
                    // Query to get the ProductItems associated with the Location
                    List<ProductItem> productItems = [
                        SELECT Id, QuantityOnHand, Product2.Name, Product2.ProductCode, Product2Id
                        FROM ProductItem 
                        WHERE LocationId = :associatedLocation.LocationId
                    ];
                    
                    // Create a list of wrapper objects to include the necessary fields
                    for (ProductItem item : productItems) {
                        productItemWrappers.add(new ProductItemWrapper(item));
                    }
                }
            }
        } catch (Exception e) {
            // Handle any exceptions here
            System.debug('An error occurred: ' + e.getMessage());
        }
        
        return productItemWrappers;
    }
    
    
    @AuraEnabled
    public static void requestProductItems(Map<Id, Decimal> requestedItems, Id recordId) {
        System.debug('Product Request--->' + requestedItems);
        System.debug('RecprrID00> ' + recordId);
        // Your logic to process the requested product items
        List<ProductRequestLineItem> productRequestLine = new List<ProductRequestLineItem>();
        System.debug('Record Id: ' + recordId);
        ProductRequest productRequestRecord = new ProductRequest();
        productRequestRecord.WorkOrderId = recordId;
        productRequestRecord.Status = 'Submitted';
        insert productRequestRecord;
        
        for(String productId : requestedItems.keySet()){
            System.debug('Redd  ' + productId);
            System.debug('Check-->  ' + requestedItems.get(productId)  );
            ProductRequestLineItem prliRecord = new ProductRequestLineItem();
            prliRecord.QuantityRequested = requestedItems.get(productId);
            prliRecord.Status = 'Submitted';
            prliRecord.Product2Id = productId;
            prliRecord.ParentId = productRequestRecord.Id;
            productRequestLine.add(prliRecord);
        }
        insert productRequestLine;
        CustomNotificationType notificationType = [SELECT Id,DeveloperName FROM CustomNotificationType WHERE DeveloperName ='Escalation_message' Limit 1];
        Messaging.CustomNotification notification = new Messaging.CustomNotification();
        notification.setTitle('Spare Requested');
        notification.setbody('Please update the spares.');
        notification.setTargetId(productRequestRecord.Id);
        notification.setNotificationTypeId(notificationType.Id);
        
        Set<String> targetIds = new Set<String>();
        targetIds.add('0055g00000EjuMKAAZ');
        
        notification.send(targetIds);
    }
    
    
    public class ProductItemWrapper {
        @AuraEnabled public Id Id { get; set; }
        @AuraEnabled public String Name { get; set; }
        @AuraEnabled public String ProductCode { get; set; }
        @AuraEnabled public Decimal QuantityOnHand { get; set; }
        @AuraEnabled public Id Product2Id { get; set; }
        
        public ProductItemWrapper(ProductItem item) {
            this.Id = item.Id;
            this.Name = item.Product2.Name;
            this.ProductCode = item.Product2.ProductCode;
            this.QuantityOnHand = item.QuantityOnHand;
            this.Product2Id = item.Product2Id;
        }
    }
}
