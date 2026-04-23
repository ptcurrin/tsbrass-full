public class OpportunityQuoteEmail_VFPage_Controller {

    public Opportunity opp {get;set;}
    public EmailMessage originalLinkedEmail {get;set;}
    public string allPreviousLinkedMessageHTMLBodies {get;set;}
    
    public list<Integer> quotePageBlanks { get;set;}
    public list<Integer> productPageBlanks { get;set;}
    
    public string renderWarningString { get;set;}
    public boolean renderWarningBool { get;set; }
    
    public boolean developmentWarningBool {get;set;}
    public string developmentWarningString {get;set;}
    
    public boolean renderQuotePDFPageBlock {get;set;}
    public boolean renderProductAttachmentsPageBlock {get;set;}
    
    private final string currentInputId {get;set;}
    
    public boolean renderUsefulPage { get;set; }
    public String recipientsString { get; set; }
    public String ccAddressString {get;set;}
    public String bccAddressString {get;set;}
    public String subjectString { get; set; }
    public transient String body { get; set; }
    
    public Set<String> specsForBodyDisplay {get;set;}
    
    
    private List<EmailMessage> emailsForReplyAll {get;set;}
    
    public transient List<Quote> quotes {get;set;}
    private Set<Id> quoteIds {get;set;}
    public Map<Id, Quote> mapQuotes {get;set;}
    List<PDFWrapper> quoteWrapperList {get;set;}
    
    public Integer numQuotesWithPDFs {get;set;} 
    
    public Map<Id, ContentVersion> map_QuoteId_ContentVersion {get;set;}
    
    private List<QuoteLineItem> items {get;set;}
    public Set<Id> quoteLineItemIdSet {get;set;}
    private Map<Id, QuoteLineItem> mapQuoteLineItems {get;set;}
    
    private Map<Id, List<QuoteLineItem>> map_Quotes_QuoteLineItems {get;set;}
    
    Map<Id, Product2> mapProducts {get;set;}
    Map<Id, Id> quoteLineItemProductMap {get;set;}
    
    public Map<Id, List<PDFWrapper>> map_Quote_PDFWrappers {get;set;}
    
    public Map<Id, List<PDFWrapper>> map_QuoteProduct_Wrappers {get;set;}
    
    Map<Id, Id> map_ContentDocumentId_ContentVersion {get;set;}
    public Map<Id, ContentVersion> mapContentVersion {get;set;}
       
    
    private Set<Id> contentVersionIdSet {get;set;}
    
    public String fileAttachment1Name {get;set;}
    public Blob fileAttachment1Body {get;set;}
    public String fileAttachment2Name {get;set;}
    public Blob fileAttachment2Body {get;set;}
    public String fileAttachment3Name {get;set;}
    public Blob fileAttachment3Body {get;set;}
    
    /*
    
    
    
    
    */
    public class ROREmailDriverException extends Exception {}
    
    private ApexPages.StandardController conn;
    
    public OpportunityQuoteEmail_VFPage_Controller(ApexPages.StandardController stdController) {
        
        this.conn = stdController;
        
        if(!Test.isRunningTest()){
        	this.conn.addFields(new List<String>{'Name','Quote_Email_Initial_Body_RichText__c','Salesperson__c'});
        }
        
        this.opp = (Opportunity)conn.getRecord();
        
        system.debug('opp: ' + this.opp);
        
        recipientsString = null;
        ccAddressString = null;
        bccAddressString = null;
        
        body = '';
        subjectString = '';
        
        specsForBodyDisplay = new Set<String>();
        
        contentVersionIdSet = new Set<Id>();
         
        quotePageBlanks = new List<Integer>{1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16};
            productPageBlanks = new List<Integer>{1,2,3,4,5,6,7,8,9,10};
                
                quoteLineItemIdSet = new Set<Id>();
        quoteLineItemProductMap = new Map<Id, Id>();
        renderQuotePDFPageBlock = true;
        renderProductAttachmentsPageBlock = true;
        
        renderWarningBool = false;
        renderWarningString = 'TEST Warning String';
        
        // MISSION: Override the Email Quote button on the Quote Detail Page, in normal Salesforce.
        
        // 1. Get the Opportunity, where email communications will come from, and get its record Id
        // 2. Get all related Quote objects
        // 3. Get all related Quote object pdfs (just the latest one)
        
        // 
        // 1. Display
        
        // var renderUsefulPage - this shows the operational part of the page
        // 
        
        System.PageReference currentPageReference = ApexPages.currentPage();
        String currentURL = currentPageReference.getURL();
        if(currentURL.contains('/apex/OpportunityQuoteEmail_VFPage?core.apexpages.request.devconsole=1')){
            system.debug('includes ... >>> /apex/OpportunityQuoteEmail_VFPage?core.apexpages.request.devconsole=1');
            
            developmentWarningBool = true;
            developmentWarningString = 'RENDERED IN DEVELOPMENT MODE ... ';
            currentInputId = currentPageReference.getParameters().get('id');
        }else{
            
            currentInputId = stdController.getId();
            
        }
        
        // Whether in development mode or not, we must have a quote id to work off of
        // 
        
        
        
        // If the current input Id is good and useful, we can try and get a Quote from it...
        // If the current page did not return a quote id, then we must provide one...
        // we are still rendering a useful page, no matter what, but we must determine if the id we have should be
        // provided and if it is, we need to provide a warning that it is a fake quote demonstration
        


        renderUsefulPage = true;
        if(currentInputId == null ){
            
            //currentInputId = '0Q0Su0000007rh7KAA';
            //currentInputId = '0Q0Su0000007CHNKA2';
            //currentInputId = '0Q0Su0000007xJVKAY';
            //currentInputId = '0Q0Su0000006aiLKAQ';
            //currentInputId = '006Su000007tm4nIAA';
            //currentInputId = '006Su000007v3YDIAY'; 
            currentInputId = '006Su000006wS5KIAU'; // JTG PANORAMA KITCHEN
        }
        
        system.debug('Initial Current Input Id read > ' + currentInputId);
        
        mapQuotes = new Map<Id, Quote>(); 
        map_Quotes_QuoteLineItems = new Map<Id, List<QuoteLineItem>>();
        map_QuoteProduct_Wrappers = new Map<Id, List<PDFWrapper>>(); 
        mapContentVersion = new Map<Id, ContentVersion>(); 
        
        
        
        // Find Recipients for Reply All
        fillEmailAddressesForReplyAll();
        
        // GET THINGS
     	generateProductWrapperList();
        
        
        String signature = '';
        
        if(opp.Salesperson__c != null){
            
            try{
                User currentUser = [SELECT Id, Name, Email, Signature FROM User WHERE Id = :UserInfo.getUserId()];
                
                if(currentUser.signature != null){
                	signature = currentUser.signature;
                
                    if(signature != null){
            			signature = signature.replace('\n', '<br/>');
                    }
                }
            }catch(Exception ex){
                
            }
        }
        
        
        // Build Prospective Body Out
        body += '<br/><br/><br/><br/><br/><br/>' +
            signature
            + '<br/><br/>';
        
        if(!specsForBodyDisplay.isEmpty()){
            
            body += 'PRODUCT SPECIFICATIONS INCLUDED BELOW';
            body += '<br/>';
            for(String tempSpec : specsForBodyDisplay){
               
                body += '<br/><br/>' + tempSpec;
                
            }
            
        }
        
        
        body += '<br/><br/>';
        
        //if(opp.Quote_Email_Initial_Body_RichText__c != null &&
          //opp.Quote_Email_Initial_Body_RichText__c != ''
          //){
              
              //body += opp.Quote_Email_Initial_Body_RichText__c;
              //body += '<br/>';
              
              //system.debug('Adding Initial BodyRichText to body: ' + opp.Quote_Email_Initial_Body_RichText__c);
              
          //}else{        
              //try{
                  
                  // This should be the original email attached to the opportunity
        EmailMessagesRelationStation station = new EmailMessagesRelationStation(opp.Id);
        
        try{
        	originalLinkedEmail = station.getOldestRelatedMessage();
        }catch(Exception ex){
            
        }
            
            
        //body += originalLinkedEmail.HtmlBody;
        allPreviousLinkedMessageHTMLBodies = station.generatePreviousRichTextHTMLBodies();
        //allPreviousLinkedMessageHTMLBodies = station.generatePreviousRichTextHTMLBodiesStacked();
        
        if(allPreviousLinkedMessageHTMLBodies != null){
            
            system.debug('allPreviousLinkedMessageHTMLBodies: ' + allPreviousLinkedMessageHTMLBodies);
            
            body += allPreviousLinkedMessageHTMLBodies;
        }
        
        body += '<br/>fin<br/>';
        
        
              //}catch(Exception ex){
                  
              //}
          //}
        
        if(this.quotes.isEmpty()){
            
            renderWarningString = 'There are no Quote Objects attached to this Opportunity. Fill out a quote and generate a pdf to send out a useful quote! ';
            renderWarningbool = true;
            
        }
        
        
    }
    
    
    @testVisible
    private void fillEmailAddressesForReplyAll(){
        
        emailsForReplyAll = new List<EmailMessage>();
        
        try{
            emailsForReplyAll = [SELECT Id, 
                                 Subject,
                                 ToAddress,
                                 FromAddress,
                                 BCCAddress,
                                 CCAddress,
                                 CreatedDate,
                                 MessageDate 
                                 FROM EmailMessage WHERE RelatedToId = :opp.Id ORDER BY MessageDate DESC LIMIT 1];
            
            Set<String> addedTos = new Set<String>();
            Set<String> addedCCs = new Set<String>();
            Set<String> addedEmails = new Set<String>();
            
            
            for(EmailMessage em : emailsForReplyAll){
                
                system.debug('EMAIL: ' + em.Id + ' - ' + em.CreatedDate);
                system.debug('CCAddress: ' + em.CcAddress);
                
                if(recipientsString != null){
                    recipientsString += ';';
                }else{
                    recipientsString = '';
                }
                
                if(ccAddressString != null){
                    ccAddressString += ';';
                }else{
                    ccAddressString = '';
                }
                
                if(em.FromAddress != null && !recipientsString.contains(em.FromAddress.trim().toLowercase())){
                	recipientsString += em.FromAddress + ';';
                    addedEmails.add(em.FromAddress.trim().toLowercase());
                    addedTos.add(em.FromAddress.trim().toLowercase());
                }
                
                if(em.ToAddress != null 
                   && 
                   !addedEmails.contains(em.ToAddress.trim().toLowercase()) 
                   && 
                   !addedCCs.contains(em.ToAddress.trim().toLowercase()))
                {
                    List<String> tempTos = em.ToAddress.split(';');
                    system.debug('tempTos: ' + tempTos);
                    for(String to: tempTos){
                        String toStr = to.trim().tolowercase();
                        addedEmails.add(toStr);
                        addedTos.add(toStr);
                        system.debug('toStr: ' + toStr);
                    }
                }
                
                if(em.ccAddress != null 
                   && 
                   !addedEmails.contains(em.ccAddress.trim().toLowercase()) 
                   && 
                   !addedCCs.contains(em.ccAddress.trim().toLowercase()))
                {
                    List<String> tempCCs = em.CcAddress.split(';');
                    system.debug('tempCCs: ' + tempCCs);
                    for(String cc : tempCcs){
                        String ccStr = cc.trim().toLowercase();
                        addedEmails.add(ccStr);
                        addedCCs.add(ccStr);
                        system.debug('ccStr: ' + ccStr);
                    }
                }
                
                
                
                subjectString = 'RE: ';
                if(em.Subject != null){
                    subjectString += em.Subject;
                }
            }
            
            String tempTos = '';
            for(String to : addedTos){
                tempTos += to + ';';
            }
            recipientsString = tempTos;
            
            String tempCCs = '';
            for(String cc : addedCCs){
                tempCCs += cc + ';';
            }
            ccAddressString = tempCCs;
            
            
            
            if(opp.Salesperson__c != null){
                
                try{
                    User u = [SELECT Id, Name, Email, Signature FROM User WHERE Id = :opp.Salesperson__c];
                    
                    
                    if(ccAddressString != null && ccAddressString.contains(u.Email)){
                        
                    }else if(ccAddressString != null){
                        ccAddressString = u.Email + ';' + ccAddressString;
                    }
                    
                }catch(Exception ex){
                    
                }
            }
                      
            system.debug('toAddressString: ' + recipientsString);
            system.debug('ccAddressString: ' + ccAddressString);
            
        }catch(QueryException qex){
            
        }
        
    }
        
	private void generateProductWrapperList(){
        

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
            
            
            List<ContentDocumentLink> qcdls;
            List<ContentVersion> qdocvers;
            Map<Id, Id> map_ContentDocumentId_QuoteId = new Map<Id, Id>();
            Map<Id, Id> map_quoteId_to_LatestQuotePDFDocument = new Map<Id, Id>();
            Map<Id, ContentDocument> map_ContentDocuments;
            Set<Id> qcontentDocumentIdSet = new Set<Id>();
            Set<Id> qLatestContentVersionSet = new Set<Id>();
			map_QuoteId_ContentVersion = new Map<Id, ContentVersion>();
            
            try{
                
                
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
                
                
                
                
                for(ContentDocumentLink cdl : qcdls){
                    system.debug('cdl: ' + cdl);
                    system.debug('cdl.LatestVersionId: ' + cdl.ContentDocument.LatestPublishedVersionId);
                }

				for(ContentDocumentLink qcdl : qcdls){
                    map_quoteId_to_LatestQuotePDFDocument.put(qcdl.LinkedEntityId, qcdl.ContentDocumentId);
                    system.debug('map_quoteId_to_LatestQuotePDFDocument put   ' + qcdl.LinkedEntityId + ' > ' + qcdl.ContentDocumentId);
                }
                
                for(Id qId : map_quoteId_to_LatestQuotePDFDocument.keyset()){
                    system.debug('qid: ' + qid + ' > > >  docid: ' + map_quoteId_to_LatestQuotePDFDocument.get(qid));
                }
                
                for(ContentDocumentLink qcdl : qcdls){
                    map_ContentDocumentId_QuoteId.put(qcdl.ContentDocumentId, qcdl.LinkedEntityId);
                    //qContentDocumentIdSet.add(qcdl.ContentDocumentId);
                    qLatestContentVersionSet.add(qcdl.ContentDocument.LatestPublishedVersionId);
                }
                
                // We need to filter off the latest published version id first I think...
                
                
                
                
                
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
                
                
                //map_Quote_PDFWrappers    
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
            
            renderUsefulPage = false;
        }
        
        
        
        
        
        
        
        
        
        
        
        
        
        try{
            
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
            Map<Id, PDFWrapper> mapWrappers = new Map<Id, PDFWrapper>();
            
          
            
            
            for(QuoteLineItem li : items){
                //system.debug('li: ' + li);
                quoteLineItemIdSet.add(li.Id);
                quoteLineItemProductMap.put(li.Id, li.PricebookEntry.Product2Id);
                
                
                
                List<QuoteLineItem> tempList = map_Quotes_QuoteLineItems.get(li.QuoteId);
                if(tempList == null){
                    tempList = new List<QuoteLineItem>();
                }
                tempList.add(li);
                
                PDFWrapper wrapper = new PDFWrapper();
                wrapper.QuoteLineItemId = li.Id;
                wrapper.productId = li.Product2Id;
                wrapper.QuoteId = li.QuoteId;
                mapWrappers.put(li.Id, wrapper);
            }
            system.debug('quoteLineItemProductMap SIZE: ' + quoteLineItemProductMap.keyset().size());
            
            List<ContentDocumentLink> cdls;
            
            try{
                
                
                cdls  = [SELECT Id,
                         Visibility,
                         ShareType,
                         LinkedEntityId, 
                         ContentDocumentId
                         FROM ContentDocumentLink 
                         WHERE LinkedEntityId IN :quoteLineItemProductMap.values()];
                
                
            }catch(QueryException qex){
                cdls = new List<ContentDocumentLink>();
            }
            
            //system.debug('cdls: ' + cdls);
            
            
            
            List<Product2> products = new List<Product2>();
            products = [SELECT Id, Name, Specification__c FROM Product2 WHERE Id IN :quoteLineItemProductMap.values()];
            system.debug('products SIZE: ' + products.size());
            mapProducts = new Map<Id, Product2>(products);
            
            
            
            Set<Id> contentDocumentIds = new Set<Id>();
            List<Blob> pdfBlobList = new List<Blob>();
            
            Set<Id> contentDocumentIdSet = new Set<Id>();
            //Map<Id, ContentDocumentLink> mapConDocId_ConDocLink = new Map<Id, ContentDocumentLink>();
            for(ContentDocumentLink cdl : cdls){
                //contentDocumentIds.add(cdl.ContentDocumentId); 
                //mapConDocId_ConDocLink.put(cdl.ContentDocumentId, cdl);
                contentDocumentIdSet.add(cdl.ContentDocumentId);
            }
            
            List<ContentVersion> docs; 
            map_ContentDocumentId_ContentVersion = new Map<Id, Id>();
            
            
            
            try{
                docs = [SELECT Id, 
                        ContentDocumentId,
                        
                        Title,
                        ContentUrl  
                        FROM ContentVersion
                        //WHERE ContentDocumentId IN :mapConDocId_ConDocLink.keyset()
                        WHERE ContentDocumentId IN :contentDocumentIdSet
                        AND IsLatest = true
                        //AND PublishStatus = 'P'
                       ];
                            
                for(ContentVersion cv : docs){
                    mapContentVersion.put(cv.Id, cv);
                    map_ContentDocumentId_ContentVersion.put(cv.ContentDocumentId, cv.Id);
                    contentVersionIdSet.add(cv.Id);
                }
                                    
                system.debug('map_ContentDocumentId_ContentVersion keyset SIZE: ' + map_ContentDocumentId_ContentVersion.keyset().size());

                
            }catch(QueryException qex){
                docs = new List<ContentVersion>();
            }
            
            for(Product2 p : products){
                //system.debug('PRODUCT2: ' + p);
            }
            
            
            
            
            for(Id quoteLineItemId : mapWrappers.keyset()){
                
                PDFWrapper wrapper = mapWrappers.get(quoteLineItemId);
                
                //QuoteLineItem foundQLI;
				Id foundQLIId;
                Id foundQuoteId;
                String foundQuoteName;
                //ContentDocumentLink foundCDL;
                Id foundCDLContentDocumentId;
                Id foundCDLlinkedEntityId;
                Boolean foundCDL = false;
                
                // Find the correct product spec information
                // Each time this loop runs, it MUST find its information, or the whole program will crash
                
                
                for(ContentDocumentLink cdl : cdls){
                 
                    //system.debug('cdl: ' + cdl);
                    //QuoteLineItem qli = wrapper.QuoteLineItem;
                    if(cdl.LinkedEntityId == wrapper.ProductId){
                        
                        //foundQLI = qli;
						foundQLIId = wrapper.quoteLineItemId;
                        foundQuoteId = wrapper.QuoteId;
                        foundQuoteName = wrapper.QuoteName;
                        foundCDLContentDocumentId = cdl.ContentDocumentId;
                        foundCDLlinkedEntityId = cdl.LinkedEntityId;
                        //foundCDL = cdl;
                        foundCDL = true;
                        break;
                    }
                    
                }
                
                if(foundCDL){
                    
                    //wrapper.cdl = foundCDL;
                    wrapper.LinkedEntityId = foundCDLLinkedEntityId;
                    //wrapper.product = mapProducts.get(foundCDL.linkedEntityId);
                    
                    
                    wrapper.QuoteName = foundQuoteName;
                    //wrapper.quoteId = foundQLI.QuoteId;
					wrapper.QuoteId = foundQuoteId;
                    //wrapper.quote = mapQuotes.get(foundQLI.QuoteId);
                    wrapper.quoteLineItemId = foundQLIId;
                    //wrapper.contentVersion = map_ContentDocumentId_ContentVersion.get(foundCDL.ContentDocumentId);
                    wrapper.contentVersionId = map_ContentDocumentId_ContentVersion.get(FoundCDLContentDocumentId);
                    String tempSpec = mapProducts.get(foundCDLLinkedEntityId).Specification__c;
                    wrapper.specSheetAddress = tempSpec;
					
                    if(tempSpec != null){
                        specsForBodyDisplay.add(tempSpec);
                    }
                    //system.debug('wrapper: ' + wrapper);
                    
                    List<PDFWrapper> tempList = map_QuoteProduct_Wrappers.get(wrapper.quoteId);
                    if(tempList == null){
                        tempList = new List<PDFWrapper>();
                    }
                    tempList.add(wrapper);
                    map_QuoteProduct_Wrappers.put(wrapper.quoteId, tempList);
                    
                    
                    
                }else{
                    
                    throw new ItemMissingException(
                        'No foundCDL while searching ContentDocumentLink list for appropriate QuoteLineItem product. Cannot display specsheet without product object info...  >>> ' + wrapper );
                    
                }
                
            }


            
            
        }catch(QueryException qex){
            throw qex;
        }
        
        if(map_QuoteId_ContentVersion.keyset().isEmpty()){
            
            
            
            renderWarningString = 'There are no pdfs attached to the Salesforce Quote object(s) you have created. Go to the Quote you would like to send and click "Generate PDF" under the dropdown on the upper right of the Quote Detail screen and follow the directions to generate a Quote PDF, first!';
			renderWarningBool = true; 
            
            system.debug('renderWarningString: ' + renderWarningString);
            
        }else{
            
            numQuotesWithPDFs = map_QuoteId_ContentVersion.keyset().size();
            
            for(Id quoteId : map_QuoteId_ContentVersion.keyset()){
            	system.debug(quoteId + ' : ' + map_QuoteId_ContentVersion.get(quoteId));
                
            }
            
            
        }
                
        
        
    }
    
    public class ItemMissingException extends Exception {}
    
        
        
    public class PDFWrapper{
        
        //public ContentDocumentLink cdl {get;set;}
        public Id LinkedEntityId {get;set;}
        public Id quoteId {get;set;}
        public String quoteName {get;set;}
        //public Quote quote {get;set;}
        public Id quoteLineItemId {get;set;}
        //public QuoteLineItem quotelineitem {get;set;}
        //public Product2 product {get;set;}
        public Id productId {get;set;}
        public String specSheetAddress {get;set;}
        //public ContentVersion contentVersion {get;set;}
        public Id contentVersionId {get;set;}
        
        /*
        public override string ToString(){
            
            string s = '';
            
            s+= 'QuoteLineItem:  ' + this.quoteLineItem;
            s+= '  |  ';
            s+= 'LinkedEntityId >  ' + this.linkedEntityId;
            s+= '  |  ';
            s+= 'specSheetAddress >  ' + this.specSheetAddress;
            
            if(product != null){
                s+= '  |  ';
                s+= 'Product: ' + product.ID;
            }
            
            if(contentVersion != null){
            	s+= '  |  ';
            	s+= 'ContentVersonId > ' + contentversion.Id;
            }
            
            return s;
        }
		*/
        
    }
    
    // contentVersionIdSet
    
    public PageReference send() {
        
        
        // Define the email
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage(); 
        
        String addresses = recipientsString;
        
        
        List<String> toAddresses = new List<String>();
        try{
        	toAddresses = recipientsString.split(';'); 
            system.debug('toAddresses after split: ' + toAddresses);
            Set<String> tempAddresses = new Set<String>();
            for(String address : toAddresses){
                String addressStr = address.tolowercase().trim();
                system.debug('str: ' + addressStr);
                tempAddresses.add(addressStr);
            }
            List<String> finalToAddresses = new List<String>();
            for(String address: tempAddresses){
                finalToAddresses.add(address);
            }
            
            toAddresses = finalToAddresses;
            system.debug('toAddresses after set shuffle: ' + toAddresses);
            
        }catch(Exception ex){
            
            throw ex;
            
        }
        
        
        List<String> ccAddresses = new List<String>();
        try{
            system.debug('ccAddressString: ' + ccAddressString);
            if(ccAddressString != null && ccAddressString != ''){
                ccAddresses = ccAddressString.split(';'); 
                List<String> tempccAddresses = new List<String>();
                for(String ccaddress : ccAddresses){
                    tempccAddresses.add(ccaddress.trim());
                }
                ccAddresses = tempccAddresses;
            }
        }catch(Exception ex){
            
            throw ex;
            
        }
        
        List<String> bccAddresses = new List<String>();
        try{
            system.debug('bccAddressString: ' + bccAddressString);
            if(bccAddressString != null && bccAddressString != ''){
                bccAddresses = bccAddressString.split(';'); 
                List<String> tempbccAddresses = new List<String>();
                for(String bccaddress : bccAddresses){
                    tempbccAddresses.add(bccaddress.trim());
                }
                bccAddresses = tempbccAddresses;
            }
        }catch(Exception ex){
            
            throw ex;
            
        }
        
         
        //toAddresses.add('redoakruntest@gmail.com');
        
        
        system.debug('toAddresses: ' + toAddresses);
        
        // Sets the paramaters of the email
        email.setSubject( subjectString );
        email.setToAddresses( toAddresses );
        
        if(!ccAddresses.isEmpty()){
        	email.setCCAddresses( ccAddresses );
        }
        
        if(!bccAddresses.isEmpty()){
        	email.setBCCAddresses( bccAddresses );
        }
        
        email.setHTMLBody( body );
        
        //email.setTargetObjectId(opp.Id);
        //email.setTargetObjectIds(new List<Id>());
        email.setWhatId(opp.Id);
        
        List<Id> attachmentIds = new List<Id>();
        
        // Quote
        
        for(Id idee: contentVersionIdSet){
            attachmentIds.add(idee);
        }
        
        
       
        //List<Messaging.EmailFileAttachment> actualAttachments = new List<Messaging.EmailFileAttachment>();
        
        
        if(fileAttachment1body != null){
            ContentVersion cv = new ContentVersion();
            cv.VersionData = fileAttachment1body;
            cv.Title = fileAttachment1name;
            
            Datetime dtnw = datetime.Now();
            String yearstr = String.valueOf(dtnw.year());
            String monthstr = String.valueOf(dtnw.month());
            if(monthstr.length() == 1){
                monthstr = '0' + monthstr;
            }
            String dayStr = String.ValueOf(dtnw.day());
            if(dayStr.length() == 1){
                daystr = '0' + dayStr;
            }
            String hourStr = String.ValueOf(dtnw.hour());
            if(hourStr.length() == 1){
                hourStr = '0' + hourStr;
            }
            String minuteStr = String.ValueOf(dtnw.minute());
            if(minuteStr.length() == 1){
                minuteStr = '0' + minuteStr;
            }
            String secondStr = String.ValueOf(dtnw.second());
            if(secondStr.length() == 1){
                secondStr = '0' + secondStr;
            }
            String millsecStr = String.ValueOf(dtnw.millisecond());
            if(millsecStr.length() == 1){
                millsecStr = '0' + millsecStr;
            }
            
            cv.PathOnClient = yearstr + monthstr + daystr + monthstr + hourstr + secondstr + millsecStr + '_' + fileAttachment1name;
            cv.Description = fileAttachment1name;
            cv.isMajorVersion = true;
            
            insert cv;
            
            ContentVersion cvGet = [SELECT Id FROM ContentVersion WHERE Id = :cv.Id];
            
            attachmentIds.add(cvGET.Id);
            
            system.debug('attachment Ids inside fileAttachment1 space: ' + attachmentIds);
            
        }else{
            system.debug('FileAttachment not filled in or detected: ' + fileAttachment1name);
        }
        
        if(fileAttachment2body != null){
            ContentVersion cv = new ContentVersion();
            cv.VersionData = fileAttachment2body;
            cv.Title = fileAttachment2name;
            
            Datetime dtnw = datetime.Now();
            String yearstr = String.valueOf(dtnw.year());
            String monthstr = String.valueOf(dtnw.month());
            if(monthstr.length() == 1){
                monthstr = '0' + monthstr;
            }
            String dayStr = String.ValueOf(dtnw.day());
            if(dayStr.length() == 1){
                daystr = '0' + dayStr;
            }
            String hourStr = String.ValueOf(dtnw.hour());
            if(hourStr.length() == 1){
                hourStr = '0' + hourStr;
            }
            String minuteStr = String.ValueOf(dtnw.minute());
            if(minuteStr.length() == 1){
                minuteStr = '0' + minuteStr;
            }
            String secondStr = String.ValueOf(dtnw.second());
            if(secondStr.length() == 1){
                secondStr = '0' + secondStr;
            }
            String millsecStr = String.ValueOf(dtnw.millisecond());
            if(millsecStr.length() == 1){
                millsecStr = '0' + millsecStr;
            }
            
            cv.PathOnClient = yearstr + monthstr + daystr + monthstr + hourstr + secondstr + millsecStr + '_' + fileAttachment2name;
            cv.Description = fileAttachment2name;
            cv.isMajorVersion = true;
            
            insert cv;
            
            ContentVersion cvGet = [SELECT Id FROM ContentVersion WHERE Id = :cv.Id];
            
            attachmentIds.add(cvGET.Id);
            
            system.debug('attachment Ids inside fileAttachment2 space: ' + attachmentIds);
            
        }else{
            system.debug('FileAttachment2 not filled in or detected: ' + fileAttachment2name);
        }
        
        if(fileAttachment3body != null){
            ContentVersion cv = new ContentVersion();
            cv.VersionData = fileAttachment3body;
            cv.Title = fileAttachment3name;
            
            Datetime dtnw = datetime.Now();
            String yearstr = String.valueOf(dtnw.year());
            String monthstr = String.valueOf(dtnw.month());
            if(monthstr.length() == 1){
                monthstr = '0' + monthstr;
            }
            String dayStr = String.ValueOf(dtnw.day());
            if(dayStr.length() == 1){
                daystr = '0' + dayStr;
            }
            String hourStr = String.ValueOf(dtnw.hour());
            if(hourStr.length() == 1){
                hourStr = '0' + hourStr;
            }
            String minuteStr = String.ValueOf(dtnw.minute());
            if(minuteStr.length() == 1){
                minuteStr = '0' + minuteStr;
            }
            String secondStr = String.ValueOf(dtnw.second());
            if(secondStr.length() == 1){
                secondStr = '0' + secondStr;
            }
            String millsecStr = String.ValueOf(dtnw.millisecond());
            if(millsecStr.length() == 1){
                millsecStr = '0' + millsecStr;
            }
            
            cv.PathOnClient = yearstr + monthstr + daystr + monthstr + hourstr + secondstr + millsecStr + '_' + fileAttachment3name;
            cv.Description = fileAttachment3name;
            cv.isMajorVersion = true;
            
            insert cv;
            
            ContentVersion cvGet = [SELECT Id FROM ContentVersion WHERE Id = :cv.Id];
            
            attachmentIds.add(cvGET.Id);
            
            system.debug('attachment Ids inside fileAttachment3 space: ' + attachmentIds);
            
        }else{
            system.debug('FileAttachment3 not filled in or detected: ' + fileAttachment3name);
        }
        
        
        if(!attachmentIds.isEmpty()){
        	email.setEntityAttachments(attachmentIds);
        }
        
        // Sends the email
        Messaging.SendEmailResult [] r = Messaging.sendEmail(new Messaging.SingleEmailMessage[] {email});  system.debug('Result: ' + r);
        
        // If Result Good ...
        if(r[0].isSuccess()){
        	
            Opportunity opp = [SELECT Id, 
                               Quote_Email_Followup_Interval_Days__c,
                               Quote_Email_Initial_Body_RichText__c,
                               Quote_Email_Initial_Send_Date__c,
                               Quote_Email_Last_Recorded_Followup_Date__c,
                               Quote_Email_Next_Followup_Date__c,
                               Quote_Email_Standard_Followup_Blurb__c,
                               Quote_Email_Standard_Followup_Subject__c
                               FROM Opportunity WHERE Id = :email.whatId];
            
            if(opp.Quote_Email_Initial_Send_Date__c == null){
            	opp.Quote_Email_Initial_Send_Date__c = Date.Today();
            }
            
            if((opp.Quote_Email_Initial_Body_RichText__c == null || opp.Quote_Email_Initial_Body_RichText__c == '')
              && (originalLinkedEmail != null  && originalLinkedEmail.HtmlBody != null)
              ){
                opp.Quote_Email_Initial_Body_RichText__c = originalLinkedEmail.HTMLBody;
            	//opp.Quote_Email_Initial_Body_RichText__c = allPreviousLinkedMessageHTMLBodies;
            }
            
            opp.Quote_Email_Next_Followup_Date__c = Date.today().addDays(Integer.valueOf(opp.Quote_Email_Followup_Interval_Days__c));
            
            update(opp);
            return new PageReference(Url.getOrgDomainUrl().toExternalForm() + '/' + email.whatId);
        	
            
        }else{
            
            return null;
            
        }
        

    }
    
    
}