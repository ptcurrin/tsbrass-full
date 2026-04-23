public class OpportunityQuoteEmailBuilder {
    
    // main variables
    private final Id                     currentInputId                        {get;set;}
    public  Opportunity                  opp                                   {get;set;}
    
    // quote variables
    private List<Quote>                  quotes                                {get;set;}
    private Map<Id, Quote>               mapQuotes                             {get;set;}
    private Set<Id>                      quoteIds                              {get;set;}
    
    // quote PDF doc variables
    private List<ContentDocumentLink>    qcdls                                 {get;set;}
    private List<ContentVersion>         qdocvers                             {get;set;}
    private Map<Id, Id>                  map_ContentDocumentId_QuoteId         {get;set;}
    private Map<Id, Id>                  map_quoteId_to_LatestQuotePDFDocument {get;set;}
    private Set<Id>                      qcontentDocumentIdSet                 {get;set;}
    private Set<Id>                      qLatestContentVersionSet              {get;set;}
    private Map<Id, ContentVersion>      map_QuoteId_ContentVersion            {get;set;}
    private Set<Id>                      contentVersionIdSet                   {get;set;}
    
    // quote line items variables
    private List<QuoteLineItem>          items                                 {get;set;}
    private Map<Id, QuoteLineItem>       mapQuoteLineItems                     {get;set;}
    private Set<Id>                      quoteLineItemIdSet                    {get;set;}
    private Map<Id, List<QuoteLineItem>> map_Quotes_QuoteLineItems             {get;set;}
    private Map<Id, Id>                  quoteLineItemProductMap               {get;set;}
    private List<Product2>               products                              {get;set;}
    private Map<Id, Product2>            mapProducts                           {get;set;}
    
    
    // last email 
    private EmailMessage                 lastEmailOutgoing                     {get;set;}
    
    // next email
    private Messaging.SingleEmailMessage email                         {get;set;}
    
    // email address fields
    private String                       stringAddresses               {get;set;}
    private String                       stringCCs 	                   {get;set;}
    
    // email subject
    public  String                       stringSubject                 {get;set;} // this should come from the Opportunity
    
    // email body fields
    private String                       stringBody 	               {get;set;}
    
    public Messaging.SendEmailResult []  r                             {get;set;}
    
    public OpportunityQuoteEmailBuilder(Id oppId){
        
        this.currentInputId = oppId;
        this.opp = [SELECT Id,
                    Name,
                    Salesperson__c,
                    Quote_Email_Followup_Interval_Days__c,
                    Quote_Email_Initial_Body_RichText__c,
                    Quote_Email_Initial_Send_Date__c,
                    Quote_Email_Standard_Followup_Blurb__c,
                    Quote_Email_Standard_Followup_Subject__c,
                    Quote_Email_Next_Followup_Date__c
                    
                    FROM Opportunity WHERE Id = :currentInputId
                   ];
        
        this.quotes = new List<Quote>();
        
        
        this.map_ContentDocumentId_QuoteId = new Map<Id, Id>();
        this.qcontentDocumentIdSet         = new Set<Id>();
        this.qLatestContentVersionSet      = new Set<Id>();
        this.map_quoteId_to_LatestQuotePDFDocument = new Map<Id, Id>();
        this.map_QuoteId_ContentVersion    = new Map<Id, ContentVersion>();
        
        
        
        gatherQuotePDFs();
        gatherProductsInformation();
        buildEmail(); 
        
    }
    
    
    private void gatherQuotePDFs(){
        
        contentVersionIdSet = new Set<Id>();
        
        try{
            
            quotes = [SELECT Id, 
                      CreatedDate,
                      LastModifiedDate,
                      Name, 
                      AccountId,
                      OpportunityId,
                      Email, 
                      ContactId, 
                      Contact.Name, 
                      Contact.Email 
                      FROM Quote 
                      WHERE OpportunityId = :currentInputId
                      AND Attach_PDF_to_Emails__c = true
                      ORDER BY CreatedDate
                     
                     ];
        
            mapQuotes = new Map<Id, Quote>(quotes); 
            
            
            quoteIds = new Set<Id>();
            for(Quote q : quotes){
                quoteIds.add(q.Id);
            }
            
            system.debug('quotes SIZE: ' + quotes.size());
            
            
            // At this point, we should have the pertinent quote objects ... 
            // We got the stuff by looking for quotes marked "Attach_PDF_to_Emails__c = true" 
            // which are also related to the Opportunity
            // 
            
            
            
            try{
                
                /*
                qcdls  = [SELECT Id,
                         Visibility,
                         ShareType,
                         LinkedEntityId, 
                         ContentDocumentId,
                         ContentDocument.LatestPublishedVersionId 
                         FROM ContentDocumentLink 
                         WHERE LinkedEntityId IN :quoteids
                         
                         ];
                */
                qcdls  = [SELECT Id,
                         Visibility,
                         ShareType,
                         LinkedEntityId, 
                         ContentDocumentId,
                         ContentDocument.Title,
                         ContentDocument.LatestPublishedVersionId 
                         FROM ContentDocumentLink 
                         WHERE LinkedEntityId IN :quoteids
                         ORDER BY ContentDocument.Title ASC
                         ];
                
                Map<Id, Datetime> quoteToLatestQuotePDFCreation = new Map<Id, Datetime>(); 
                
                for(ContentDocumentLink qcdl : qcdls){
                    map_quoteId_to_LatestQuotePDFDocument.put(qcdl.LinkedEntityId, qcdl.ContentDocumentId);
                    system.debug('map_quoteId_to_LatestQuotePDFDocument put   ' + qcdl.LinkedEntityId + ' > ' + qcdl.ContentDocumentId);
                }
                
                for(Id qId : map_quoteId_to_LatestQuotePDFDocument.keyset()){
                    system.debug('qid: ' + qid + ' > > >  docid: ' + map_quoteId_to_LatestQuotePDFDocument.get(qid));
                }
                /*
                for(ContentDocumentLink cdl : qcdls){
                    system.debug('cdl: ' + cdl);
                    system.debug('cdl.LatestVersionId: ' + cdl.ContentDocument.LatestPublishedVersionId);
                }*/
                
                for(ContentDocumentLink qcdl : qcdls){
                    
                    map_ContentDocumentId_QuoteId.put(qcdl.ContentDocumentId, qcdl.LinkedEntityId);
                    //qcontentDocumentIdSet.add(qcdl.ContentDocumentId);
                    qLatestContentVersionSet.add(qcdl.ContentDocument.LatestPublishedVersionId);
                    
                }
                
                /*
                qdocvers = [SELECT Id, 
                        ContentDocumentId,
                        Title,
                        ContentUrl,
                         VersionNumber 
                        FROM ContentVersion
                        
                        WHERE Id IN :qLatestContentVersionSet
                         AND IsLatest = true
                        ORDER BY VersionNumber DESC
                       ];
                */
                
                qdocvers = [SELECT Id, 
                        ContentDocumentId,
                        Title,
                        ContentUrl,
                        VersionNumber 
                        FROM ContentVersion
                        ///////////////WHERE ContentDocumentId IN :mapConDocId_ConDocLink.keyset()
                        //WHERE ContentDocumentId IN :qcontentDocumentIdSet
                        WHERE Id IN :qLatestContentVersionSet
                         AND IsLatest = true
                            AND ContentDocumentId IN :map_quoteId_to_LatestQuotePDFDocument.values()
                        //AND PublishStatus = 'P'
                        ORDER BY VersionNumber DESC
                       ];
                
				if(qdocvers.isEmpty()){
                    
                }else{
                    system.debug('qdocvers.size(): ' + qdocvers.size());
                }
                
                for(ContentVersion qcv : qdocvers){
                    
                    Id quoteId = map_ContentDocumentId_QuoteId.get(qcv.ContentDocumentId);
                    
                    ContentVersion TempCV = map_QuoteId_ContentVersion.get(quoteId);
                    if(tempCV == null){
                    	map_QuoteId_ContentVersion.put(quoteId, qcv);
                    }else if(tempCV != null){
                        
                        if(qcv.VersionNumber > tempCV.VersionNumber){
                            map_QuoteId_ContentVersion.put(quoteId, qcv);
                        }
                        
                    }
                    
                    
                }
                
				for(ContentVersion qcv : map_QuoteId_ContentVersion.values()){
                    contentVersionIdSet.add(qcv.Id);
                }
				                
                
                
                
            }catch(QueryException qex){
                qcdls = new List<ContentDocumentLink>();
            }
            
            
           
            
            
        }catch(QueryException qex){
            
            
        }
        
    }    
        
        
    private void gatherProductsInformation(){
    
            // GET items
            items = new List<QuoteLineItem>();
            
            items = [SELECT Id, 
                     QuoteId,
                     Product2Id,
                     PricebookEntry.Product2.Specification__c,
                     PricebookEntry.Product2Id
                     //Spec__c
                     FROM QuoteLineItem
                     WHERE QuoteId IN :quoteIds
                     ORDER BY SortOrder
                    ];
            
            system.debug('items SIZE: ' + items.size());
            
            mapQuoteLineItems = new Map<Id, QuoteLineItem>(items);
            quoteLineItemProductMap = new Map<Id, Id>();
            quoteLineItemIdSet = new Set<Id>();
        	map_Quotes_QuoteLineItems = new Map<Id, List<QuoteLineItem>>();
           
            for(QuoteLineItem li : items){
                
                quoteLineItemIdSet.add(li.Id);
                quoteLineItemProductMap.put(li.Id, li.PricebookEntry.Product2Id);
                
                
                
                List<QuoteLineItem> tempList = map_Quotes_QuoteLineItems.get(li.QuoteId);
                if(tempList == null){
                    tempList = new List<QuoteLineItem>();
                }
                tempList.add(li);
                
            }
            system.debug('quoteLineItemProductMap SIZE: ' + quoteLineItemProductMap.keyset().size());
         
            
            products = new List<Product2>();
            products = [SELECT Id, Name, Specification__c FROM Product2 WHERE Id IN :quoteLineItemProductMap.values()];
            system.debug('products SIZE: ' + products.size());
            mapProducts = new Map<Id, Product2>(products);
            
       
    }
    
    private void buildEmail(){
        
        email = new Messaging.SingleEmailMessage(); 
        
        // We need some information from the old Opportunity, and we also need some information from 
        // the last email to go out from this opportunity, which should be the last thing we sent as
        // a product offering. 
        
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
                                 WHERE RelatedToId = :opp.Id
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
        
        
        if(opp.Quote_Email_Standard_Followup_Subject__c != null){
        	this.stringSubject   = opp.Quote_Email_Standard_Followup_Subject__c;    // from the opportunity: Standard Subject
        }else{
            this.stringSubject = opp.Name;
        }
        system.debug('stringSubject: ' + stringSubject);
        email.setSubject(stringSubject);
        
        this.stringBody      = ''; // Will the name be from the quote or the opportunity? It's not part of the linked email on the opp...?
        if(opp.Quote_Email_Standard_Followup_Blurb__c != null){
        	this.stringBody     += opp.Quote_Email_Standard_Followup_Blurb__c; 
        }// continue building the body with a followup blurb
        
        
        system.debug('opp: ' + opp);
        
        String signature = '';
        
        if(opp.Salesperson__c != null){
            
            
            try{
                User u = [SELECT Id, Name, Email, Signature FROM User WHERE Id = :opp.Salesperson__c];
                
                //OrgWideEmailAddress owa = [SELECT Id, DisplayName, Address FROM OrgWideEmailAddress WHERE Address = :u.Email];                
                //email.setOrgWideEmailAddressId (owa.Id);
                
                email.setReplyTo(u.Email);
                email.setSenderDisplayName(u.Name);
                
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
        
        
        EmailMessagesRelationStation station = new EmailMessagesRelationStation(opp.Id);
        this.stringbody += station.generatePreviousRichTextHTMLBodies();
        
        this.stringBody     +=   '<br/><br/><br/>';
        
        /*
        if(opp.Quote_Email_Initial_Body_RichText__c != null){
            this.stringBody     +=   '<br/><br/><br/><br/><br/><br/>';
        	//this.stringBody     += opp.Quote_Email_Initial_Body_RichText__c;        // This should be filled in, the first time an email goes out from Salesforce
        	
        }
        */
        
    }
    
    
    public Boolean send() {
        
        boolean success = false;
          
        
            
        List<String> toAddresses = new List<String>();
        try{
        	toAddresses = this.stringAddresses.split(';'); 
            system.debug('toAddresses after split: ' + toAddresses);
            Set<String> tempAddresses = new Set<String>();
            for(String address : toAddresses){
                String addressStr = address.trim().tolowercase();
                system.debug('str: ' + addressStr);
                tempAddresses.add(addressStr);
            }
            List<String> finalToAddresses = new List<String>();
            for(String address: tempAddresses){
                if(!finalToAddresses.contains(address)){
                	finalToAddresses.add(address);
                }
            }
            
            system.debug('toAddresses after set shuffle: ' + finalToAddresses);
            email.setToAddresses(finalToAddresses);
            
        }catch(Exception ex){
            
            throw ex;
            
        }
        
        
        List<String> ccAddresses = new List<String>();
        try{
            
            List<String> tempccAddresses = new List<String>();
            if(this.stringCCs != null && this.stringCCs != ''){
                ccAddresses = this.stringCCs.split(';'); 
                for(String ccaddress : ccAddresses){
                    String tempCC = ccaddress.trim().toLowercase();
                    if(!tempccAddresses.contains(tempCC)){
                    	tempccAddresses.add(tempCC);
                    }
                }
                
            }
            List<String> finalCCAddresses = new List<String>();
            for(String address: tempccAddresses){
                if(!finalCCAddresses.contains(address)){
                	finalCCAddresses.add(address);
                }
            }
            ccAddresses = finalCCaddresses;
            system.debug('CCAddresses after set shuffle: ' + ccAddresses);
            
            
            if(opp.Salesperson__c != null){
                
                try{
                    User u = [SELECT Id, Name, Email FROM User WHERE Id = :opp.Salesperson__c];
                    
                    
                    if(ccAddresses.contains(u.Email)){
                        
                    }else{
                        ccAddresses.add(u.Email);
                    }
                    
                }catch(Exception ex){
                    
                }
            }
            system.debug('CCAddresses after Salesperson check: ' + ccAddresses);
            
            email.setCCAddresses(ccAddresses);
            
        }catch(Exception ex){
            
            throw ex;
            
        }
        
        
        //email.setBCCAddresses(new List<String>{'pcurrin@tsbrass.com'});// ,'salesforceadmin@tsbrass.com'
        
        
        system.debug('stringBody: ' + stringBody);
        email.setHTMLBody( this.stringBody );
        
        email.setWhatId(opp.Id);
        
        EmailMessagesRelationStation station = new EmailMessagesRelationStation(opp.Id);
        EmailMessage lastMessage = station.getLatestRelatedMessage();
        email.setInReplyTo(lastMessage.MessageIdentifier);
        
        List<Id> attachmentIds = new List<Id>();
        
        // Quote PDFs Attached:
        for(Id idee: contentVersionIdSet){
            attachmentIds.add(idee);
        }
        
        
        
        email.setEntityAttachments(attachmentIds);
        
        // Sends the email
        
        if(!Test.isRunningTest()){    
            r = Messaging.sendEmail(new Messaging.SingleEmailMessage[] {email});  
        }
        system.debug('Result: ' + r);
        
        // If Result Good ...
        if(r != null && r[0].isSuccess() || Test.isRunningTest()){
        	
            Opportunity opp = [SELECT Id FROM Opportunity WHERE Id = :email.whatId];
            opp.Quote_Email_Last_Recorded_Followup_Date__c = Date.Today();  update(opp);  return true;
        	
            
        }else{
            
            return false;
            
        }
                
    }
    
    
}