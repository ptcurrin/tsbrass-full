@isTest//(SeeAllData=true)
public class EventRelationValidatorTest {

    static testmethod void addEventGoodAccountRelationship(){
        
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
        
        //
        Event e = new Event();
        e.WhatId = a2.Id;
        e.WhoId = c1.Id;
        e.Subject = 'Meeting';
        e.DurationInMinutes = 60;
        e.ActivityDateTime = Datetime.Now() + 100;
        e.Description = 'TEST DESCRIPTION';
        e.Type = 'Internal Meeting';
        Database.SaveResult sr = Database.insert(e);
        
        system.assert(sr.isSuccess());
        
    }




    
    static testmethod void addEventBadAccountRelationship_But_NoTYPE_PASSES(){
        
        
        
        //insert rep agency account #1 (Only the Syteline Integration User can create Rep Agency Accounts)
            Account a1 = new Account();
            a1.Name = 'Test Prospect';       
            a1.External_Id__c='12345';
            a1.SLSMan_EXT_ID__c='SMA00001';
            a1.Type='Rep Agency';
            a1.RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByName().get('Rep Agency').getRecordTypeId();
            insert a1;     
        
        
        User Niko = [SELECT Id FROM User WHERE Name = 'Nikolai Hinzer' LIMIT 1];
        
        Event e;
        
        system.runas(Niko){
            
                         
            
            //insert prospect account #2
            Account a2 = new Account();
            a2.Name = 'Test Prospect';
            a2.RSM__c='SMA00867';
            a2.External_Id__c='12346';
            a2.SLSMan_Rep_Agency__c=a1.Id;
            a2.Type='Installer';   
            a2.RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByName().get('Prospect').getRecordTypeId();
            insert a2; 
            
            Contact c1 = new Contact();
            c1.FirstName = 'Paddy';
            c1.Lastname = 'Currin';
            c1.AccountId = a2.Id; // assign contact to account #2, so it won't trigger the addError 
            c1.Title = 'Bassist';
            c1.Email = 'test@test.com';
            c1.OtherPhone = '9999999999';
            c1.Phone = '9999999999';
            insert(c1);
            
            e = new Event();
            e.WhatId = a2.Id; // assign event account #2 and 
            e.WhoId = c1.Id; // contact #1
            e.Subject = 'Meeting';
            e.DurationInMinutes = 60;
            e.ActivityDateTime = Datetime.Now() + 100;
            //e.Type = 'Internal Meeting';   <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< NO TYPE ... SHOULD PASS THROUGH REQUIREMENT CODE
            e.Description = 'TEST DESCRIPTION';
            e.Meeting_Preparation__c = 'Meeting Preparation is standing in for Description because Sales!!! ';
            
            Database.SaveResult sr; 
            
            insert(e);
            
        }
            
            // Attempt to add a relation, which should trigger resave on the event, and voila!!
            Test.startTest();
            
            Contact c2 = new Contact();
            c2.FirstName = 'Paddy2';
            c2.Lastname = 'Currin2';
            c2.AccountId = a1.Id; // assign contact to account #1
            c2.Title = 'Guitarist';
            c2.Email = 'test@test.com';
            c2.OtherPhone = '9999999999';
            c2.Phone = '9999999999';
            insert(c2);
            
        
            
            EventRelation er = new EventRelation();
            er.EventId = e.Id;
            er.RelationId = c2.Id;
            er.IsInvitee = false;
            er.IsParent = true;
            
            try{
                
                
                
                
                insert(er);
                
                
                system.runas(Niko){
                	update(e);
                }
                
                
                system.assert(true); // <<<<< will not fail to update
                
            }catch(Exception ex){
                
                system.assert(false); // <<<<<<<<< if it fails, that's wrong in this case
                
            }
            
            Test.stopTest();
            
            
        
    }
    



    
    static testmethod void addEventBadAccountRelationship(){
        
        //insert rep agency account #1
        Account a1 = new Account();
        a1.Name = 'Test Prospect';       
        a1.External_Id__c='12345';
        a1.SLSMan_EXT_ID__c='SMA00001';
        a1.Type='Rep Agency';
        a1.RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByName().get('Rep Agency').getRecordTypeId();
        insert a1;                  
        
        //insert prospect account #2
        Account a2 = new Account();
        a2.Name = 'Test Prospect';
        a2.RSM__c='SMA00867';
        a2.External_Id__c='12346';
        a2.SLSMan_Rep_Agency__c=a1.Id;
        a2.Type='Installer';   
        a2.RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByName().get('Prospect').getRecordTypeId();
        insert a2; 
        
        Contact c1 = new Contact();
        c1.FirstName = 'Paddy';
        c1.Lastname = 'Currin';
        c1.AccountId = a2.Id; // assign contact to account #2, so it won't trigger the addError 
        c1.Title = 'Bassist';
        c1.Email = 'test@test.com';
        c1.OtherPhone = '9999999999';
        c1.Phone = '9999999999';
        insert(c1);
        
        Event e = new Event();
        e.WhatId = a2.Id; // assign event account #2 and 
        e.WhoId = c1.Id; // contact #1
        e.Subject = 'Meeting';
        e.DurationInMinutes = 60;
        e.ActivityDateTime = Datetime.Now() + 100;
        e.Type = 'Internal Meeting';
        e.Description = 'TEST DESCRIPTION';
        
        Database.SaveResult sr; 
        
        insert(e);
        
        // Attempt to add a relation, which should trigger resave on the event, and voila!!
        Test.startTest();
        
        Contact c2 = new Contact();
        c2.FirstName = 'Paddy2';
        c2.Lastname = 'Currin2';
        c2.AccountId = a1.Id; // assign contact to account #1
        c2.Title = 'Guitarist';
        c2.Email = 'test@test.com';
        c2.OtherPhone = '9999999999';
        c2.Phone = '9999999999';
        insert(c2);
        
        EventRelation er = new EventRelation();
        er.EventId = e.Id;
        er.RelationId = c2.Id;
        er.IsInvitee = false;
        er.IsParent = true;
        
        try{
            
            User Niko = [SELECT Id FROM User WHERE Name = 'Nikolai Hinzer' LIMIT 1];
            
            system.runas(Niko){
        		insert(er);
            }
            update(e);
            
            system.assert(false);

        }catch(Exception ex){
            
            system.assert(true);

        }
        
        Test.stopTest();
        
    }
    
    
    
    
    
