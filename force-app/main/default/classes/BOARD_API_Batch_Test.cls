@isTest
public class BOARD_API_Batch_Test {
    
    static testmethod void ScheduledBatchTest_Success(){
        
        // For this unit test, there is a China Customer and a TR Customer with the same Cust Num. We are 
        // testing to make sure they can coexist, and update through board when the China Customers are in.
        
        
        Account a1 = new Account();
        a1.Name = 'Test Rep';       
        a1.External_Id__c='12345';
        a1.SLSMan_EXT_ID__c='SMA00001';
        a1.Type='Rep Agency';
        a1.RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Rep_Agency').getRecordTypeId();
        insert a1;                  
        
        
        //insert customer
        Account a3 = new Account();
        a3.Name = 'China1';
        a3.Cust_Num__c = 'AW03999'; // <<< not in the incoming string.... ( std_example_json )
        a3.RSM__c='SMA00867';
        a3.External_Id__c='8d716d47-a140-4c93-98e0-b65b51bcc777';
        a3.SLSMan_Rep_Agency__c=a1.Id;
        a3.Type='Installer';   
        a3.RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('China').getRecordTypeId();
        insert a3;  
        
        Account a4 = new Account(); // <<< this account has the same cust num but different ext id (rowpointer) than China
        a4.Name = 'Customer1';
        a4.Cust_Num__c = 'AW03999';
        a4.RSM__c='SMA00867';
        a4.External_Id__c='82716d347-a141-4c93-28e0-b65b51bdc717';
        a4.SLSMan_Rep_Agency__c=a1.Id;
        a4.Type='Installer';   
        a4.RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Customer').getRecordTypeId();
        insert a4;  
        
        //insert customer
        Account a2 = new Account();
        a2.Name = 'Customer2';
        a2.Cust_Num__c = 'AT00999';
        a2.RSM__c='SMA00867';
        a2.External_Id__c='8d716d47-a740-4c94-98e0-b65b51bcc890';
        a2.SLSMan_Rep_Agency__c=a1.Id;
        a2.Type='Installer';   
        a2.RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Customer').getRecordTypeId();
        insert a2;    
        
        
        
        
        BOARD_API_MOCKS.isSuccessTokenCallout = true;
        BOARD_API_MOCKS.isSuccessListCallout = true;
        BOARD_API_MOCKS.listResponseSuccessResponseString = std_example_json; 
        
        system.debug('std_example_json(MOCKS): ' + std_example_json);
        
        Test.setMock(HttpCalloutMock.class, new BOARD_API_MOCKS());
        
        
        Account AT00999 = [SELECT Id, Name, 
                           
                           Sales_YTD__c, 
                           
                           YTD_Sales_TSZQ__c, Cust_Num__c FROM Account WHERE Cust_Num__c = 'AT00999' AND Id = :a2.Id];
        system.debug('AT00999: ' + AT00999);
        system.assertEquals(AT00999.Sales_YTD__c, null);
        system.assertEquals(AT00999.YTD_Sales_TSZQ__c, null);
        
        
        Account AW03999China = [SELECT Id, Name, 
                           
                           Sales_YTD__c, 
                           
                           YTD_Sales_TSZQ__c, Cust_Num__c FROM Account WHERE Cust_Num__c = 'AW03999' AND Id = :a3.Id];
        system.debug('AW03999China: ' + AW03999China);
        system.assertEquals(AW03999China.Sales_YTD__c, null);
        system.assertEquals(AW03999China.YTD_Sales_TSZQ__c, null);
        
        
        Account AW03999TR = [SELECT Id, Name, 
                           
                           Sales_YTD__c, 
                           
                           YTD_Sales_TSZQ__c, Cust_Num__c FROM Account WHERE Cust_Num__c = 'AW03999' AND Id = :a4.Id];
        system.debug('AW03999TR: ' + AW03999TR);
        system.assertEquals(AW03999TR.Sales_YTD__c, null);
        system.assertEquals(AW03999TR.YTD_Sales_TSZQ__c, null);
        system.assertEquals(AW03999TR.Cust_Num__c, 'AW03999');
        
        
        Test.startTest();
        
        Database.executeBatch(new BOARD_API_Batch(), 20);
        
        Test.stoptest();
        
        // expected :
        // AT00999 - Customer TR - 
        // AT00999.Sales_YTD__c = 41924.7196683884 or ~ 2 decimnal places
        // AT00999.YTD_Sales_TSZQ__c = 0 or null
        AT00999 = [SELECT Id, Name, 
                   Sales_YTD__c, 
                   YTD_Sales_TSZQ__c, 
                   Cust_Num__c 
                   FROM Account 
                   WHERE Cust_Num__c = 'AT00999' 
                   AND Id = :a2.Id];
        system.debug('AT00999: ' + AT00999);
        system.assertEquals(AT00999.Sales_YTD__c, 41924.72);
        system.assertEquals(AT00999.YTD_Sales_TSZQ__c, null);
        
        
        // expected :
        // AW03999 (china)
        // AW03999.Sales_YTD__c = 196.080001831055 or ~ to 2 decimal places
        AW03999China = [SELECT Id, Name, 
                   Sales_YTD__c, 
                   YTD_Sales_TSZQ__c, 
                   Cust_Num__c 
                   FROM Account 
                   WHERE Cust_Num__c = 'AW03999' 
                   AND Id = :a3.Id];
        system.debug('AW03999China: ' + AW03999China);
        system.assertEquals(AW03999China.Sales_YTD__c, null);
        system.assertEquals(AW03999China.YTD_Sales_TSZQ__c, 196.08);
        
        
        // expected :
        // AW03999 (china)
        // AW03999.Sales_YTD__c = 196.080001831055 or ~ to 2 decimal places
        AW03999TR = [SELECT Id, Name, 
                   Sales_YTD__c, 
                   YTD_Sales_TSZQ__c, 
                   Cust_Num__c 
                   FROM Account 
                   WHERE Cust_Num__c = 'AW03999' 
                   AND Id = :a4.Id];
        system.debug('AW03999TR: ' + AW03999TR);
        system.assertEquals(AW03999TR.Sales_YTD__c, 3710.83);
        system.assertEquals(AW03999TR.YTD_Sales_TSZQ__c, null);
        
        
    }
    
    
    
    
    static string std_example_json = 
        '{' + 
        '"data":[' +
    	'{' +
        '"customer": "AT00999",' +  // was US21066 changed to AT00999
        '"ytd Sales TR":41924.7196683884,' +
        '"ytd Sales TSZQ":0.0' + 
        '},' + 
    	'{' + 
        '"customer":"AW03999",' + // was US35425 changed to AW03999
        '"ytd Sales TR":3710.82594680786,' + 
        '"ytd Sales TSZQ":196.080001831055' + 
        '}' + 
        ']' +
        '}';
    
