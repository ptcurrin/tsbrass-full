//Test coverage created by Vision-e to handle ConvertAddress Trigger designed to take multiple address lines entered on Scanning queue
//and output to 4 custom fields on Contact object
//100% coverage at time of creation || 2 Methods to test both success and failure scenarios
//
//update 9/30/2022 - added coverage for changes to trigger that include updates to Contact Mailing Address. 
//100% code coverage || 3 additional test methods added

@isTest
private class ConvertAddressTest {
    
    static testmethod void ConvertAddressTestSuccess(){
        id repRecTypeId = schema.SObjectType.Account.getRecordTypeInfosByName().get('Rep Agency').getRecordTypeId();
        Account repAcc = new Account();
        repAcc.Name = 'Test Rep Agency';
        repAcc.RecordTypeId = repRecTypeId;
        insert repAcc;
        
        Account tAcc = new Account();
        tAcc.Name = 'TestAccount';
        tAcc.SLSMan_Rep_Agency__c = repAcc.id;
        tAcc.Type = 'Other';
        insert tAcc;
        
        Contact tCon = new Contact();
        tCon.eContacts__Created_By_eContacts__c = TRUE;
        tCon.FirstName = 'John';
        tCon.LastName = 'Doe';
        tCon.AccountId = tAcc.Id;
        tCon.MailingStreet = '1234 Test Street\nSuite 1A\nUnit 2B\n2nd Floor';
        tCon.Email = 'noemail@noemail.com';
        tCon.Phone = '555-555-5555';
        tCon.Title = 'Sales Rep';
        
        
        
		Test.startTest();
        database.SaveResult result = database.insert(tCon, false);
        Test.stopTest();
        
        system.Assert(result.isSuccess());
        string newConId = (string)tCon.id;
        sObject newCon = database.query('Select Id, Address_1__c from Contact where id =: newConId');
        system.debug(newCon);
        system.assertEquals('1234 Test Street', newCon.get('Address_1__c'));
       
    }
    
    static testmethod void ConvertAddressTestSuccessEmptyAddress(){
        id repRecTypeId = schema.SObjectType.Account.getRecordTypeInfosByName().get('Rep Agency').getRecordTypeId();
        Account repAcc = new Account();
        repAcc.Name = 'Test Rep Agency';
        repAcc.RecordTypeId = repRecTypeId;
        insert repAcc;
        
        Account tAcc = new Account();
        tAcc.Name = 'TestAccount';
        tAcc.SLSMan_Rep_Agency__c = repAcc.id;
        tAcc.Type = 'Other';
        insert tAcc;
        
        Contact tCon = new Contact();
        tCon.eContacts__Created_By_eContacts__c = TRUE;
        tCon.FirstName = 'John';
        tCon.LastName = 'Doe';
        tCon.AccountId = tAcc.Id;
        tCon.MailingStreet = '';
        tCon.Email = 'noemail@noemail.com';
        tCon.Phone = '555-555-5555';
        tCon.Title = 'Sales Rep';
        
        
		Test.startTest();
        database.SaveResult result = database.insert(tCon, false);
        Test.stopTest();
        
        system.Assert(result.isSuccess());
        string newConId = (string)tCon.id;
        sObject newCon = database.query('Select Id, Address_1__c from Contact where id =: newConId');
        system.assertEquals(null, newCon.get('Address_1__c'));
       
    }
    static testmethod void ConvertAddressTestFailure(){
        id repRecTypeId = schema.SObjectType.Account.getRecordTypeInfosByName().get('Rep Agency').getRecordTypeId();
        Account repAcc = new Account();
        repAcc.Name = 'Test Rep Agency';
        repAcc.RecordTypeId = repRecTypeId;
        insert repAcc;
        
        Account tAcc = new Account();
        tAcc.Name = 'TestAccount';
        tAcc.SLSMan_Rep_Agency__c = repAcc.id;
        tAcc.Type = 'Other';
        insert tAcc;
        
        Contact tCon = new Contact();
        tCon.eContacts__Created_By_eContacts__c = TRUE;
        tCon.FirstName = 'John';
        tCon.LastName = 'Doe';
        tCon.AccountId = tAcc.Id;
        tCon.MailingStreet = '1234 Test Street 1234 Test Street and really long text to cause a failure on this line\nSuite 1A\nUnit 2B\n2nd Floor';
        tCon.Email = 'noemail@noemail.com';
        tCon.Phone = '555-555-5555';
        tCon.Title = 'Sales Rep';
        
        eContacts__Settings__c settings = new eContacts__Settings__c();
        settings.Name = 'default';
        insert settings;
        
        string warningMsg = '';
    	if(settings.Address_Length_Warning_Text__c != '' && settings.Address_Length_Warning_Text__c != null){
        	warningMsg = settings.Address_Length_Warning_Text__c;
    	}
    	else{
        	warningMsg = 'Each address line must be less than 50-characters';
    	}
        
		Test.startTest();
        database.SaveResult result = database.insert(tCon, false);
        Test.stopTest();
        
        system.Assert(!result.isSuccess());
        system.Assert(result.getErrors().size() > 0);
        system.AssertEquals(warningMsg,
                            result.getErrors()[0].getMessage());
        
       
    }
    
