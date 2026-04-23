@isTest
public class EventTriggerHandlerTest {

    static string converter(Account a ){

        String address = '';
                        
                        if(a.Address_1__c != null) { address += a.Address_1__c + ' '; }
                        if(a.Address_2__c != null) { address += a.Address_2__c + ' '; }
                        if(a.Address_3__c != null) { address += a.Address_3__c + ' '; }
                        if(a.Address_4__c != null) { address += a.Address_4__c + ' '; }
                        if(a.Billing_City__c != null) { address += a.Billing_City__c + ', '; }
                        if(a.Billing_State__c != null) { address += a.Billing_State__c + ' '; }
                        if(a.Billing_Zip__c != null) { address += a.Billing_Zip__c + ' '; }
                        if(a.Billing_Country__c != null) { address += a.Billing_Country__c + ' '; }

        return address;

    }

	

    // Need to Have a positive test showing the location not filling in and not throwing errors with no WhatId
    static testmethod void INSERT_LocationFill_NoAccount(){
        
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
        
        //
        Event e = new Event();
        //e.WhatId = a2.Id;
        e.WhoId = c1.Id;
        e.Subject = 'Meeting';
        e.DurationInMinutes = 60;
        e.ActivityDateTime = Datetime.Now() + 100;
        e.Description = 'Discussion of Last Meeting';
        e.Meeting_Preparation__c = 'PREPARED!!!';
        e.Type = 'Internal Meeting';
        
        try{
        	insert(e);
            e = [SELECT Id, Location FROM Event WHERE Id = :e.Id];
            
            system.assertEquals(null, e.Location);
            
            system.assert(true);
            
        }catch(Exception ex){
            system.assert(false);
        }
        
        // no errors on no WhatId ... good
        
    }
    


    // Need to Have a positive and test showing the location filling in and not throwing errors when blank
    static testmethod void INSERT_LocationFill_LocationBlank_AccountAddressFillsIn(){
        
        
        //PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Label = 'Calendar Event - NOT Internal Meeting Save Conditions'];
        //PermissionSetAssignment psa = new PermissionSetAssignment();
        //psa.AssigneeId = UserInfo.getUserId();
        //psa.PermissionSetId = ps.Id;
        //insert(psa);
        
        //Boolean isPSAPresent = (0 < [SELECT Count() FROM PermissionSetAssignment WHERE PermissionSet.Label = 'Calendar Event - NOT Internal Meeting Save Conditions' AND IsActive = true AND AssigneeId = :UserInfo.getUserId()]);
        //system.assert(isPSAPresent);
		
        
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
        
        
        //
        Event e = new Event();
        e.WhatId = a2.Id;
        e.WhoId = c1.Id;
        e.Subject = 'Meeting';
        e.DurationInMinutes = 60;
        e.ActivityDateTime = Datetime.Now() + 100;
        e.Description = 'Discussion of Last Meeting';
        e.Location = null;
        e.Meeting_Preparation__c = 'Meeting Preparation is now switched with Description';
        e.Type = 'In Person'; // would not work if it were internal meeting
        
            
        try{

            Test.startTest();
            
            User Niko = [SELECT Id FROM User WHERE Name = 'Nikolai Hinzer' LIMIT 1];
            
            system.runas(Niko){
        		insert(e);
            }
            Test.stopTest();

            
            system.assert(true);



            Event eRes = [SELECT Location FROM Event WHERE Id = :e.Id];
            system.assertEquals(converter(a2).normalizeSpace(), eRes.Location.normalizeSpace());


        }catch(Exception ex){
            system.assert(false);
        }
        
    }


    
    // Need to Have a negative and test showing the location NOT filling in and not throwing errors when filled already
    static testmethod void INSERT_LocationFill_LocationBlank_AddressStaysAsIs(){
        
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
        
        string testAnswer = 'TEST ADDRESS';
        
        Event e = new Event();
        e.WhatId = a2.Id;
        e.WhoId = c1.Id;
        e.Subject = 'Meeting';
        e.DurationInMinutes = 60;
        e.ActivityDateTime = Datetime.Now() + 100;
        e.Description = 'Discussion of Last Meeting';
        e.Meeting_Preparation__c = 'PREPARED!!!';
        e.Location = testAnswer;
        
        try{
        	insert(e);
            
            e = [SELECT Id, Location FROM Event WHERE Id = :e.Id];
            
            system.assertEquals(testAnswer, e.Location);
            
            
            system.assert(true);
        }catch(Exception ex){
            system.assert(false);
        }
        
    }
    
    
    