    /*
    
    static testmethod void ChinaRecType_TestObjects_Test(){
        
        
        Id RepRecTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Rep_Agency').getRecordTypeId();

        
        Account a1 = new Account();
        a1.Name = 'Test Prospect';       
        a1.External_Id__c='12345';
        
        a1.SLSMan_EXT_ID__c='SMA00001';
        a1.Type='Rep Agency';
        a1.RecordTypeId=RepRecTypeId;
        insert a1;                  
        
        
        //insert china customer
        Id chinaRecTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('China').getRecordTypeId();
        
        
        Account a2 = new Account();
        a2.Name = 'Cust1China';
        a2.Cust_Num__c = 'AW03999';
        a2.RSM__c='SMA00867';
        a2.External_Id__c='8d716d47-a740-4c94-98e0-b65b51bcc890';
        a2.SLSMan_Rep_Agency__c=a1.Id;
        a2.Type='Installer';   
        a2.RecordTypeId=chinaRecTypeId;
        insert a2;
        
        
        
        //insert tr customer
        Id trRecTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Customer').getRecordTypeId();
        
        
        Account a3 = new Account();
        a3.Name = 'Cust2TR';
        a3.Cust_Num__c = 'AW03990'; // <<< there is nothing visible with this code/id. This one should fail....
        a3.RSM__c='SMA00867';
        a3.External_Id__c='8d716d47-a140-4c93-98e0-b65b51bcc777';
        a3.SLSMan_Rep_Agency__c=a1.Id;
        a3.Type='Installer';   
        a3.RecordTypeId=trRecTypeId;
        insert a3;  
        
        
        Test.startTest();
        
        
        Account checkRepAgency = [SELECT Id, RecordTypeId, Name FROM Account WHERE RecordTypeId = :repRecTypeId];
        system.debug('checkRep: ' + checkRepAgency);
        
        Account checkChina = [SELECT Id, RecordTypeId, Name FROM Account WHERE RecordTypeId =: chinaRecTypeId];
        system.debug('checkChina: ' + checkChina);
        
        Account checkCustomer = [SELECT Id, RecordTypeId, Name FROM Account WHERE RecordTypeId =: trRecTypeId];
        system.debug('checkCustomer: ' + checkCustomer);

		   
        Test.stopTest();
        

    }
    
    
    */
    
    
    
    
    static testmethod void ScheduledBatchTest_Success_TestLimit_1(){
        
        Account a1 = new Account();
        a1.Name = 'Test Prospect';       
        a1.External_Id__c='12345';
        
        a1.SLSMan_EXT_ID__c='SMA00001';
        a1.Type='Rep Agency';
        a1.RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Rep_Agency').getRecordTypeId();
        insert a1;                  
        
        //insert customer
        Account a2 = new Account();
        a2.Name = 'Cust1';
        a2.Cust_Num__c = 'AT00999';
        a2.RSM__c='SMA00867';
        a2.External_Id__c='12346';
        a2.SLSMan_Rep_Agency__c=a1.Id;
        a2.Type='Installer';   
        a2.RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Customer').getRecordTypeId();
        insert a2;    
        
        //insert customer
        Account a3 = new Account();
        a3.Name = 'Cust2';
        a3.Cust_Num__c = 'AW04000'; // <<< there is nothing visible with this code/id. This one should fail....
        a3.RSM__c='SMA00867';
        a3.External_Id__c='12347';
        a3.SLSMan_Rep_Agency__c=a1.Id;
        a3.Type='Installer';   
        a3.RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Customer').getRecordTypeId();
        insert a3;  
        
        
        BOARD_API_MOCKS.isSuccessTokenCallout = true;
        BOARD_API_MOCKS.isSuccessListCallout = true;
        BOARD_API_MOCKS.listResponseSuccessResponseString = std_example_json; 
        
        Test.setMock(HttpCalloutMock.class, new BOARD_API_MOCKS());
        
        
        
        Test.startTest();
        
        Database.executeBatch(new BOARD_API_Batch(1), 2);
        
        Test.stoptest();
        
        Account AT00999 = [SELECT Id, Name, Sales_YTD__c, Cust_Num__c, YTD_Sales_TSZQ__c FROM Account WHERE Cust_Num__c = 'AT00999'];
        system.debug('AT00999: ' + AT00999);
        system.assertEquals(AT00999.Sales_YTD__c, 41924.72);
        system.assertEquals(AT00999.YTD_Sales_TSZQ__c, null);
    }
    

    
    
    
    
    
    
    
    
