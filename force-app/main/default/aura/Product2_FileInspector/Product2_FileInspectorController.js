({
	doInit: function(cmp, event, helper) {
        // Set the attribute value. 
        // You could also fire an event here instead.
        console.log("We got this");
        
        
        cmp.set('v.productsColumns', [
            { label: 'ProductCode', fieldName: 'product.ProductCode', type: 'text'}
            //,
            //{ label: 'Name', fieldName: 'product.Name', type: 'text'}
            /*
            ,
            {
                label: 'Confidence',
                fieldName: 'Confidence',
                type: 'percent',
                cellAttributes: { iconName: { fieldName: 'TrendIcon' },
                iconPosition: 'right' }
            },
            {
                label: 'Amount',
                fieldName: 'Amount',
                type: 'currency',
                typeAttributes: { currencyCode: 'EUR'}
            },
            { label: 'Contact Email', fieldName: 'Contact', type: 'email'},
            { label: 'Contact Phone', fieldName: 'Phone', type: 'phone'}
            */
        ]);
        
        
        
        
        
        
        helper.apexGetProducts(cmp, event, helper);
        
        
        
    }
})