    static testmethod void addEventBadAccountRelationship_NoEventConditionSet(){
        
        //insert rep agency account #1
        Account a1 = new Account();
        a1.Name = 'Test Prospect';       
        a1.External_Id__c='12345';
        a1.SLSMan_EXT_ID__c='SMA00001';
        a1.Type='Rep Agency';
        a1.RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByName().get('Rep Agency').getRecordTypeId();
        insert a1;                  
        
        //insert prospect account #2
        Account a2 = new Account();
        a2.Name = 'Test Prospect';
        a2.RSM__c='SMA00867';
        a2.External_Id__c='12346';
        a2.SLSMan_Rep_Agency__c=a1.Id;
        a2.Type='Installer';   
        a2.RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByName().get('Prospect').getRecordTypeId();
        insert a2; 
        
        Contact c1 = new Contact();
        c1.FirstName = 'Paddy';
        c1.Lastname = 'Currin';
        c1.AccountId = a2.Id; // assign contact to account #2, so it won't trigger the addError 
        c1.Title = 'Bassist';
        c1.Email = 'test@test.com';
        c1.OtherPhone = '9999999999';
        c1.Phone = '9999999999';
        insert(c1);
        
        Event e = new Event();
        e.WhatId = a2.Id; // assign event account #2 and 
        e.WhoId = c1.Id; // contact #1
        e.Subject = 'Meeting';
        e.DurationInMinutes = 60;
        e.ActivityDateTime = Datetime.Now() + 100;
        e.Type = 'Internal Meeting';
        e.Description = 'TEST DESCRIPTION';
        
        Database.SaveResult sr; 
        
        insert(e);
        
        // Attempt to add a relation, which should trigger resave on the event, and voila!!
        Test.startTest();
        
        Contact c2 = new Contact();
        c2.FirstName = 'Paddy2';
        c2.Lastname = 'Currin2';
        c2.AccountId = a1.Id; // assign contact to account #1
        c2.Title = 'Guitarist';
        c2.Email = 'test@test.com';
        c2.OtherPhone = '9999999999';
        c2.Phone = '9999999999';
        insert(c2);
        
        EventRelation er = new EventRelation();
        er.EventId = e.Id;
        er.RelationId = c2.Id;
        er.IsInvitee = false;
        er.IsParent = true;
        
        try{
            
            // Run as Integration User so the permission set doesn't force event conditions
            
            //User Niko = [SELECT Id FROM User WHERE Name = 'Nikolai Hinzer' LIMIT 1];
            
            //system.runas(Niko){
        		insert(er);
            //}
            update(e);
            
            system.assert(true);

        }catch(Exception ex){
            
            system.assert(false);

        }
        
        Test.stopTest();
        
    }
    
    
    
    
    static testmethod void addEventGoodAccountRelationshipExtraEntities(){
        
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
        
        
        
        //
        Event e = new Event();
        e.WhatId = a2.Id;
        e.WhoId = c1.Id;
        e.Subject = 'Meeting';
        e.DurationInMinutes = 60;
        e.ActivityDateTime = Datetime.Now() + 100;
        e.Description = 'TEST DESCRIPTION';
        e.Type = 'Internal Meeting';
        Database.SaveResult sr = Database.insert(e);
        
        system.assert(sr.isSuccess());
        
    }
    
    /*
    
    static testmethod void addEventHalfBadRelationship(){
        
        //insert rep agency account
        Account a1 = new Account();
        a1.Name = 'Test Prospect';       
        a1.External_Id__c='12345';
        a1.SLSMan_EXT_ID__c='SMA00001';
        a1.Type='Rep Agency';
        a1.RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByName().get('Rep Agency').getRecordTypeId();
        insert a1;                  
        
        //insert prospect
        Account a2 = [SELECT Id, Name FROM Account WHERE Name = 'Red Oak Run, LLC'];           
        
        Contact c1 = [SELECT Id FROM Contact WHERE Name = 'Patrick Currin'];
        Contact c2 = [SELECT Id From Contact WHERE Name = 'Jon Godwin'];
        
        system.assert(c1 != null);
        system.assert(c2 != null);
        
        //
        Event e = new Event();
        e.WhatId = a2.Id;
        e.WhoId = c1.Id;
        e.Subject = 'Meeting';
        e.DurationInMinutes = 60;
        e.ActivityDateTime = Datetime.Now() + 100;
        e.Description = 'TEST DESCRIPTION';
        
        Database.SaveResult sr = Database.insert(e);
        
        system.assert(sr.isSuccess());
        
        EventRelation er = new EventRelation();
        er.RelationId = c2.Id;
        er.EventId = e.Id;
        insert(er);
        
        
        
    }
    */
}