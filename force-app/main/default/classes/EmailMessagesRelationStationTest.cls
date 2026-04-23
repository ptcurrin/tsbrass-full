@isTest
public class EmailMessagesRelationStationTest {

    
    
    static testmethod void Bootup(){
        
        Opportunity o = new Opportunity();
        o.StageName = 'Follow-Up';
        o.Name = 'TestOpp';
        o.CloseDate = Date.Today().addDays(1);
        o.Quote_Email_Initial_Send_Date__c = Date.today().addDays(-1);
        insert(o);
        
        
        EmailMessagesRelationStation station = new EmailMessagesRelationStation(o.Id);
        
        system.assert(station.hasMessages() == false);
                
    }
    
    static testmethod void Bootup_NoPreviousBodyStringsReturned(){
        
        Opportunity o = new Opportunity();
        o.StageName = 'Follow-Up';
        o.Name = 'TestOpp';
        o.CloseDate = Date.Today().addDays(1);
        o.Quote_Email_Initial_Send_Date__c = Date.today().addDays(-1);
        o.Quote_Email_Body_Do_Not_Append_Previous__c = true;
        insert(o);
        
        EmailMessage m90DaysBack = new EmailMessage();
        m90DaysBack.Subject = '90 Days Back Quote';
        m90DaysBack.ToAddress = 'patrick@bb.com';
        m90DaysBack.FromAddress = 'mark@bb.com';
        m90DaysBack.BccAddress = 'aneese@tsbrass.com';
        m90DaysBack.HtmlBody = '</br>Test 90';
        m90DaysBack.MessageDate = Datetime.now().addDays(-90);
        m90DaysBack.RelatedToId = o.Id;
        insert(m90DaysBack);
        
        
        EmailMessage m85DaysBack = new EmailMessage();
        m85DaysBack.Subject = '85 Days Back Quote';
        m85DaysBack.ToAddress = 'patrick@bb.com';
        m85DaysBack.FromAddress = 'mark@bb.com';
        m85DaysBack.BccAddress = 'aneese@tsbrass.com';
        m85DaysBack.HtmlBody = '</br>Test 85';
        m85DaysBack.MessageDate = Datetime.now().addDays(-85);
        m85DaysBack.RelatedToId = o.Id;
        insert(m85DaysBack);
        
        
        EmailMessage m80DaysBack = new EmailMessage();
        m80DaysBack.Subject = '80 Days Back Quote';
        m80DaysBack.ToAddress = 'patrick@bb.com';
        m80DaysBack.FromAddress = 'mark@bb.com';
        m80DaysBack.BccAddress = 'aneese@tsbrass.com';
        m80DaysBack.HtmlBody = '</br>Test 80';
        m80DaysBack.MessageDate = Datetime.now().addDays(-80);
        m80DaysBack.RelatedToId = o.Id;
        insert(m80DaysBack);
        
        Test.startTest();
        EmailMessagesRelationStation station = new EmailMessagesRelationStation(o.Id);
        Test.stopTest();
        
        system.assert(station.hasMessages() == true);
        
        List<EmailMessage> messages = station.getMessages();
        system.assert(!messages.isEmpty());
        
        system.debug('Get 80 Days Back Message ? ' + (m80DaysBack.Id == station.getLatestRelatedMessage().Id));
        system.assert(m80DaysBack.Id == station.getLatestRelatedMessage().Id);
        system.debug('Get 85 Days Back Message ? ' + (m85DaysBack.Id == station.getMessages()[1].Id));
        system.assert(m85DaysBack.Id == station.getMessages()[1].Id);
        system.debug('Get 90 Days Back Message ? ' + (m90DaysBack.Id == station.getOldestRelatedMessage().Id));
        system.assert(m90DaysBack.Id == station.getOldestRelatedMessage().Id);
        
        system.assertEquals('', station.generatePreviousRichTextHTMLBodies());
                
    }
    
    
    
    
    static testmethod void NoMessages(){
        
        Opportunity o = new Opportunity();
        o.StageName = 'Follow-Up';
        o.Name = 'TestOpp';
        o.CloseDate = Date.Today().addDays(1);
        o.Quote_Email_Initial_Send_Date__c = Date.today().addDays(-1);
        insert(o);
        
        
        EmailMessagesRelationStation station = new EmailMessagesRelationStation(o.Id);
        
        system.assert(station.hasMessages() == false);
        
        List<EmailMessage> messages = station.getMessages();
        system.assert(messages.isEmpty());
        
    }
    
    
    static testmethod void OneMessage(){
        
        Opportunity o = new Opportunity();
        o.StageName = 'Follow-Up';
        o.Name = 'TestOpp';
        o.CloseDate = Date.Today().addDays(1);
        o.Quote_Email_Initial_Send_Date__c = Date.today().addDays(-1);
        insert(o);
        
        EmailMessage m90DaysBack = new EmailMessage();
        m90DaysBack.Subject = '90 Days Back Quote';
        m90DaysBack.ToAddress = 'patrick@bb.com';
        m90DaysBack.FromAddress = 'mark@bb.com';
        m90DaysBack.BccAddress = 'aneese@tsbrass.com';
        m90DaysBack.HtmlBody = '</br>Test 90';
        m90DaysBack.MessageDate = Datetime.now().addDays(-90);
        m90DaysBack.RelatedToId = o.Id;
        insert(m90DaysBack);
        
        
        EmailMessage m85DaysBack = new EmailMessage();
        m85DaysBack.Subject = '85 Days Back Quote';
        m85DaysBack.ToAddress = 'patrick@bb.com';
        m85DaysBack.FromAddress = 'mark@bb.com';
        m85DaysBack.BccAddress = 'aneese@tsbrass.com';
        m85DaysBack.HtmlBody = '</br>Test 85';
        m85DaysBack.MessageDate = Datetime.now().addDays(-85);
        m85DaysBack.RelatedToId = o.Id;
        insert(m85DaysBack);
        
        
        EmailMessage m80DaysBack = new EmailMessage();
        m80DaysBack.Subject = '80 Days Back Quote';
        m80DaysBack.ToAddress = 'patrick@bb.com';
        m80DaysBack.FromAddress = 'mark@bb.com';
        m80DaysBack.BccAddress = 'aneese@tsbrass.com';
        m80DaysBack.HtmlBody = '</br>Test 80';
        m80DaysBack.MessageDate = Datetime.now().addDays(-80);
        m80DaysBack.RelatedToId = o.Id;
        insert(m80DaysBack);
        
        Test.startTest();
        EmailMessagesRelationStation station = new EmailMessagesRelationStation(o.Id);
        Test.stopTest();
        
        system.assert(station.hasMessages() == true);
        
        List<EmailMessage> messages = station.getMessages();
        system.assert(!messages.isEmpty());
        
        system.debug('Get 80 Days Back Message ? ' + (m80DaysBack.Id == station.getLatestRelatedMessage().Id));
        system.assert(m80DaysBack.Id == station.getLatestRelatedMessage().Id);
        system.debug('Get 85 Days Back Message ? ' + (m85DaysBack.Id == station.getMessages()[1].Id));
        system.assert(m85DaysBack.Id == station.getMessages()[1].Id);
        system.debug('Get 90 Days Back Message ? ' + (m90DaysBack.Id == station.getOldestRelatedMessage().Id));
        system.assert(m90DaysBack.Id == station.getOldestRelatedMessage().Id);
        
    }
    
    
    
