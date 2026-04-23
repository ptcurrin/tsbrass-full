@isTest
public class EventGenericTests {

    // Need to Have a positive test showing the location not filling in and not throwing errors with no WhatId
    static testmethod void Does_EventRelation_Fill_WhoId_Yes(){
        
        //insert rep agency account
        Account a1 = new Account();
        a1.Name = 'Test Prospect';       
        a1.External_Id__c='12345';
        a1.SLSMan_EXT_ID__c='SMA00001';
        a1.Type='Rep Agency';
        a1.RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByName().get('Rep Agency').getRecordTypeId();
        insert a1;                  
        
        //insert prospect
        Account a2 = new Account();
        a2.Name = 'Test Prospect';
        a2.RSM__c='SMA00867';
        a2.External_Id__c='12346';
        a2.SLSMan_Rep_Agency__c=a1.Id;
        a2.Type='Installer';   
        a2.RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByName().get('Prospect').getRecordTypeId();
        a2.Address_1__c = '115';
        a2.Address_2__c = 'Pine';
        a2.Address_3__c = 'Cone';
        a2.Address_4__c = 'Drive';
        a2.Billing_City__c = 'Oxford';
        a2.Billing_State__c = 'NC';
        a2.Billing_Zip__c = '27565';
        a2.Billing_Country__c = 'United States';
        insert a2; 
        
        Contact c1 = new Contact();
        c1.FirstName = 'Paddy';
        c1.Lastname = 'Currin';
        c1.AccountId = a2.Id;
        c1.Title = 'Bassist';
        c1.Email = 'test@test.com';
        c1.OtherPhone = '9999999999';
        c1.Phone = '9999999999';
        insert(c1);
        
        Contact c2 = new Contact();
        c2.FirstName = 'Mark';
        c2.Lastname = 'Belk';
        c2.AccountId = a2.Id;
        c2.Title = 'Guitarist';
        c2.Email = 'test@test.com';
        c2.OtherPhone = '9999999999';
        c2.Phone = '9999999999';
        insert(c2);
        
        Contact c3 = new Contact();
        c3.FirstName = 'John';
        c3.Lastname = 'Dunkle';
        c3.AccountId = a2.Id;
        c3.Title = 'Conductor';
        c3.Email = 'test@test.com';
        c3.OtherPhone = '9999999999';
        c3.Phone = '9999999999';
        insert(c3);
        
        
        Event e = new Event();
        
        // We fill in the WhatId with the account Id but not the whoId ...
        // e.WhoId = c1.Id;
        
        e.WhatId = a2.Id;
        e.Subject = 'Meeting';
        e.DurationInMinutes = 60;
        e.ActivityDateTime = Datetime.Now() + 100;
        e.Description = 'Discussion of Last Meeting';
        e.Type = 'Internal Meeting';
        
        
        insert(e);
        
        List<EventRelation> relations = new List<EventRelation>();
        
        EventRelation er1 = new EventRelation();
        er1.EventId = e.Id;
        er1.IsWhat = false;
        er1.IsInvitee = true;
        er1.IsParent = true;
        er1.RelationId = c1.Id;
        
        EventRelation er2 = new EventRelation();
        er2.EventId = e.Id;
        er2.IsWhat = false;
        er2.IsInvitee = true;
        er2.IsParent = true;
        er2.RelationId = c2.Id;
        
        EventRelation er3 = new EventRelation();
        er3.EventId = e.Id;
        er3.IsWhat = false;
        er3.IsInvitee = true;
        er3.IsParent = true;
        er3.RelationId = c3.Id;
        
        relations.add(er1);
        relations.add(er2);
        relations.add(er3);
        
        insert(relations);
        
        Test.startTest();
        
        Test.stopTest();
        
        
        try{
            List<EventRelation> relRes = [SELECT Id FROM EventRelation WHERE EventId = :e.Id];
        
        	system.assert(relRes.size() == relations.size() + 1);
        	
            Event eventRes = [SELECT Id, WhoId, WhoCount FROM Event WHERE Id = :e.Id];
            
            system.assert(eventRes.WhoId != null);
            //system.assertEquals(2, eventRes.WhoCount); // will not work because we do not have shared activities enabled
        	system.assert(eventRes.WhoId == c1.Id);
            
        }catch(Exception ex){
            system.assert(false);
        }
        
    }
    

