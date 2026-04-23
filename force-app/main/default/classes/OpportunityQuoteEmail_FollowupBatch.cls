global class OpportunityQuoteEmail_FollowupBatch implements System.Schedulable, Database.AllowsCallouts, Database.Stateful, Database.Batchable<Opportunity> {

    private List<OpportunityQuoteEmailBuilder> builders {get;set;}
    private List<String> resultStrings {get;set;}
    private Id testOppId {get;set;}
    
    global void execute(SchedulableContext SC){
        Database.executeBatch(new OpportunityQuoteEmail_FollowupBatch(), 1);
        
    }
    
    global OpportunityQuoteEmail_FollowupBatch(String oppId){
        this.testOppId = oppId;
    }
   
    global OpportunityQuoteEmail_FollowupBatch(){}
    
    global Iterable<Opportunity> start(Database.BatchableContext BC){
        
        resultStrings = new List<String>();
        builders = new List<OpportunityQuoteEmailBuilder>();
        
        if(this.testOppId == null){
            return new OpportunityQuoteEmailFollowupIterable();
        }else{
            return new OpportunityQuoteEmailFollowupIterable(this.testOppId);
        }
        
    }
    
    public class TooManyObjectsInScopeException extends Exception {}
    // The scope needs to run one time per email
    global void execute(Database.BatchableContext BC, List<Opportunity> oppsFound){
       
        system.debug('oppsFound(scope): ' + oppsFound);
        
        if(!oppsFound.isEmpty() && oppsFound.size() > 1){ throw new TooManyObjectsInScopeException('You cannot send but one email in a chunk of the batch. There are ' + oppsFound.size() + ' opportunities in this chunk. Please inform an administrator.'); }
        
        OpportunityQuoteEmailBuilder builder = new OpportunityQuoteEmailBuilder(oppsFound[0].Id);
        builder.send();
        
        Date tdy = Date.today();
        Date nextFollowupDate = tdy.addDays(Integer.valueOf(oppsFound[0].Quote_Email_Followup_Interval_Days__c));
        
        Opportunity oppUpdate = new Opportunity();
        oppUpdate.Id = oppsFound[0].Id;
        oppUpdate.Quote_Email_Next_Followup_Date__c = nextFollowupDate;
        oppUpdate.Quote_Email_Last_Recorded_Followup_Date__c = tdy;
        update(oppUpdate);
         
        String orgBaseUrl = Url.getOrgDomainUrl().toExternalForm();
        String reportBody = '</br>';
        reportBody += '</br>' + orgBaseUrl + '/' + builder.opp.Id + '  ...  ' + builder.opp.Name + ' - EmailSubject:' + builder.stringSubject;
        reportBody += '</br>Next Scheduled Follow-Up Email: ' + builder.opp.Quote_Email_Next_Followup_Date__c; 
        
        resultStrings.add(reportBody);
        
    }
    
    global void finish(Database.BatchableContext BC){
        
        
        String reportBody = 'FOLLOW-UP CUSTOMER EMAILS TODAY:';
        
        Date tdy = Date.today();
        String tdyStr = tdy.format();
        
        reportBody += 'TODAYS DATE: ' + tdyStr;
        
        for(String repStr : resultStrings){
            reportBody += repStr;
        }
        
        reportBody += '<br/>';
        
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(new List<String>{
            //'salesforceadmin@tsbrass.com',
                //'redoakruntest@gmail.com',
                'pcurrin@tsbrass.com'});
        email.setHTMLBody(reportBody);
        email.setSubject('Followup Quote Emails Today Were Sent For These MEA Team Opportunities');
        
        Messaging.SendEmailResult [] r = Messaging.sendEmail(new List<Messaging.SingleEmailMessage> {email});
        
        
        
    }
    
    
    
    
}