    // Need to Have a negative and test showing the location NOT filling in and not throwing errors when filled already
    static testmethod void UPDATE_LocationFill_LocationBlank_AddressStaysAsIs(){
        
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
        
        string testAnswer = 'TEST ADDRESS';
        
        Event e = new Event();
        e.WhatId = a2.Id;
        e.WhoId = c1.Id;
        e.Subject = 'Meeting';
        e.DurationInMinutes = 60;
        e.ActivityDateTime = Datetime.Now() + 100;
        e.Description = 'Discussion of Last Meeting';
        e.Meeting_Preparation__c = 'PREPARED!!!';
        e.Location = testAnswer;
        
        try{
        	insert(e);
            
            e = [SELECT Id, Location FROM Event WHERE Id = :e.Id];
            
            system.assertEquals(testAnswer, e.Location);

            system.assert(true);
            
            // change the location a bit ... 
            string abit = 'A BIT';
            e.Location += abit;
            
            try{
                Test.startTest();
                update(e);
                Test.stopTest();

                e = [SELECT Id, Location FROM Event WHERE Id = :e.Id];
                
                system.assertEquals(testAnswer + abit, e.Location);
                
                system.assert(true);
                
            }catch(Exception ex){
                system.assert(false);
            }
            
            
            
        }catch(Exception ex){
            system.assert(false);
        }
        
    }
  
    
    
    // Need to Have a negative and test showing the location NOT filling in and not throwing errors when filled already
    static testmethod void UPDATE_LocationFill_LocationBlank_AddressFillsIn(){
        
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
        
        string testAnswer = 'TEST ADDRESS';
        
        Event e = new Event();
        e.WhatId = a2.Id;
        e.WhoId = c1.Id;
        e.Subject = 'Meeting';
        e.DurationInMinutes = 60;
        e.ActivityDateTime = Datetime.Now() + 100;
        e.Description = 'Discussion of Last Meeting';
        e.Location = testAnswer;
        e.Type = 'Internal Meeting';
        
        try{
            Test.startTest();
        	insert(e);
            Test.stopTest();

            e = [SELECT Id, Location FROM Event WHERE Id = :e.Id];
            
            system.assertEquals(testAnswer, e.Location);

            system.assert(true);
            
            // change the location a bit ... 
            string nothing = '';
            e.Location += nothing;
            
            try{
                update(e);
                
                e = [SELECT Id, Location FROM Event WHERE Id = :e.Id];
                
                system.assertNotEquals(nothing, e.Location);
                
                system.assert(true);
                
            }catch(Exception ex){
                system.assert(false);
            }
            
            
            
        }catch(Exception ex){
            system.assert(false);
        }
        
    }

/*


    // Need to Have a positive and test showing the location filling in and not throwing errors when blank
    static testmethod void INSERT_Location_NoType(){
        
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
        
        //
        Event e = new Event();
        e.WhatId = a2.Id;
        e.WhoId = c1.Id;
        e.Subject = 'Meeting';
        e.DurationInMinutes = 60;
        e.ActivityDateTime = Datetime.Now() + 100;
        e.Description = 'Discussion of Last Meeting';
        e.Location = null;
        //e.Type = 'Internal Meeting';
        
        try{

            Test.startTest();
        	insert(e);
            Test.stopTest();

            
            system.assert(true);

            // 2023-10-09 this should fill in, but I took away the Type field value. As
            // a result, the primary address doesn't fill in.
            Event eRes = [SELECT Location FROM Event WHERE Id = :e.Id];
            system.assert(eRes.Location == null);


        }catch(Exception ex){
            system.assert(false);
        }
        
    }

	*/



}