    static testmethod void ConvertAddressTestFailure2(){
        id repRecTypeId = schema.SObjectType.Account.getRecordTypeInfosByName().get('Rep Agency').getRecordTypeId();
        Account repAcc = new Account();
        repAcc.Name = 'Test Rep Agency';
        repAcc.RecordTypeId = repRecTypeId;
        insert repAcc;
        
        Account tAcc = new Account();
        tAcc.Name = 'TestAccount';
        tAcc.SLSMan_Rep_Agency__c = repAcc.id;
        tAcc.Type = 'Other';
        insert tAcc;
        
        Contact tCon = new Contact();
        tCon.eContacts__Created_By_eContacts__c = TRUE;
        tCon.FirstName = 'John';
        tCon.LastName = 'Doe';
        tCon.AccountId = tAcc.Id;
        tCon.MailingStreet = '1234 Test Street 1234 Test Street and really long text to cause a failure on this line\nSuite 1A\nUnit 2B\n2nd Floor';
        tCon.Email = 'noemail@noemail.com';
        tCon.Phone = '555-555-5555';
        tCon.Title = 'Sales Rep';
        
        //for this test, we set a value in the custom setting field for custom warning message
        eContacts__Settings__c settings = new eContacts__Settings__c();
        settings.Name = 'default';
        settings.Address_Length_Warning_Text__c = 'Each address line must be less than 50-characters';
        insert settings;
        
        string warningMsg = '';
    	if(settings.Address_Length_Warning_Text__c != '' && settings.Address_Length_Warning_Text__c != null){
        	warningMsg = settings.Address_Length_Warning_Text__c;
    	}
    	else{
        	warningMsg = 'Each address line must be less than 50-characters';
    	}
        
		Test.startTest();
        database.SaveResult result = database.insert(tCon, false);
        Test.stopTest();
        
        //get updated warning message from custom settings to compare
        eContacts__Settings__c updatedSettings = [Select id, Address_Length_Warning_Text__c from eContacts__Settings__c where id =: settings.id];
        string newWarning = updatedSettings.Address_Length_Warning_Text__c;
        
        system.Assert(!result.isSuccess());
        system.Assert(result.getErrors().size() > 0);
        system.AssertEquals(newWarning,
                            result.getErrors()[0].getMessage());
        
       
    }
    
    static testMethod void testAddressUpdate(){
        id repRecTypeId = schema.SObjectType.Account.getRecordTypeInfosByName().get('Rep Agency').getRecordTypeId();
        Account repAcc = new Account();
        repAcc.Name = 'Test Rep Agency';
        repAcc.RecordTypeId = repRecTypeId;
        insert repAcc;
        
        Account tAcc = new Account();
        tAcc.Name = 'TestAccount';
        tAcc.SLSMan_Rep_Agency__c = repAcc.id;
        tAcc.Type = 'Other';
        insert tAcc;
        
        Contact tCon = new Contact();
        tCon.eContacts__Created_By_eContacts__c = TRUE;
        tCon.FirstName = 'John';
        tCon.LastName = 'Doe';
        tCon.AccountId = tAcc.Id;
        tCon.MailingStreet = '1234 Test Street\nSuite 1A\nUnit 2B\n2nd Floor';
        tCon.Email = 'noemail@noemail.com';
        tCon.Phone = '555-555-5555';
        tCon.Title = 'Sales Rep';
        insert tCon;
        
        Contact con2Update = [select id from Contact where id =: tCon.Id];
        
        con2Update.MailingStreet = '5678 Test Avenue\nLine2\nLine3\nLine4';
        
        
		Test.startTest();
        database.SaveResult result = database.update(con2Update, false);
        Test.stopTest();
        
        system.Assert(result.isSuccess());
        string newConId = (string)con2Update.id;
        sObject newCon = database.query('Select Id, Address_1__c from Contact where id =: newConId');
        system.debug(newCon);
        system.assertEquals('5678 Test Avenue', newCon.get('Address_1__c'));
    }
    