    static testmethod void ScheduledBatchTest_Fails(){
        
        Account a1 = new Account();
        a1.Name = 'Test Prospect';       
        a1.External_Id__c='12345';
        
        a1.SLSMan_EXT_ID__c='SMA00001';
        a1.Type='Rep Agency';
        a1.RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Rep_Agency').getRecordTypeId();
        insert a1;                  
        
        //insert customer
        Account a2 = new Account();
        a2.Name = 'Cust1';
        a2.Cust_Num__c = 'AT00999';
        a2.RSM__c='SMA00867';
        a2.External_Id__c='12346';
        a2.SLSMan_Rep_Agency__c=a1.Id;
        a2.Type='Installer';   
        a2.RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Customer').getRecordTypeId();
        insert a2; 
        
        
        //insert customer
        Account a2C = new Account();
        a2C.Name = 'Cust1China';
        a2C.Cust_Num__c = 'AW03999';
        a2C.RSM__c='SMA00867';
        a2C.External_Id__c='8d716d47-a740-4c94-98e0-b65b51bcc890';
        a2C.SLSMan_Rep_Agency__c=a1.Id;
        a2C.Type='Installer';   
        a2C.RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('China').getRecordTypeId();
        insert a2C;
        
        
        
        
        //insert customer
        Account a3 = new Account();
        a3.Name = 'Cust2';
        a3.Cust_Num__c = 'AW04000'; // <<< there is nothing visible with this code/id. This one should fail....
        a3.RSM__c='SMA00867';
        a3.External_Id__c='12347';
        a3.SLSMan_Rep_Agency__c=a1.Id;
        a3.Type='Installer';   
        a3.RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Customer').getRecordTypeId();
        insert a3;  
        
        
        BOARD_API_MOCKS.isSuccessTokenCallout = true;
        BOARD_API_MOCKS.isSuccessListCallout = true;
        BOARD_API_MOCKS.listResponseSuccessResponseString = json_missing_from_database; 
        
        Test.setMock(HttpCalloutMock.class, new BOARD_API_MOCKS());
        
        
        
        Test.startTest();
        
        Database.executeBatch(new BOARD_API_Batch(), 2);
        
        
        Test.stoptest();
        
        
        
    }
    
    
    
