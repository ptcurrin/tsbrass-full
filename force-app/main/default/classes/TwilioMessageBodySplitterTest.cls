@isTest
public class TwilioMessageBodySplitterTest {
    
    static testmethod void shouldSucceed(){
        
        List<String> bodies = new List<String>{'Louis Armstrong louis@thesavoy.edu'};
            
            List<TwilioMessageBodySplitter.ConvertLeadActionResult> results = TwilioMessageBodySplitter.formatBody(bodies);
        
        for(TwilioMessageBodySplitter.ConvertLeadActionResult res : results){
            
            system.assertEquals('Louis', res.firstname);
            system.assertEquals('Armstrong', res.lastname);
            system.assertEquals('louis@thesavoy.edu', res.email);
            system.assertEquals('success', res.result);
        }
        
    }
    
    
    static testmethod void shouldFail(){
        
        List<String> bodies = new List<String>{'Louis louis@thesavoy.edu'};
            List<TwilioMessageBodySplitter.ConvertLeadActionResult> results;
        
        results = TwilioMessageBodySplitter.formatBody(bodies);
        
        TwilioMessageBodySplitter.ConvertLeadActionResult res = results[0];
        system.assertEquals('failed', res.result);
        
        
    }
    
}