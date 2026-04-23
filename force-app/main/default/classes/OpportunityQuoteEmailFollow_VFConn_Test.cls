@isTest
public class OpportunityQuoteEmailFollow_VFConn_Test {

    static testmethod void touchConn(){
        
        Profile p = [SELECT Id FROM Profile WHERE Name='T&S Brass - System Administrator']; 
        User u = new User(Alias = 'standt', Email='salesforceadmin@tsbrass.com', 
            EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US', 
            LocaleSidKey='en_US', ProfileId = p.Id, 
            TimeZoneSidKey='America/New_York', UserName='salesforceadmin@tsbrass.com');

        insert(u);
        
        Opportunity o = new Opportunity();
        o.StageName = 'Follow-Up';
        o.Quote_Email_Initial_Send_Date__c = Date.today().addDays(-2);
        o.Name = 'TestOpp';
        o.Salesperson__c = u.Id;
        o.CloseDate = Date.Today().addDays(1);
        o.Quote_Email_Followup_Interval_Days__c = 30;
        o.Quote_Email_Initial_Body_RichText__c = 'TEST BODY RICH TEXT';
        o.Quote_Email_Next_Followup_Date__c = Date.today();
        o.Quote_Email_Standard_Followup_Subject__c = 'TEST FOLLOWUP SUBJECT';
        o.Quote_Email_Standard_Followup_Blurb__c = 'TEST FOLLOWUP BLURB/HTMLBODY';
        o.RecordTypeId = Schema.SObjectType.Opportunity.getRecordTypeInfosByName().get('MEA Projects').getRecordTypeId();
        insert(o);
        
        
        
        EmailMessage m90DaysBack = new EmailMessage();
        m90DaysBack.Subject = '90 Days Back Quote';
        m90DaysBack.ToAddress = 'patrick@bb.com';
        m90DaysBack.FromAddress = 'mark@bb.com';
        m90DaysBack.CcAddress = 'pcurrin@tsbrass.com';
        m90DaysBack.BccAddress = 'aneese@tsbrass.com';
        m90DaysBack.HtmlBody = '</br>Test 90';
        m90DaysBack.MessageDate = Datetime.now().addDays(-90);
        m90DaysBack.RelatedToId = o.Id;
        insert(m90DaysBack);
        
        
        EmailMessage m85DaysBack = new EmailMessage();
        m85DaysBack.Subject = '85 Days Back Quote';
        m85DaysBack.ToAddress = 'patrick@bb.com';
        m85DaysBack.FromAddress = 'mark@bb.com';
        m85DaysBack.CcAddress = 'pcurrin@tsbrass.com';
        m85DaysBack.BccAddress = 'aneese@tsbrass.com';
        m85DaysBack.HtmlBody = '</br>Test 85';
        m85DaysBack.MessageDate = Datetime.now().addDays(-85);
        m85DaysBack.RelatedToId = o.Id;
        insert(m85DaysBack);
        
        
        EmailMessage m80DaysBack = new EmailMessage();
        m80DaysBack.Subject = '80 Days Back Quote';
        m80DaysBack.ToAddress = 'patrick@bb.com';
        m80DaysBack.FromAddress = 'mark@bb.com';
        m80DaysBack.CcAddress = 'pcurrin@tsbrass.com';
        m80DaysBack.BccAddress = 'aneese@tsbrass.com';
        m80DaysBack.HtmlBody = '</br>Test 80';
        m80DaysBack.MessageDate = Datetime.now().addDays(-80);
        m80DaysBack.RelatedToId = o.Id;
        insert(m80DaysBack);
        
        
        PageReference thePage = Page.OpportunityQuoteEmailFollowupOneOff;
        thePage.getParameters().put('id', o.id);
        
        Test.setCurrentPage(thePage);
        
        Test.startTest();
        
        ApexPages.StandardController stdController = new ApexPages.StandardController(o);
        OpportunityQuoteEmailFollow_VFPage_Conn conn = new OpportunityQuoteEmailFollow_VFPage_Conn(stdController);
        conn.send();
        
        Test.stopTest();
        
    }
    
}