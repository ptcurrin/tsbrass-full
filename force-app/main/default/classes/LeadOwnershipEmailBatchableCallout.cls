global class LeadOwnershipEmailBatchableCallout implements Database.Batchable<SObject>, Schedulable , Database.Stateful{
    
    private final String Query;
    private Map<String, List<Lead>> ownerIdToLeads {get;set;}
    private List<Lead> aggregatedLeadsList {get;set;}
    private Map<Id, String> aggregateListResults {get;set;}
    private Map<Id, String> aggregatedSaveResults {get;set;}
    
    public void execute(System.SchedulableContext sc){
        Database.executeBatch(new LeadOwnershipEmailBatchableCallout(), 1);
    }
    
    public LeadOwnershipEmailBatchableCallout(){
        aggregateListResults = new Map<Id, String>();
        aggregatedLeadsList = new List<Lead>();
        ownerIdToLeads = new Map<String, List<Lead>>();
        aggregatedSaveResults = new Map<Id, String>();
    }
    
    public Database.QueryLocator start(Database.BatchableContext bc){
        
        List<Lead> leadsOwnerIdChanged;
        
        try{
            leadsOwnerIdChanged = [SELECT Id, OWnerId FROM Lead WHERE Ownership_Change_Email_SEND_TONIGHT__c = true];
        }catch(QueryException qex){
            leadsOwnerIdChanged = new List<Lead>();
        }
        
        Set<Id> ownerIdSet = new Set<Id>();
        
        AggregateResult[] groupedResults
            = [SELECT OwnerId, COUNT(Id)
               FROM Lead
               WHERE Ownership_Change_Email_SEND_TONIGHT__c = true
               GROUP BY OwnerId];
        for (AggregateResult ar : groupedResults)  {
            string ownerId = (string)ar.get('OwnerId');
            System.debug('Owner ID: ' + ownerId);
            if(ownerId != null){
                ownerIdSet.add(ownerId);
            }else{
                system.debug('Owner Id is somehow blank');
            }
        }
        
        string query = 'SELECT Id FROM User WHERE Id IN :ownerIdSet ';
        
        if(Test.isRunningTest()){
            query += ' LIMIT 1';
        }
        
        return Database.getQueryLocator(query);
        
    }
    
    public void execute(Database.BatchableContext bc, List<User> scope){
        
        system.debug('scope: ' + scope);
        
        // This is written to send one email at a time. 
        User owner = scope[0];
        
        Boolean hasPermission = false;
        
        try{
            PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'Leads_Reassignment_New_Owners_Get_A_Nightly_Email_Notification_List'];
            PermissionSetAssignment psa = [SELECT Id, 
                                           AssigneeId 
                                           FROM PermissionSetAssignment 
                                           WHERE AssigneeId = :owner.Id
                                           AND PermissionSetId = :ps.Id
                                          ];
            if(psa != null && psa.AssigneeId == owner.Id){
                hasPermission = true;
            }
        }catch(QueryException qex){
            
        }
        
        if(hasPermission == true || Test.isRunningTest()){
            
            List<Lead> leadsForUpdate = new List<Lead>();
            
            List<Lead> leads = [SELECT Id, 
                                Name, 
                                OwnerId,
                                Owner.Name,
                                Owner.Email 
                                FROM Lead 
                                WHERE OwnerId = :owner.Id 
                                AND Ownership_Change_Email_SEND_TONIGHT__c = true];
            
            ownerIdToLeads.put(owner.Id, leads);
            
            string orgURL = URL.getOrgDomainUrl().toString();
            string ownerName = leads[0].Owner.Name;
            
            string subject = 'Newly Assigned/Reassigned Leads';
            string body = '';
            body += ownerName + '</br>';
            body += 'The following leads have been assigned to you, today, in the salesforce org at ' + orgURL + '</br></br>';
            
            body += 'LEAD LIST' + '</br>';
            
            string toAddress;
            for(Lead l : leads){
                
				toAddress = l.Owner.Email;                 

                string line = orgURL + '/' + l.Id + ' >>> ' + l.Name + '</br>';
                system.debug('line: ' + line);
                
                body += line;
                
                Lead tempLead = new Lead();
                tempLead.Id = l.Id;
                tempLead.Ownership_Change_Email_SEND_TONIGHT__c = false;
                leadsForUpdate.add(tempLead);
                
            }
            
            body += '</br>Thank You</br>';
            
            
            //string toAddress = 'pcurrin@tsbtrass.com';
            //string toAddress = 'salesforceadmin@tsbrass.com';
            system.debug('LEADS toAddress: ' + toAddress);
            
            Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
            message.setHTMLBody(body);
            message.setToAddresses(new List<String> {leads[0].Owner.Email});
            message.setBCCAddresses(new List<String>{ toAddress }); 
            message.setSubject(subject);
            
            List<Messaging.SendEmailResult> results = Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ message });
            
            string emailResultMessage = 'Email Sent? ' + results[0].isSuccess();
            
            aggregateListResults.put(owner.Id, emailResultMessage);
            
            if(results[0].isSuccess()){
                List<Database.SaveResult> saveResults = Database.update(leadsForUpdate);
                for(Database.SaveResult sr : saveResults){
                    string messages = '';
                    for(Database.Error error : sr.getErrors()){
                        messages += '</br>' + error.getMessage() + '</br>';
                    }
                    aggregatedSaveResults.put(sr.getId(), sr.isSuccess() + ' | ' + messages);
                }
            }
            
            system.debug('body: ' + body);
            system.debug('results: ' + results);
            
        }else{
            system.debug('This user does not have a permission set assignment for Leads_Reassignment_New_Owners_Get_A_Nightly_Email_Notification_List. Action ended early for this user. ');
        }
    }
    
    public void finish(Database.BatchableContext bc){
        
        // Send an email to salesforceadmin@tsbrass.com with results
        
        
        string orgURL = URL.getOrgDomainUrl().toString();
        string ownerName = 'Salesforce Admin';
        
        string subject = 'Newly Assigned/Reassigned Leads Results';
        string body = '';
        body += ownerName + '</br>';
        body += 'The following users were sent Lead Assignment emails today in the salesforce org at ' + orgURL + '</br></br>';
        
        body += '</br>';
        
        Set<String> ownerIdToLeadsKeyset = ownerIdToLeads.keyset();
        Map<Id, User> mapOwners = new Map<Id, User>( [SELECT Id, Name FROM User WHERE Id IN :ownerIdToLeadsKeyset] );
        
        for(String ownerId : ownerIdToLeadsKeyset){
            
            User Owner = mapOwners.get(ownerId);
            
            body += '</br>';
            body += owner.Name + ' ... (Owner)[' + owner.Id + ']';
            body += '</br>';
            
            
            List<Lead> leads = ownerIdToLeads.get(ownerId);
            
            for(Lead l : leads){
                
                string line = orgURL + '/' + l.Id + ' >>> ' + l.Name + '</br>';
                system.debug('line: ' + line);
                
                body += line;
                
            }
            body += '</br>';
            body += '-------------------------------';
            body += '</br>';
            
        }
        
        body += '</br>Thank You</br></br>';
        
        body += 'Ids vs Save Results For Today</br>';
        for(Id idkey : aggregatedSaveResults.keyset()){
            
            String messages = orgURL + '/' + idkey + '  >>> ' + aggregatedSaveResults.get(idkey);
            
            string saveResultline = '</br>   ' + messages;
            system.debug('saveResultline: ' + saveResultline);
            body += saveResultline;
        }
        
        //string toAddress = 'redoakruntest@gmail.com';
        //string toAddress = 'salesforceadmin@tsbrass.com';
        List<String> toAddresses = new List<String>();
        List<Leads_Reassignment_Email_Options__mdt> options = [SELECT Id, 
                                                               Active__c, 
                                                               Email__c 
                                                               FROM Leads_Reassignment_Email_Options__mdt 
                                                               WHERE Active__c = true];
        for(Leads_Reassignment_Email_Options__mdt option : options){
            String email = option.Email__c;
            toAddresses.add(email);
            system.debug('LEADS RESULTS toAddresses: ' + email);
        }
        
        
        Messaging.SingleEmailMessage message = new Messaging.SingleEmailMessage();
        message.setHTMLBody(body);
        message.setToAddresses( toAddresses ); // salesforceadmin
        message.setSubject(subject);
        
        List<Messaging.SendEmailResult> results = Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ message });
        
        system.debug('body: ' + body);
        system.debug('results: ' + results);
        
    }
}