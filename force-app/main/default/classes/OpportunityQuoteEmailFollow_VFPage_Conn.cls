public class OpportunityQuoteEmailFollow_VFPage_Conn {

    // Check each one of these and make sure it has a place on the visualization page
    
    private ApexPages.StandardController conn;
    public Opportunity opp_Found {get;set;}
    public boolean oppFoundNull {get;set;}
    
    public string stringBody {get;set;}
    public string stringSubject {get;set;}
    public string stringAddresses {get;set;}
    public string stringCCs {get;set;}
    public string signature {get;set;}
    
    public string replyTo {get;set;}
    public string senderDisplayName {get;set;}
    
    private List<String> resultStrings {get;set;}
    
    //public class NoObjectInScopeException extends Exception {}
    
    public OpportunityQuoteEmailFollow_VFPage_Conn(ApexPages.StandardController stdController) {
        
        oppFoundNull = false;
        this.conn = stdController;
        if(!Test.isRunningTest()){
        	this.conn.addFields(new List<String>{'Name',
                'Quote_Email_Initial_Body_RichText__c',
                'Salesperson__c',
                'Quote_Email_Followup_Interval_Days__c',
                'Quote_Email_Last_Recorded_Followup_Date__c',
                'Quote_Email_Next_Followup_Date__c',
                'Quote_Email_Standard_Followup_Subject__c',
                'Quote_Email_Standard_Followup_Blurb__c'
                });
        }
        
        this.opp_Found = (Opportunity)conn.getRecord();
        
        system.debug('opp Found(scope): ' + opp_Found);
        
        if(opp_Found == null){ 
            oppFoundNull = true;
            //throw new NoObjectInScopeException('There is no opportunity found: ' + opp_Found); 
        }
        
        EmailMessage lastEmailOutgoing;
        try{
            lastEmailOutgoing = [SELECT Id,
                                 BccAddress,
                                 CCAddress,
                                 CreatedById,
                                 CreatedDate,
                                 FirstOpenedDate,
                                 ValidatedFromAddress,
                                 FromAddress,
                                 FromName,
                                 HasAttachment,
                                 Headers,
                                 HtmlBody,
                                 //Initial_OppQuote_Send_Date__c,
                                 IsExternallyVisible,
                                 Incoming,
                                 LastModifiedById,
                                 LastModifiedDate,
                                 LastOpenedDate,
                                 MessageDate,
                                 ParentId,
                                 RelatedToId,
                                 Status,
                                 Subject,
                                 TextBody,
                                 ToAddress
                                 FROM EmailMessage
                                 WHERE RelatedToId = :opp_Found.Id
                                 AND Incoming = false
                                 ORDER BY CreatedDate DESC
                                 LIMIT 1
                                ];
            
        }catch(QueryException qex){
            
            
            
        }
        
        //			Id,
        //            Name,
        //            Quote_Email_Followup_Interval_Days__c,
        //            Quote_Email_Initial_Body_RichText__c,
        //            Quote_Email_Initial_Send_Date__c,
        //            Quote_Email_Standard_Followup_Blurb__c,
        //            Quote_Email_Standard_Followup_Subject__c
        
        
        // Set Addresses from Prior Addresses
        this.stringAddresses = lastEmailOutgoing.ToAddress;                     // this is a string field, multiple possible addresses with a semicolon
        this.stringCCs       = lastEmailOutgoing.CcAddress;                     // this is a string field, multiple possible addresses with a semicolon
        
        
        if(opp_Found.Quote_Email_Standard_Followup_Subject__c != null){
        	this.stringSubject   = opp_Found.Quote_Email_Standard_Followup_Subject__c;    // from the opportunity: Standard Subject
        }else{
            this.stringSubject = opp_Found.Name;
        }
        system.debug('stringSubject: ' + stringSubject);
        //email.setSubject(stringSubject);
        
        this.stringBody      = ''; // Will the name be from the quote or the opportunity? It's not part of the linked email on the opp...?
        if(opp_Found.Quote_Email_Standard_Followup_Blurb__c != null){
        	this.stringBody     += opp_Found.Quote_Email_Standard_Followup_Blurb__c; 
        }// continue building the body with a followup blurb
        
        
        system.debug('opp_Found: ' + opp_Found);
        
        //String signature = '';
        
        if(opp_Found.Salesperson__c != null){
            
            
            try{
                User u = [SELECT Id, Name, Email, Signature FROM User WHERE Id = :opp_Found.Salesperson__c];
                
                //OrgWideEmailAddress owa = [SELECT Id, DisplayName, Address FROM OrgWideEmailAddress WHERE Address = :u.Email];                
                //email.setOrgWideEmailAddressId (owa.Id);
                
                
                //email.setReplyTo(u.Email);
                replyTo = u.Email;
                //email.setSenderDisplayName(u.Name);
                senderDisplayName = u.Name;
                
                
                if(u.Signature != null){
                    signature = u.Signature;
                }
                
                //this.stringBody +=   '<br/>' + u.Name + '<br/>';
                
                if(signature != null){
                    this.stringBody     += '<br/><br/>' + signature + '<br/>';
                }
                
            }catch(Exception ex){
                
            }
        }
        
        
        EmailMessagesRelationStation station = new EmailMessagesRelationStation(opp_Found.Id);
        this.stringbody += station.generatePreviousRichTextHTMLBodies();
        
        
        
    }
    
    public PageReference send(){
        
        OpportunityQuoteEmailBuilder builder = new OpportunityQuoteEmailBuilder(opp_Found.Id);
        boolean result = builder.send();
        
        Date tdy = Date.today();
        Date nextFollowupDate = tdy.addDays(Integer.valueOf(opp_Found.Quote_Email_Followup_Interval_Days__c));
        
        Opportunity oppUpdate = new Opportunity();
        oppUpdate.Id = opp_Found.Id;
        oppUpdate.Quote_Email_Next_Followup_Date__c = nextFollowupDate;
        oppUpdate.Quote_Email_Last_Recorded_Followup_Date__c = tdy;
        update(oppUpdate);
         
        String orgBaseUrl = Url.getOrgDomainUrl().toExternalForm();
        String reportBody = '</br>';
        reportBody += '</br>' + orgBaseUrl + '/' + builder.opp.Id + '  ...  ' + builder.opp.Name + ' - EmailSubject:' + builder.stringSubject;
        reportBody += '</br>Next Scheduled Follow-Up Email: ' + builder.opp.Quote_Email_Next_Followup_Date__c; 
        
        resultStrings = new List<String>();
        resultStrings.add(reportBody);
        
        
        reportBody = '<br/>FOLLOW-UP CUSTOMER EMAILS TODAY:';
        
        
        String tdyStr = tdy.format();
        
        reportBody += '<br/>TODAYS DATE: ' + tdyStr;
        
        
        for(String repStr : resultStrings){
            reportBody += repStr;
        }
        
        reportBody += '<br/>';
        
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(new List<String>{
            'salesforceadmin@tsbrass.com',
                'redoakruntest@gmail.com',
                'pcurrin@tsbrass.com'});
        email.setHTMLBody(reportBody);
        email.setSubject('Followup Quote Email(s) Today Were Sent For This MEA Team Opportunity');
        
        Messaging.SendEmailResult [] r = Messaging.sendEmail(new List<Messaging.SingleEmailMessage> {email});
        
        
        
        return new PageReference('/' + opp_Found.Id);
    }
    
}