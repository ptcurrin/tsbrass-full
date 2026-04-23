global class BOARD_API_Batch implements schedulable, Database.Batchable<Account>, Database.Stateful, Database.AllowsCallouts {
    
    global void execute(SchedulableContext ctx) {
        
        Database.executeBatch(this, 20);
        
    }
    
    public BOARD_API_Batch(){}
    
    public class LimitTooHighException extends Exception {}
    
    public BOARD_API_Batch(Integer testLimit){
        this.testLimit = testLimit;
        
        if(testLimit > 40){
            throw new LimitTooHighException('Limit needs to stay below 40. You typed ' + testLimit);
        }
    }
    
    private Integer testLimit;
    
    private String tryCatchExceptionString;
    private Integer totalQueries;
    private Integer totalDMLStatements;
    private Integer totalDMLRows;
    
    private List<String> transLogs {get;set;}
    private Integer transactionNum {get;set;}
    
    // if an instance variable, not a static variable, and it should retain its state between transactions because Database.Stateful
    private List<Database.SaveResult> finalsaveresults;
    
    // This map grows as Accounts are successfully saved, and helps with reporting
    private Map<Id, Account> sfAccountMap;
    
    // This map grows no matter what
    private Map<String, Account> allAccountsByCustNumMap;
    
    // This list grows as accounts are missing 
    private Map<String, Account> reportMissingAccountsMap;
    
    // This list grows as accounts are found but do not need updating
    private Map<String, Account> foundButSameDecValueMap;
    
    // This list of String Custnums grows as accounts (which are only Cust Nums and Decimals) fail
    private List<String> AllAccountExtIds; 
    
    // Total count considered and Added to all
    private Integer considered;
    
    
    
    global System.Iterable<Account> start(Database.BatchableContext context){
        
        transLogs = new List<STring>();
        transactionNum = 1;
        
        considered = 0;
        sfAccountMap = new Map<Id, Account>();
        reportMissingAccountsMap = new Map<String, Account>();
        AllAccountExtIds = new List<String>();
        finalsaveresults = new List<Database.SaveResult>();
        allAccountsByCustNumMap = new Map<String, Account>();
        foundButSameDecValueMap = new Map<String, Account>();
        
        system.debug('^^^ TestLimit From BOARD_API_Batch ... before: ' + testLimit);
        if(testLimit != null){
            return new BOARDCustomAccountIterable(this.testLimit);
        }else{
            return new BOARDCustomAccountIterable();
        }
    }
    
    // This execute method is receiving from the BOARDCustomAccountIterator, which is passing
    // BOARDCustomAccountIterables, which are just Account slugs. 
    // Since BOARD is giving us two values, sometimes, for the same Cust_Num__c, even though we have 
    // two different kind of accounts, both new Decimal values are attached to the same CustNum, 
    // transported on the same account slug
    // 
    // ACCOUNT SLUG
    // 
    // NOT!!!! AN ACCOUNT TO SAVE, just an object transporting data. The below execute method makes
    // method calls, independently, to get a map of all Customer Accounts by CustNum, for TR, and then
    // does the exact same thing for CHINA.
    // 
    // These maps are to find the appropriate account, China or TR, and fill the appropriate YTD Sales field 
    
    global void execute(Database.BatchableContext context, List<Account> accountsThisBatch){
        
        system.debug('Get Limit DML Statements: ' + Limits.getLimitDMLRows());
        
        List<Account> saveAccounts = new List<Account>();
        
        //Map<string, Account> mapChina = selectChinaAccountsByCustNum();
        //Map<string, Account> mapTR    = selectTRAccountsByCustNum();
        
        for(Account slug : accountsThisBatch){
            
            try{
                
                system.debug('slug: ' + slug); 
                
                Boolean foundTR = false;
                
                if(slug.Cust_Num__c != null){// && slug.Sales_YTD__c != null){
                    
                    Account tmpAcctTR = selectTRAccountsByCustNum(slug.Cust_Num__c);
                    
                    if(tmpAcctTR != null){
                        
                        Decimal decVal = slug.Sales_YTD__c.setScale(2);
                        
                        if(tmpAcctTR.Sales_YTD__c != decVal){
                            Account saveAcctTR = new Account();
                            saveAcctTR.Id = tmpAcctTR.Id;
                        	saveAcctTR.Sales_YTD__c = decVal;
                        	saveAccounts.add(saveAcctTR);
                        }else{
                            foundButSameDecValueMap.put(tmpAcctTR.Id, tmpAcctTR);
                        }
                        foundTR = true;
                        
                    }
                }
                
                
                Boolean foundChina = false;
                
                if(slug.Cust_Num__c != null){  // && slug.YTD_Sales_TSZQ__c  != null){
                    Account tmpAcctChina = selectChinaAccountsByCustNum(slug.Cust_Num__c);
                    if(tmpAcctChina != null){
                        
                        Decimal decChinaVal = slug.YTD_Sales_TSZQ__c.setScale(2);
                        
                        if(tmpAcctChina.YTD_Sales_TSZQ__c != decChinaVal){
                            Account saveAcctChina = new Account();
                        	saveAcctChina.Id = tmpAcctChina.Id;
                        	saveAcctChina.YTD_Sales_TSZQ__c = decChinaVal;
                        	saveaccounts.add(saveAcctChina);
                        }else{
                            foundButSameDecValueMap.put(tmpAcctChina.Id, tmpAcctChina);
                        }
                        foundChina = true;
                    }
                }
                
                if(!foundTR && !foundChina){
                    reportMissingAccountsMap.put(slug.Cust_Num__c, slug);
                }
                
            }catch(Exception ex){
                
                if(tryCatchExceptionString == null){
                    tryCatchExceptionString = '';
                }
                
                string newStr = '<p>' + slug + '</p>';
                newStr += '<p>' + ex.getMessage() + '</p>';
                newStr += '<p></p>';
                
                tryCatchExceptionString += newStr;
                
            }
            
        }
        
        
        
        List<Database.SaveResult> sresults = Database.update(saveAccounts);
        
        
        // Since there is a stateful batch ongoing, this variable stores the savedAccount results to report later
        finalsaveresults.addAll(sresults);
        
        tallyLimits();
        
        
        
        translogs.add(transactionNum++ + '.)  Queries Queried/Allowed: ' + Limits.getQueries() + '/' + Limits.getLimitQueries() + ' ... DML Saves/Allowed: ' + Limits.getDMLStatements() + '/' + Limits.getLimitDMLStatements());
        
    }
    
    // IF everything lines up as it should, then a failed save should be available at a specific place in the 
    // list  "allAccountExtIds," which should make it easy to key to allAccountsByCustNumMap ... 
    // 
    
    private void tallyLimits(){
        
        if(totalQueries == null){
            system.debug('initialize totalQueries var to 0');
            totalQueries = 0;
        }
        if(totalDMLStatements == null){
            system.debug('initialize totalDMLStatements var to 0');
            totalDMLStatements = 0;
        }
        if(totalDMLRows == null){
            system.debug('initialize totalDMLRows var to 0');
            totalDMLRows = 0;
        }
        
        system.debug('$$$$$.    SOQL Query Transaction LIMITS : ' + Limits.getLimitQueries());
        system.debug('$$$$$.    SOQL Queries this Transaction : ' + Limits.getQueries());
        system.debug('$$$$$.    DML Statements this Transation: ' + Limits.getDMLStatements());
        system.debug('$$$$$.    DML Rows this Transaction     : ' + Limits.getDMLRows());
        
        totalQueries += Limits.getQueries();
        totalDMLStatements += Limits.getDMLStatements();
        totalDMLRows += Limits.getDMLRows();
    }
    
    global void finish(Database.BatchableContext context){
        
        String htmlupdateNotFound = '<table><thead><tr><th>#</th><th>Cust Num</th><th>YTD Returned</th></tr></thead><body>';
        Integer notFound = 0;
        
        String htmlupdateSuccess = '<table><thead><tr><th>#</th><th>Cust Num</th><th>RecType</th><th>Successfully Updated</th><th>TR Amount </th><th> China(TSZQ)Amount</th></tr></thead><body>';
        Integer updated = 0;
        
        String htmlupdateFailure = '<table><thead><tr><th>#</th><th>Cust Num</th><th>RecType</th><th>Failed To Update</th><th>SalesForce ID</th></tr></thead><body>';
        Integer failed = 0;
        
        String htmlupdateUnneeded = '<table><thead><tr><th>#</th><th>SFID</th><th>Cust Num</th><th>RecType</th><th>Failed To Update</th><th>SalesForce ID</th></tr></thead><body>';
        Integer unneeded = 0;
        
        String summary = '<p>BOARD API CALL : UPDATE SALES YTD </p><p></p>';
        summary += '<p>Total   SOQL Queries: ' + totalQueries + '</p>';
        summary += '<p>Total DML Statements: ' + totalDMLStatements + '</p>';
        summary += '<p>Total DML Rows.     : ' + totalDMLRows + '</p><p></p>';
        
        
        system.debug('$$$$$.    finish method - totalQueries : ' + totalQueries);
        system.debug('$$$$$.    finish method - totalDMLStat : ' + totalDMLStatements);
        system.debug('$$$$$     finish method - totalDMLRows : ' + totalDMLRows);
        
        summary += 'Transaction-Section-Specific-Exceptions? : ';
        if(tryCatchExceptionString != null){
            summary += tryCatchExceptionString;
        }else{
            summary += 'none';
        }
        
        RecordType recTypeChina = [SELECT Id, Name FROM RecordType WHERE SObjectType = 'Account' AND DeveloperName = 'China'];
        RecordType recTypeTR    = [SELECT Id, Name FROM RecordType WHERE SObjectType = 'Account' AND DeveloperName = 'Customer'];
        
        Map<Id, string> recordTypeMap = new Map<Id, string>();
        recordTypeMap.put(recTypeChina.Id, recTypeChina.Name);
        recordTypeMap.put(recTypeTR.Id   , recTypeTR.Name);
        
        Integer missingCount = 0;
        for(String key : reportMissingAccountsMap.keyset()){
            
            Account a = reportMissingAccountsMap.get(key);
            
            htmlupdateNotFound += '<tr><td>' + ++missingCount + '</td><td>' + key + '</td><td style="text-align: right;">' + 
                a.Sales_YTD__c  + 
                '</td><td style="text-align: right;">' + a.YTD_Sales_TSZQ__c  + '</td></tr>';
            notFound++;
        }
        
        htmlupdateNotFound += '</body></table></br>';
        string beforeHtmlUpdateNotFound = '[' + notFound + '] Missing - Not Updated</br>';
        htmlupdateNotFound = beforeHtmlUpdateNotFound + htmlupdateNotFound;
        
        system.debug(htmlupdateNotFound);
        
        
        for(String key : foundButSameDecValueMap.keyset()){
            
            Account u = foundButSameDecValueMap.get(key);
            string newString = '<tr><td>' + unneeded + '</td><td>' + 
                	(u.Id + '').rightpad(19, ' ') + '</td><td>' + 
                    (u.Cust_Num__c).rightpad(10, ' ') + '</td><td>' +
                    (recordTypeMap.get(u.RecordTypeId)).rightpad(10, ' ') + '</td><td>' +
                    (u.Name).rightPad(60, '.') + '</td><td style="text-align: right;">' +
                    (u.Sales_YTD__c + '') + '</td><td style="text-align: right;">' +
                    (u.YTD_Sales_TSZQ__c + '') + '</td></tr>';
            htmlupdateUnneeded += newString;
            unneeded++;
        }
        htmlupdateUnneeded += '</body></table></br>';
        string beforeHtmlUpdateUnneeded = '[' + unneeded + '] Uneeded (Same Value Already!)</br>';
        htmlupdateUnneeded = beforeHtmlUpdateUnneeded + htmlupdateUnneeded;
        
        
        
        
        
        Set<Id> overallFailureIdSet = new Set<Id>();
        Set<Id> overallSuccessIdSet = new Set<Id>();
        for(Database.SaveResult sr : finalsaveresults){
            if(sr.isSuccess()){
                overallSuccessIdSet.add(sr.getId());
            }else{
                try{
                    
                    Id srId = sr.getId();
                    overallFailureIdSet.add(srId);
                    
                }catch(exception ex){
                    
                }
            }  
        }
        
        system.debug('$$$$$.    SOQL Query Transaction LIMITS: ' + Limits.getLimitQueries());
        system.debug('$$$$$.    SOQL Queries this Transaction: ' + Limits.getQueries());
        
        List<Account> properlySavedAccounts = [SELECT Id, CreatedDate, Name, Cust_Num__c, RecordTypeId, RecordType.Name,
                                               Sales_YTD__c, 
                                               YTD_Sales_TSZQ__c FROM Account WHERE Id IN :overallSuccessIdSet ];
        
        Map<Id, Account> properlySavedAccountsMap = new Map<Id, Account>(properlySavedAccounts);
        
        
        List<Account> improperlySavedAccounts = [SELECT Id, RecordTypeId, RecordType.Name, Cust_Num__c, Name FROM Account WHERE Id IN :overallFailureIdSet];
        Map<Id, Account> improperlySavedAccountsMap = new Map<Id, Account>(improperlySavedAccounts);
        
        
        
        Integer successCount = 0;
        for(Database.SaveResult sr : finalsaveresults){
            
            if(sr.isSuccess()){
                Account successReportAccount = properlySavedAccountsMap.get(sr.getId());
                updated++;
                
                string newString = '<tr><td>' + ++successCount + '</td><td>' + 
                    (successReportAccount.Cust_Num__c).rightpad(10, ' ') + '</td><td>' +
                    (recordTypeMap.get(successReportAccount.RecordTypeId)).rightpad(10, ' ') + '</td><td>' +
                    (successReportAccount.Name).rightPad(60, '.') + '</td><td style="text-align: right;">' +
                    (successReportAccount.Sales_YTD__c + '') + '</td><td style="text-align: right;">' +
                    (successReportAccount.YTD_Sales_TSZQ__c + '') + '</td></tr>';
                // .leftPad(10, '.')
                htmlupdateSuccess += newString;
                
            }
            
        }
        
        htmlupdateSuccess += '</body></table></br>';
        String beforeHtmlSuccess = '[' + updated + '] Updated Successfully</br>';
        htmlupdateSuccess = beforeHtmlSuccess + htmlupdateSuccess;
        
        
        system.debug(htmlupdateSuccess);
        
        Integer failedCount = 0;
        Integer reconsidered = 0;
        for(Database.SaveResult sr : finalsaveresults){
            
            if(!sr.isSuccess()){
                string fid;
                Account fa;
                String recTypeName;
                try{
                    fid = sr.getId();
                    
                    fa = improperlySavedAccountsMap.get(fid);
                    
                    if(fa != null){
                        recTypeName = recordTypeMap.get(fa.RecordTypeId);
                    }else{
                        fa = null;
                        recTypeName = 'no data';
                    }
                }catch(Exception ex){
                    fid = 'NO ID AVAILABLE';
                }
                
                failed++;
                
                
                String custNum = allAccountExtIds.get(reconsidered);
                //Account fa = allAccountsByCustNumMap.get(custNum);
                
                htmlupdateFailure += '<tr><td>' + ++failedCount + '</td><td>' + custNum + '</td><td>' + fa + '</td><td>' + recTypeName + '</td><td>' + fid + '</td></tr>'; 
                
                
            }
            
            reconsidered++;
        }
        
        htmlupdateFailure += '</body></table></br>';
        string beforeUpdateFailure = '[' + failed + '] Failed To Update </br>';
        htmlupdateFailure = beforeUpdateFailure + htmlupdateFailure;
        system.debug(htmlupdateFailure);
        
        
        
        summary += 
            '<p>Not Found [' + notFound + ']</p>' + 
            '<p>Unneeded Update [' + unneeded + ']</p>' +
            '<p>Successfully Updated [' + updated + ']</p>' + 
            '<p>Failed To Update [' + failed + ']</p></br>';
        
        summary = '<h3>SALES YTD BOARD FIELD UPDATE IN ORG >>>  ' + URL.getOrgDomainURL().toExternalForm() + '</h3></br></br>' + summary;
        
        if(translogs.isEmpty() == false){
            for(String logStr : translogs){
                summary += '<p>' + logStr + '</p>';
            }
        }
        
        system.debug('Summary: ' + summary);
        
        constructAndSendEmail(summary + htmlupdateNotFound + htmlupdateUnneeded + htmlupdateSuccess + htmlupdateFailure, summary + htmlupdateNotFound + htmlupdateSuccess + htmlupdateFailure, 'Sales YTD BOARD Fields Update Results');
        
    }
    
    public void constructAndSendEmail(String htmlbody, String plainTextBody, String subject){
        
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setHTMLBody(htmlbody);
        email.setPlainTextBody(plainTextBody);
        email.setSubject(subject);
        
        List< BOARD_Result_Email_Address__mdt > emailAddresses = [SELECT Id, Label, EmailAddress__c, IsActive__c FROM 
                                                                  BOARD_Result_Email_Address__mdt WHERE IsActive__c = true];
        //OrgWideEmailAddress owea;
        //List<OrgWideEmailAddress> addresses = new List<OrgWideEmailAddress>();
        List<String> addresses = new List<String>();
        for( BOARD_Result_Email_Address__mdt emailAddress : emailAddresses) {
            
            system.debug('ADDRESS ADD ATTEMPT: ' + emailAddress.emailAddress__c);
            
            addresses.add(emailAddress.emailAddress__c);
            
            //owea = new OrgWideEmailAddress();
            //owea = [SELECT Id, Address, DisplayName FROM 
            //      OrgWideEmailAddress WHERE Address= :emailAddress.EmailAddress__c];
            
            //addresses.add(owea);
            
            
        }    
        
        
        
        //email.setOrgWideEmailAddressId(owea.Id);
        email.setToAddresses(addresses);		
        
        system.debug(email);
        
        if(!Test.isRunningTest()){
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
        }
    }
    
    
    public class RecTypeNotReturnedException extends Exception {}
    
    @testVisible
    private Account selectChinaAccountsByCustNum(string custnum){
        
        
        //Map<string, Account> mapChinaAccountsByCustNum = new Map<string, Account>();
        
        Id recordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('China').getRecordTypeId();
        
        if(recordTypeId == null){
            throw new RecTypeNotReturnedException('There is no. "China" rec type.... error');
        }
        
        try{        
            Account acctChinaCustomer = [SELECT Id, Name, Cust_Num__c, YTD_Sales_TSZQ__c, RecordType.Name, RecordTypeId, Sales_YTD__c 
                                         FROM Account WHERE RecordTypeId = :recordTypeId AND Cust_Num__c = :custnum];
            return acctChinaCustomer;
        }catch(QueryException qex){
            return null;
        }
        
        //for(Account acct : acctsChinaCustomer){
        //    mapChinaAccountsByCustNum.put(acct.Cust_Num__c, acct);
        //}
        
        //return mapChinaAccountsByCustNum;
    }
    
    @testVisible
    private Account selectTRAccountsByCustNum(string custnum){
        
        Map<string, Account> mapTRAccountsByCustNum = new Map<string, Account>();
        
        Id recordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Customer').getRecordTypeId();
        
        if(recordTypeId == null){
            throw new RecTypeNotReturnedException('There is no. "Customer" rec type.... error');
        }
        
        try{
            Account acctTRCustomer = [SELECT Id, Name, Cust_Num__c, Sales_YTD__c, RecordType.Name, RecordTypeId, YTD_Sales_TSZQ__c 
                                      FROM Account WHERE RecordTypeId = :recordTypeId AND Cust_Num__c = :custnum];
            return acctTRCustomer;
        }catch(QueryException qex){
            return null;
        }
        //for(Account acct : acctsTRCustomer){
        //    mapTRAccountsByCustNum.put(acct.Cust_Num__c, acct);
        //}
        
        //return mapTRAccountsByCustNum;
    }
    
    
    
}