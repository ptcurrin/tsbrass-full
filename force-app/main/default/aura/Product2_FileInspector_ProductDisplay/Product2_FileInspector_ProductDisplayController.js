({
	doInit : function(component, event, helper) {
		
        var wrapper = component.get("v.wrapper");
        
        console.log("Product: " + JSON.stringify(wrapper, null, 2));
        
    },
    
    
    /*
    goToURL : function (component, event, helper) {
        
        var urlEvent = $A.get("e.force:navigateToURL");
        
        urlEvent.setParams({
            "url": "/"
        });
        urlEvent.fire();
    }*/
})