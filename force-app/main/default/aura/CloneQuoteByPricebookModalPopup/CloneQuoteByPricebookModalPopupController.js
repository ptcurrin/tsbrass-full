({
    init : function (cmp) {
        
        var recordId = cmp.get("v.recordId");
        
        console.log('recordId: ' + recordId);
        
        var flow = cmp.find("flowData");
        
        var inputVariables = [
            {
                name : 'recordId',
                type : 'String',
                value : recordId
            }
        ];
        
        flow.startFlow("Clone_Quote_By_Pricebook", inputVariables);
    }
})