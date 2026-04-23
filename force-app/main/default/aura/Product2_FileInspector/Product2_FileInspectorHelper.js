({
	apexGetProducts : function(cmp, event, helper) {
		
        console.log("apexGetProducts");
        
        var action = cmp.get("c.getProducts");
        action.setParams({ isActive : true });

        // Create a callback that is executed after 
        // the server-side action returns
        action.setCallback(this, function(response) {
            var state = response.getState();
            if (state === "SUCCESS") {
                // Alert the user with the value returned 
                // from the server
                //alert("From server: " + response.getReturnValue());

                console.log("apexGetProducts Success... ");
                
                cmp.set("v.productsList", response.getReturnValue());
                
                
                var prodsForPush = cmp.get("v.productsList");
                
                // You would typically fire a event here to trigger 
                // client-side notification that the server-side 
                // action is complete
                
                var prodTree = [];
                
                for(var i = 0; i < prodsForPush.length; i++){
                    console.log(i);
                    
                    var limb = prodsForPush[i];
                    //console.log(JSON.stringify(limb, null, 2));
                    prodTree.push(limb);
                }
                
                console.log("prodTree.length: " + prodTree.length);
                /*
                console.log(JSON.stringify(prodTree, null, 2));
                */
                
                
            }
            else if (state === "INCOMPLETE") {
                // do something
                console.log("apexGetProducts INCOMPLETE");
            }
            else if (state === "ERROR") {
                
                console.log("apexGetProducts ERROR ... ");
                
                var errors = response.getError();
                if (errors) {
                    if (errors[0] && errors[0].message) {
                        console.log("Error message: " + 
                                 errors[0].message);
                    }
                } else {
                    console.log("Unknown error");
                }
            }
        });
        $A.enqueueAction(action);
        
	}
})