global class TwilioMessageBodySplitter {

    @InvocableMethod(label='SplitFirstLastEmail' description='Receives a message body with the expected format firstname, lastname, email with spaces between, and returns them, split and named as such' category='Custom Apex Utility Classes')
    public static List<ConvertLeadActionResult> formatBody(List<String> bodies) {
    
        List<ConvertLeadActionResult> results = new List<ConvertLeadActionResult>(); 
        
        try{
        
        for(String s : bodies){
            
            ConvertLeadActionResult res = new ConvertLeadActionResult();
            
            String[] strings = s.split(' ');
            
            res.firstname = strings[0];
            res.lastname = strings[1];
            res.email = strings[2];
            
            if(res.firstname != null && res.lastname != null && res.email != null){
            	res.result = 'success';
            }else{
                res.result = 'failed';
            }
            results.add(res);
        }
            
        }catch(Exception ex){
            ConvertLeadActionResult res = new ConvertLeadActionResult();
            res.result = 'failed';
            
            results = new List<ConvertLeadActionResult>(); 
            results.add(res);
        }
            
        return results;
    }
    
    global class ConvertLeadActionResult {
        
        @InvocableVariable
        global string firstname;
        
        @InvocableVariable
        global string lastname;
        
        @InvocableVariable
        global string email;
        
        @InvocableVariable
        global string result;
    }
    
}