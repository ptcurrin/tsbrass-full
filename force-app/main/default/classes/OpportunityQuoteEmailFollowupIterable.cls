public class OpportunityQuoteEmailFollowupIterable implements Iterable<Opportunity>{

    public Id testOppId {get;set;}
    
    public OpportunityQuoteEmailFollowupIterable(){}
    
    public OpportunityQuoteEmailFollowupIterable(String testOppId){
        this.testOppId = testOppId;
    }
    
    public Iterator<Opportunity> iterator(){
        
        Date tdy = Date.today();
        List<Opportunity> opps; 
        if(this.testOppId == null){    
            opps = [SELECT Id,
                    Name,
                    StageName,
                    Quote_Email_Initial_Send_Date__c,
                    Quote_Email_Followup_Interval_Days__c, 
                    RecordTypeId,
                    RecordType.Name
                    FROM Opportunity 
                    WHERE RecordType.DeveloperName = 'MEA_Projects' 
                    AND Quote_Email_Next_Followup_Date__c = :tdy
                    AND StageName = 'Follow-Up'];
        }else{
            opps = [SELECT Id,
                    Name,
                    StageName,
                    Quote_Email_Initial_Send_Date__c,
                    Quote_Email_Followup_Interval_Days__c, 
                    RecordTypeId,
                    RecordType.Name
                    FROM Opportunity 
                    WHERE RecordType.DeveloperName = 'MEA_Projects' 
                    AND Quote_Email_Next_Followup_Date__c = :tdy
                    AND StageName = 'Follow-Up'
                    AND Id = :testOppId
                   ];
        
        }
        
        system.debug('OpportunityQuoteEmailFollowupIterable RUN > ' + opps);
        
        if(!opps.isEmpty()){
            system.debug('OpportunityQuoteEmailFollowupIterable opps found: ' + opps.size());
        }else{
            system.debug('opps is empty');
        }
        for(Opportunity opp : opps){
            
            system.debug(opp);
            
            
        }
        
        
        
        
        return new OpportunityIterator(opps);
           
    }
    
}