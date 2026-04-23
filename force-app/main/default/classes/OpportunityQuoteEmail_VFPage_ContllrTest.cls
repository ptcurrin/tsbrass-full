@isTest
public class OpportunityQuoteEmail_VFPage_ContllrTest {
    
    static testmethod void touch(){
        
        Opportunity o = new Opportunity();
        o.NAme = 'TestOpp';
        o.StageName = 'Target';
        o.CloseDate = Date.today();
        insert(o);
        
        EmailMessage em = new EmailMessage();
        em.Subject = 'TESTSUBJECT - Original Linked Email';
        em.ToAddress = 'redoakruntest@gmail.com;patrick.currin@redoakrun.com';
        em.FromAddress = 'salesforceadmin@tsbrass.com';
        em.BCCAddress = 'aneese@tsbrass.com;pcurrin@tsbrass.com';
        em.CCAddress = 'test1@cc.com;test2@cc.com';
        em.MessageDate = Date.today().addDays(-5);
        em.RelatedToId = o.Id;
        em.Incoming = false;
        em.TextBody = 'TESTTEXTBODY - Original Linked Email';
        em.HtmlBody = 'TESTHTMLBODY - Original Linked Email<br>';
        insert(em);
        
        
        
        EmailMessage em2 = new EmailMessage();
        em2.Subject = 'TESTSUBJECT2';
        em2.ToAddress = 'redoakruntest@gmail.com;patrick.currin@redoakrun.com';
        em2.FromAddress = 'salesforceadmin@tsbrass.com';
        em2.BCCAddress = 'aneese@tsbrass.com;pcurrin@tsbrass.com';
        em2.CCAddress = 'test1@cc.com;test2@cc.com';
        em2.MessageDate = Date.today().addDays(-1);
        em2.RelatedToId = o.Id;
        em.TextBody = 'TESTTEXTBODY - Second Linked Email';
        em.HtmlBody = 'TESTHTMLBODY - Second Linked Email<br>';
        insert(em2);
        
        
        
        
        Product2 p = new Product2();
        p.Name = 'PRODUCTTESTNAME';
        p.ProductCode = 'PRODUCTTESTNAME'; 
        //p.List_USD__c = 1.00;
        insert(p);
        
        Pricebook2 pb = new Pricebook2();
        pb.Name = 'PRICEBOOKTESTNAME';
        pb.Calendar_Year__c = '2024';
        //pb.Quote_Object_Name_Concatenation__c = 'PRICEBOOKTESTNAME';
        insert(pb);
        
        Quote q = new Quote();
        q.Name = 'QUOTETESTNAME';
        q.OpportunityId = o.Id;
        //q.Terms__c = 'PREPAID';
        q.Pricebook2Id = pb.Id;
        q.Attach_PDF_to_Emails__c = true;
        insert(q);
        
        ContentVersion contentVersionProduct = new ContentVersion(
            Title          = 'a picture',
            PathOnClient   = 'Pic.jpg',
            VersionData    = Blob.valueOf('Test Content'),
            IsMajorVersion = true);
        insert contentVersionProduct;
        List<ContentDocument> documents = [SELECT Id, Title, LatestPublishedVersionId FROM ContentDocument WHERE Title = 'a picture'];
        
        //create ContentDocumentLink  record
        
        ContentDocumentLink cdlProduct = new ContentDocumentLink();
        cdlProduct.LinkedEntityId = p.Id;
        cdlProduct.ContentDocumentId = documents[0].Id;
        cdlProduct.ShareType = 'V';
        cdlProduct.Visibility = 'AllUsers';
        insert cdlProduct;
        
        PricebookEntry pbeStd = new PricebookEntry();
        pbeStd.Pricebook2Id = Test.getStandardPricebookId();
        pbeStd.IsActive = true;
        pbeStd.UnitPrice = 1.01;
        pbeStd.Product2Id = p.Id;
        insert(pbeStd);
        
        PricebookEntry pbe = new PricebookEntry();
        pbe.Pricebook2Id = pb.Id;
        pbe.IsActive = true;
        pbe.UnitPrice = 0.99;
        pbe.Product2Id = p.Id;
        insert(pbe);
        
        /*
OpportunityLineItem oli = new OpportunityLineItem();
oli.Quantity = 1;
oli.PricebookEntryId = pbe.Id;
oli.UnitPrice = 0.99;
oli.Description = 'DESCRIBED';
oli.OpportunityId
*/
        
        QuoteLineItem qli = new QuoteLineItem();
        //qli.Country_of_Origin_Editable__c = 'United States';
        //qli.HTS_Code_Editable__c = '1000.1.2.2';
        //qli.OpportunityLineItemId = oli.Id;
        qli.QuoteId = q.Id;
        qli.UnitPrice = 0.99;
        qli.PricebookEntryId = pbe.Id;
        qli.Quantity = 1;
        
        insert(qli);
        
        ContentVersion contentVersion = new ContentVersion(
            Title          = 'another picture',
            PathOnClient   = 'Pic.jpg',
            VersionData    = Blob.valueOf('Test Content'),
            IsMajorVersion = true);
        
        insert contentVersion;
        
        List<ContentDocument> documents2 = [SELECT Id, Title, LatestPublishedVersionId FROM ContentDocument WHERE Title = 'another picture'];
        
        //create ContentDocumentLink  record
        
        ContentDocumentLink cdl = new ContentDocumentLink();
        cdl.LinkedEntityId = q.Id;
        cdl.ContentDocumentId = documents2[0].Id;
        cdl.ShareType = 'V';
        cdl.Visibility = 'AllUsers';
        
        insert cdl;
        
        
        PageReference pageRef = Page.OpportunityQuoteEmail_VFPage;
        Test.setCurrentPage(pageRef);
        pageRef.getParameters().put('Id', String.valueOf(o.Id));
        ApexPages.StandardController sc = new ApexPages.StandardController(o);
        
        
        
        OpportunityQuoteEmail_VFPage_Controller conn = new OpportunityQuoteEmail_VFPage_Controller(sc);
        
        conn.bccAddressString = 'patrick.currin@redoakrun.com';
        
        conn.fileAttachment1Name = contentVersion.title;
        conn.fileAttachment1Body = contentVersion.VersionData;
        conn.fileAttachment2Name = contentVersion.title;
        conn.fileAttachment2Body = contentVersion.VersionData;
        conn.fileAttachment3Name = contentVersion.title;
        conn.fileAttachment3Body = contentVersion.VersionData;
        
        Test.startTest();
        
        PageReference sendPage = conn.send();
        
        Test.stopTest();
        
        EmailMessagesRelationStation station = new EmailMessagesRelationStation(o.Id);
        
        system.assert(station.hasMessages() == true);
        
        List<EmailMessage> messages = station.getMessages();
        system.assert(!messages.isEmpty());
        
        system.debug('em2 Yesterday\'s Message ? ' + (em2.Id == station.getMessages()[1].Id));
        system.debug('em2 Yesterday\'s Message > ' + (em2.MessageDate + ' - ' + em2.Subject));
        system.assertNotEquals(em2.Id, station.getLatestRelatedMessage().Id);
        
        system.debug('em 5 Days Back Message ? ' + (em.Id == station.getOldestRelatedMessage().Id));
        system.assert(em.Id == station.getOldestRelatedMessage().Id);
        
        String previousHTMLBodies = station.generatePreviousRichTextHTMLBodies();
        
        system.debug('previousHTMLBodies: ' + previousHTMLBodies);
        system.debug(previousHTMLBodies);
        
        String answer = '';
        
        for(EmailMessage email : station.getMessages()){
            if(email.HTMLBody != null){    
            	answer += '<br><br>' + email.MessageDate + '<br>' + email.HtmlBody;
            }
        
        }
        
        system.assertEquals(answer, previousHTMLBodies);
        
        
        
        
    }
    
}