    static testmethod void SeveralMessages(){
        
        Opportunity o = new Opportunity();
        o.StageName = 'Follow-Up';
        o.Name = 'TestOpp';
        o.CloseDate = Date.Today().addDays(1);
        o.Quote_Email_Initial_Send_Date__c = Date.today().addDays(-1);
        insert(o);
        
        EmailMessage m90DaysBack = new EmailMessage();
        m90DaysBack.Subject = '90 Days Back Quote';
        m90DaysBack.ToAddress = 'patrick@bb.com';
        m90DaysBack.FromAddress = 'mark@bb.com';
        m90DaysBack.BccAddress = 'aneese@tsbrass.com';
        m90DaysBack.HtmlBody = '</br>Test 90 Days Ago HTMLBody';
        m90DaysBack.MessageDate = Datetime.now().addDays(-90);
        m90DaysBack.RelatedToId = o.Id;
        insert(m90DaysBack);
        
        
        EmailMessage m85DaysBack = new EmailMessage();
        m85DaysBack.Subject = '85 Days Back Quote';
        m85DaysBack.ToAddress = 'patrick@bb.com';
        m85DaysBack.FromAddress = 'mark@bb.com';
        m85DaysBack.BccAddress = 'aneese@tsbrass.com';
        m85DaysBack.HtmlBody = '</br>Test 85 Days Ago HTMLBody';
        m85DaysBack.MessageDate = Datetime.now().addDays(-85);
        m85DaysBack.RelatedToId = o.Id;
        insert(m85DaysBack);
        
        
        EmailMessage m80DaysBack = new EmailMessage();
        m80DaysBack.Subject = '80 Days Back Quote';
        m80DaysBack.ToAddress = 'patrick@bb.com';
        m80DaysBack.FromAddress = 'mark@bb.com';
        m80DaysBack.BccAddress = 'aneese@tsbrass.com';
        m80DaysBack.HtmlBody = '</br>Test 80 Days Ago HTMLBody';
        m80DaysBack.MessageDate = Datetime.now().addDays(-80);
        m80DaysBack.RelatedToId = o.Id;
        insert(m80DaysBack);
        
        Test.startTest();
        EmailMessagesRelationStation station = new EmailMessagesRelationStation(o.Id);
        Test.stopTest();
        
        system.assert(station.hasMessages() == true);
        
        List<EmailMessage> messages = station.getMessages();
        system.assert(!messages.isEmpty());
        
        system.debug('Get 80 Days Back Message ? ' + (m80DaysBack.Id == station.getLatestRelatedMessage().Id));
        system.assert(m80DaysBack.Id == station.getLatestRelatedMessage().Id);
        system.debug('Get 85 Days Back Message ? ' + (m85DaysBack.Id == station.getMessages()[1].Id));
        system.assert(m85DaysBack.Id == station.getMessages()[1].Id);
        system.debug('Get 90 Days Back Message ? ' + (m90DaysBack.Id == station.getOldestRelatedMessage().Id));
        system.assert(m90DaysBack.Id == station.getOldestRelatedMessage().Id);
        
        String previousHTMLBodies = station.generatePreviousRichTextHTMLBodies();
        
        system.debug('previousHTMLBodies: ');
        system.debug(previousHTMLBodies);
        
        String answer = 
            
            '<br><br>' + m80DaysBack.MessageDate + '<br>' + m80DaysBack.HtmlBody +
            '<br><br>' + m85DaysBack.MessageDate + '<br>' + m85DaysBack.HtmlBody +
            '<br><br>' + m90DaysBack.MessageDate + '<br>' + m90DaysBack.HtmlBody;
        
        system.assertEquals(answer, previousHTMLBodies);
        
        
    }
    
}