    // Need to Have a positive test showing the location not filling in and not throwing errors with no WhatId
    static testmethod void QUESTION_Is_First_Event_WhoId_Sticky_isParentAllTrue(){
        
        //insert rep agency account
        Account a1 = new Account();
        a1.Name = 'Test Prospect';       
        a1.External_Id__c='12345';
        a1.SLSMan_EXT_ID__c='SMA00001';
        a1.Type='Rep Agency';
        a1.RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByName().get('Rep Agency').getRecordTypeId();
        insert a1;                  
        
        //insert prospect
        Account a2 = new Account();
        a2.Name = 'Test Prospect';
        a2.RSM__c='SMA00867';
        a2.External_Id__c='12346';
        a2.SLSMan_Rep_Agency__c=a1.Id;
        a2.Type='Installer';   
        a2.RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByName().get('Prospect').getRecordTypeId();
        a2.Address_1__c = '115';
        a2.Address_2__c = 'Pine';
        a2.Address_3__c = 'Cone';
        a2.Address_4__c = 'Drive';
        a2.Billing_City__c = 'Oxford';
        a2.Billing_State__c = 'NC';
        a2.Billing_Zip__c = '27565';
        a2.Billing_Country__c = 'United States';
        insert a2; 
        
        Contact c1 = new Contact();
        c1.FirstName = 'Paddy';
        c1.Lastname = 'Currin';
        c1.AccountId = a2.Id;
        c1.Title = 'Bassist';
        c1.Email = 'test@test.com';
        c1.OtherPhone = '9999999999';
        c1.Phone = '9999999999';
        insert(c1);
        
        Contact c2 = new Contact();
        c2.FirstName = 'Mark';
        c2.Lastname = 'Belk';
        c2.AccountId = a2.Id;
        c2.Title = 'Guitarist';
        c2.Email = 'test@test.com';
        c2.OtherPhone = '9999999999';
        c2.Phone = '9999999999';
        insert(c2);
        
        Contact c3 = new Contact();
        c3.FirstName = 'John';
        c3.Lastname = 'Dunkle';
        c3.AccountId = a2.Id;
        c3.Title = 'Conductor';
        c3.Email = 'test@test.com';
        c3.OtherPhone = '9999999999';
        c3.Phone = '9999999999';
        insert(c3);
        
        
        Event e = new Event();
        
        // We fill in the WhatId with the account Id but not the whoId ...
        // e.WhoId = c1.Id;
        
        e.WhatId = a2.Id;
        e.Subject = 'Meeting';
        e.DurationInMinutes = 60;
        e.ActivityDateTime = Datetime.Now() + 100;
        e.Description = 'Discussion of Last Meeting';
        e.Type = 'Internal Meeting';
        
        insert(e);
        
        EventRelation er1 = new EventRelation();
        er1.EventId = e.Id;
        er1.IsWhat = false;
        er1.IsInvitee = true;
        er1.IsParent = true;
        er1.RelationId = c1.Id;
        insert(er1);
        
        
        
        Test.startTest();
        
        List<EventRelation> relations = new List<EventRelation>();
        
        EventRelation er2 = new EventRelation();
        er2.EventId = e.Id;
        er2.IsWhat = false;
        er2.IsInvitee = true;
        er2.IsParent = true;
        er2.RelationId = c2.Id;
        
        EventRelation er3 = new EventRelation();
        er3.EventId = e.Id;
        er3.IsWhat = false;
        er3.IsInvitee = true;
        er3.IsParent = true;
        er3.RelationId = c3.Id;
        
        relations.add(er2);
        relations.add(er3);
        
        insert(relations);
        
        Test.stopTest();
        
        
        
        try{
            List<EventRelation> relRes = [SELECT Id, EventId, RelationId, IsInvitee, isParent FROM EventRelation WHERE EventId = :e.Id];
        
            for(EventRelation er : relRes){
                system.debug('$$$ ' + er.eventId + ' ' + er.RelationId + ' ' + er.isInvitee + ' ' + er.isParent);
            }
            
        	system.assertEquals(4, relRes.size()); // 1 Acct, 3 Cons
        	
            Event eventRes = [SELECT Id, WhoId, WhoCount FROM Event WHERE Id = :e.Id];
            
            system.assert(eventRes.WhoId != null);
            //system.assertEquals(2, eventRes.WhoCount); // will not work because we do not have shared activities enabled
        	system.assert(eventRes.WhoId == c1.Id);
            
        }catch(Exception ex){
            system.assert(false);
        }
        
    }
    
    
    