    static testmethod void ScheduledBatchTest_Longer(){
        
        Account a1 = new Account();
        a1.Name = 'Test Prospect';       
        a1.External_Id__c='12345';
        
        a1.SLSMan_EXT_ID__c='SMA00001';
        a1.Type='Rep Agency';
        a1.RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Rep_Agency').getRecordTypeId();
        insert a1;                  
        
        //insert customer
        Account a2 = new Account();
        a2.Name = 'Cust1';
        a2.Cust_Num__c = 'AT00999';
        a2.RSM__c='SMA00867';
        a2.External_Id__c='12346';
        a2.SLSMan_Rep_Agency__c=a1.Id;
        a2.Type='Installer';   
        a2.RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Customer').getRecordTypeId();
        insert a2;    
        
        //insert customer
        Account a3 = new Account();
        a3.Name = 'Cust2';
        a3.Cust_Num__c = 'AW04000'; // <<< there is nothing visible with this code/id. This one should fail....
        a3.RSM__c='SMA00867';
        a3.External_Id__c='12347';
        a3.SLSMan_Rep_Agency__c=a1.Id;
        a3.Type='Installer';   
        a3.RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Customer').getRecordTypeId();
        insert a3;  
        
        
        BOARD_API_MOCKS.isSuccessTokenCallout = true;
        BOARD_API_MOCKS.isSuccessListCallout = true;
        BOARD_API_MOCKS.listResponseSuccessResponseString = std_example_json_longer; 
        
        Test.setMock(HttpCalloutMock.class, new BOARD_API_MOCKS());
        
        
        
        Test.startTest();
        
        Database.executeBatch(new BOARD_API_Batch(), 40);
        
        Test.stoptest();
        
    }
    
    
    
