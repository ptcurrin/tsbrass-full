({
    invoke : function(component, event, helper) {
        // Get the record ID attribute
        var record = component.get("v.recordId");
        
        var recordRelativeAddress = '/' + record;
        
        console.log('recordRelativeAddress: ' + recordRelativeAddress);
        
        // Get the Lightning event that opens a record in a new tab
        var redirect = $A.get("e.force:navigateToURL");
        
        // Pass the record ID to the event
        redirect.setParams({
            "url": recordRelativeAddress
        });
        
        // Open the record
        redirect.fire();
        
        console.log('AFTER FIRE');
        
    }
})