    static testmethod void canYouMakeTwoEventRelationsWithTheSameRelationId(){
        
        //insert rep agency account
        Account a1 = new Account();
        a1.Name = 'Test Prospect';       
        a1.External_Id__c='12345';
        a1.SLSMan_EXT_ID__c='SMA00001';
        a1.Type='Rep Agency';
        a1.RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByName().get('Rep Agency').getRecordTypeId();
        insert a1;                  
        
        //insert prospect
        Account a2 = new Account();
        a2.Name = 'Test Prospect';
        a2.RSM__c='SMA00867';
        a2.External_Id__c='12346';
        a2.SLSMan_Rep_Agency__c=a1.Id;
        a2.Type='Installer';   
        a2.RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByName().get('Prospect').getRecordTypeId();
        a2.Address_1__c = '115';
        a2.Address_2__c = 'Pine';
        a2.Address_3__c = 'Cone';
        a2.Address_4__c = 'Drive';
        a2.Billing_City__c = 'Oxford';
        a2.Billing_State__c = 'NC';
        a2.Billing_Zip__c = '27565';
        a2.Billing_Country__c = 'United States';
        insert a2; 
        
        Contact c1 = new Contact();
        c1.FirstName = 'Paddy';
        c1.Lastname = 'Currin';
        c1.AccountId = a2.Id;
        c1.Title = 'Bassist';
        c1.Email = 'test@test.com';
        c1.OtherPhone = '9999999999';
        c1.Phone = '9999999999';
        insert(c1);
        
        Contact c2 = new Contact();
        c2.FirstName = 'Mark';
        c2.Lastname = 'Belk';
        c2.AccountId = a2.Id;
        c2.Title = 'Guitarist';
        c2.Email = 'test@test.com';
        c2.OtherPhone = '9999999999';
        c2.Phone = '9999999999';
        insert(c2);
        
        Contact c3 = new Contact();
        c3.FirstName = 'John';
        c3.Lastname = 'Dunkle';
        c3.AccountId = a2.Id;
        c3.Title = 'Conductor';
        c3.Email = 'test@test.com';
        c3.OtherPhone = '9999999999';
        c3.Phone = '9999999999';
        insert(c3);
        
        
        Event e = new Event();
        
        // We fill in the WhatId with the account Id but not the whoId ...
        // e.WhoId = c1.Id;
        
        e.WhatId = a2.Id;
        e.Subject = 'Meeting';
        e.DurationInMinutes = 60;
        e.ActivityDateTime = Datetime.Now() + 100;
        e.Description = 'Discussion of Last Meeting';
        e.Type = 'Internal Meeting';
        
        insert(e);
        
        EventRelation er1 = new EventRelation();
        er1.EventId = e.Id;
        er1.IsWhat = false;
        er1.IsInvitee = true; //. <<<<<<<<<<<<<
        er1.IsParent = true;
        er1.RelationId = c1.Id;
        insert(er1);
        
        Test.startTest();
        
        try{
            EventRelation erExtra = new EventRelation();
            erExtra.EventId = e.Id;
            erExtra.IsWhat = false;
            erExtra.IsInvitee = false;  //. <<<<<<<<<<<<<<<<
            erExtra.IsParent = true;
            erExtra.RelationId = c1.Id;
            insert(erExtra);
            system.assert(false);
        }catch(Exception ex){
            system.Assert(true);
        }
        
        Test.stopTest();
        
        
        
        /*
        List<EventRelation> relations = new List<EventRelation>();
        
        EventRelation er2 = new EventRelation();
        er2.EventId = e.Id;
        er2.IsWhat = false;
        er2.IsInvitee = true;
        er2.IsParent = true;
        er2.RelationId = c2.Id;
        
        EventRelation er3 = new EventRelation();
        er3.EventId = e.Id;
        er3.IsWhat = false;
        er3.IsInvitee = true;
        er3.IsParent = true;
        er3.RelationId = c3.Id;
        
        relations.add(er2);
        relations.add(er3);
        
        insert(relations);
        
        Test.stopTest();
        
        
        
        try{
            List<EventRelation> relRes = [SELECT Id, EventId, RelationId, IsInvitee, isParent FROM EventRelation WHERE EventId = :e.Id];
        
            for(EventRelation er : relRes){
                system.debug('$$$ ' + er.eventId + ' ' + er.RelationId + ' ' + er.isInvitee + ' ' + er.isParent);
            }
            
        	system.assertEquals(4, relRes.size()); // 1 Acct, 3 Cons
        	
            Event eventRes = [SELECT Id, WhoId, WhoCount FROM Event WHERE Id = :e.Id];
            
            system.assert(eventRes.WhoId != null);
            //system.assertEquals(2, eventRes.WhoCount); // will not work because we do not have shared activities enabled
        	system.assert(eventRes.WhoId == c1.Id);
            
        }catch(Exception ex){
            system.assert(false);
        }
        */
    }
    
}