    static testmethod void ScheduledBatchTest_LongerLonger(){
        
        Account RA1 = new Account();
        RA1.Name = 'Rep Agency 1';       
        RA1.External_Id__c='RA1';
        
        RA1.SLSMan_EXT_ID__c='SMA00001';
        RA1.Type='Rep Agency';
        RA1.RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Rep_Agency').getRecordTypeId();
        insert RA1;                  
        
        
        //insert customer
        // AT00999 TR 41924.72 CH 0.00 <<< expected results
        Account TR1 = new Account();
        TR1.Name = 'TR1';
        TR1.Cust_Num__c = 'AT00999';
        TR1.RSM__c='SMA00867';
        TR1.External_Id__c='TR1';
        TR1.SLSMan_Rep_Agency__c=RA1.Id;
        TR1.Type='Installer';   
        TR1.RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Customer').getRecordTypeId();
        insert TR1;    
        
        //insert customer
        Account TR2 = new Account();
        TR2.Name = 'TR2';
        TR2.Cust_Num__c = 'AW04000'; // <<< there is nothing visible with this code/id. This one should not be updated....
        TR2.RSM__c='SMA00867';
        TR2.External_Id__c='TR2';
        TR2.SLSMan_Rep_Agency__c=RA1.Id;
        TR2.Type='Installer';   
        TR2.RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Customer').getRecordTypeId();
        insert TR2;  
        
        //insert China Customer
        // AW03999 TR 3710.83  CH 196.08 <<< expected results
        Account CH1 = new Account();
        CH1.Name = 'CH1';
        CH1.Cust_Num__c = 'AW03999';
        CH1.RSM__c='SMA00867';
        CH1.External_Id__c='CH1';
        CH1.SLSMan_Rep_Agency__c=RA1.Id;
        CH1.Type='Installer';   
        CH1.RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('China').getRecordTypeId();
        insert CH1; 
        
        Account TR3 = new Account();
        TR3.Name = 'TR3';
        TR3.Cust_Num__c = 'AW03999';
        TR3.RSM__c='SMA00867';
        TR3.External_Id__c='TR3'; // Same cust num as the china account but can't have the same external Id (syteline key)
        TR3.SLSMan_Rep_Agency__c=RA1.Id;
        TR3.Type='Installer';   
        TR3.RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Customer').getRecordTypeId();
        insert TR3; 
        
        
        Account TR4 = new Account();
        TR4.Name = 'TR4';
        TR4.Cust_Num__c = 'AW03999';
        TR4.RSM__c='SMA00867';
        TR4.External_Id__c='TR4'; // Same cust num as the china account but can't have the same external Id (syteline key)
        TR4.SLSMan_Rep_Agency__c=RA1.Id;
        TR4.Type='Installer';   
        TR4.RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Klarco').getRecordTypeId();
        insert TR4; 
        
        
        
        BOARD_API_MOCKS.isSuccessTokenCallout = true;
        BOARD_API_MOCKS.isSuccessListCallout = true;
        BOARD_API_MOCKS.listResponseSuccessResponseString = std_example_json_longer; 
        
        Test.setMock(HttpCalloutMock.class, new BOARD_API_MOCKS());
        Test.startTest();
        
        Database.executeBatch(new BOARD_API_Batch(), 40);
        
        Test.stoptest();
        
        // AT00999 TR 41924.72 CH 0.00
    	// AW03999 TR 3710.83  CH 196.08
    	// US47526 TR 3256.11 CH 0.00
    	// US01558 TR 2218.80 CH 0.00 
        
		// TR3 and CH1 share a line. This should be divided by record type Id. They share AW03999.....
        Account resTR3 = [ SELECT Id, Name, RecordTypeId, RecordType.DeveloperName, 
                          Cust_Num__c, 
                          Sales_YTD__c, YTD_Sales_TSZQ__c 
                          FROM Account
                          WHERE Id = :TR3.Id
                         ];
        system.debug(resTR3);
        system.assertEquals(resTR3.Cust_Num__c, 'AW03999');
        system.assertEquals(resTR3.RecordType.DeveloperName, 'Customer');
        system.assertEquals(3710.83, resTR3.Sales_YTD__c);
        system.assertEquals(null, resTR3.YTD_Sales_TSZQ__c); // <<< if never filled in, begins as null
        
        
        Account resCH1 = [ SELECT Id, Name, RecordTypeId, RecordType.DeveloperName, 
                          Cust_Num__c, 
                          Sales_YTD__c, YTD_Sales_TSZQ__c 
                          FROM Account
                          WHERE Id = :CH1.Id
                         ];
        system.debug(resCH1);
        system.assertEquals(resCH1.Cust_Num__c, 'AW03999');
        system.assertEquals(resCH1.RecordType.DeveloperName, 'China');
        system.assertEquals(null, resCH1.Sales_YTD__c); // <<< if never filled in, begins as null
        system.assertEquals(196.08, resCH1.YTD_Sales_TSZQ__c); 
    
        
        Account resTR4 = [ SELECT Id, Name, RecordTypeId, RecordType.DeveloperName, 
                          Cust_Num__c, 
                          Sales_YTD__c, YTD_Sales_TSZQ__c 
                          FROM Account
                          WHERE Id = :TR4.Id
                         ];
        system.debug(resTR4);
        system.assertEquals(resTR4.Cust_Num__c, 'AW03999');
        system.assertEquals(resTR4.RecordType.DeveloperName, 'Klarco');
        system.assertEquals(null, resTR4.Sales_YTD__c);// <<< if never filled in, begins as null
        system.assertEquals(null, resTR4.YTD_Sales_TSZQ__c); // <<< if never filled in, begins as null
        
    
    
    }
    
    

    
    
    
    static testmethod void ScheduledBatchTest_Longer_LIMITED(){
        
        Account a1 = new Account();
        a1.Name = 'Test Prospect';       
        a1.External_Id__c='12345';
        
        a1.SLSMan_EXT_ID__c='SMA00001';
        a1.Type='Rep Agency';
        a1.RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Rep_Agency').getRecordTypeId();
        insert a1;                  
        
        //insert customer
        Account a2 = new Account();
        a2.Name = 'Cust1';
        a2.Cust_Num__c = 'AT00999';
        a2.RSM__c='SMA00867';
        a2.External_Id__c='12346';
        a2.SLSMan_Rep_Agency__c=a1.Id;
        a2.Type='Installer';   
        a2.RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Customer').getRecordTypeId();
        insert a2;    
        
        //insert customer
        Account a3 = new Account();
        a3.Name = 'Cust2';
        a3.Cust_Num__c = 'AW04000'; // <<< there is nothing visible with this code/id. This one should fail....
        a3.RSM__c='SMA00867';
        a3.External_Id__c='12347';
        a3.SLSMan_Rep_Agency__c=a1.Id;
        a3.Type='Installer';   
        a3.RecordTypeId=Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Customer').getRecordTypeId();
        insert a3;  
        
        
        BOARD_API_MOCKS.isSuccessTokenCallout = true;
        BOARD_API_MOCKS.isSuccessListCallout = true;
        BOARD_API_MOCKS.listResponseSuccessResponseString = std_example_json_longer; 
        
        Test.setMock(HttpCalloutMock.class, new BOARD_API_MOCKS());
        
        
        
        Test.startTest();
        
        Database.executeBatch(new BOARD_API_Batch(1), 40);
        
        
        Test.stoptest();
        
        
        
    }
    
    static testmethod void testScheduler(){
        
        String cronjob = '0 0 1 1 2 ?';
        
        system.schedule('TestByCron', cronjob, new BOARD_API_Batch());
        
        
    }

	

    
    static string json_missing_from_database = 
        '{' + 
        '"data": [' + 
        '{' + 
        '"customer": "AW03999",' + 
        '"ytd Sales TR":3710.82594680786,' + 
        '"ytd Sales TSZQ":196.080001831055' + 
        '}' +
        ']' +
        '}';
    
    
    // AT00999 TR 41924.72 CH 0.00
    // AW03999 TR 3710.83  CH 196.08
    // US47526 TR 3256.11 CH 0.00
    // US01558 TR 2218.80 CH 0.00
    static string std_example_json_longer = 
        '{"data":[{"customer":"AT00999","ytd Sales TR":41924.7196683884,"ytd Sales TSZQ":0.0},{"customer":"AW03999","ytd Sales TR":3710.82594680786,"ytd Sales TSZQ":196.080001831055},{"customer":"US47526","ytd Sales TR":3256.10997772217,"ytd Sales TSZQ":0.0},{"customer":"US01558","ytd Sales TR":2218.80001068115,"ytd Sales TSZQ":0.0}]}';
    
  
    
}