    static testMethod void testAddressUpdateEmptyString(){
        id repRecTypeId = schema.SObjectType.Account.getRecordTypeInfosByName().get('Rep Agency').getRecordTypeId();
        Account repAcc = new Account();
        repAcc.Name = 'Test Rep Agency';
        repAcc.RecordTypeId = repRecTypeId;
        insert repAcc;
        
        Account tAcc = new Account();
        tAcc.Name = 'TestAccount';
        tAcc.SLSMan_Rep_Agency__c = repAcc.id;
        tAcc.Type = 'Other';
        insert tAcc;
        
        Contact tCon = new Contact();
        tCon.eContacts__Created_By_eContacts__c = TRUE;
        tCon.FirstName = 'John';
        tCon.LastName = 'Doe';
        tCon.AccountId = tAcc.Id;
        tCon.MailingStreet = '1234 Test Street\nSuite 1A\nUnit 2B\n2nd Floor';
        tCon.Email = 'noemail@noemail.com';
        tCon.Phone = '555-555-5555';
        tCon.Title = 'Sales Rep';
        insert tCon;
        
        Contact con2Update = [select id from Contact where id =: tCon.Id];
        
        con2Update.MailingStreet = '';
        
        
		Test.startTest();
        database.SaveResult result = database.update(con2Update, false);
        Test.stopTest();
        
        system.Assert(result.isSuccess());
        string newConId = (string)con2Update.id;
        sObject newCon = database.query('Select Id, Address_1__c from Contact where id =: newConId');
        system.debug(newCon);
        system.assertEquals(null, newCon.get('Address_1__c'));
    }
    
    static testmethod void UpdateAddressTestFailure(){
        id repRecTypeId = schema.SObjectType.Account.getRecordTypeInfosByName().get('Rep Agency').getRecordTypeId();
        Account repAcc = new Account();
        repAcc.Name = 'Test Rep Agency';
        repAcc.RecordTypeId = repRecTypeId;
        insert repAcc;
        
        Account tAcc = new Account();
        tAcc.Name = 'TestAccount';
        tAcc.SLSMan_Rep_Agency__c = repAcc.id;
        tAcc.Type = 'Other';
        insert tAcc;
        
        Contact tCon = new Contact();
        tCon.eContacts__Created_By_eContacts__c = TRUE;
        tCon.FirstName = 'John';
        tCon.LastName = 'Doe';
        tCon.AccountId = tAcc.Id;
        tCon.MailingStreet = '1234 Test Street';
        tCon.Email = 'noemail@noemail.com';
        tCon.Phone = '555-555-5555';
        tCon.Title = 'Sales Rep';
        insert tCon;
        
        //for this test, we set a value in the custom setting field for custom warning message
        eContacts__Settings__c settings = new eContacts__Settings__c();
        settings.Name = 'default';
        settings.Address_Length_Warning_Text__c = 'Each address line must be less than 50-characters';
        insert settings;
        
        string warningMsg = '';
    	if(settings.Address_Length_Warning_Text__c != '' && settings.Address_Length_Warning_Text__c != null){
        	warningMsg = settings.Address_Length_Warning_Text__c;
    	}
    	else{
        	warningMsg = 'Each address line must be less than 50-characters';
    	}
        
        Contact con2Update = [select id from Contact where id =: tCon.Id];
        
        con2Update.MailingStreet = '1234 Test Street 1234 Test Street and really long text to cause a failure on this line\nSuite 1A\nUnit 2B\n2nd Floor';
        
		Test.startTest();
        database.SaveResult result = database.update(con2Update, false);
        system.debug('result: ' + result);
        Test.stopTest();
        
        //get updated warning message from custom settings to compare
        eContacts__Settings__c updatedSettings = [Select id, Address_Length_Warning_Text__c from eContacts__Settings__c where id =: settings.id];
        string newWarning = updatedSettings.Address_Length_Warning_Text__c;
        
        system.Assert(!result.isSuccess());
        system.Assert(result.getErrors().size() > 0);
        system.AssertEquals(newWarning,
                            result.getErrors()[0].getMessage());
        
       
    }
}