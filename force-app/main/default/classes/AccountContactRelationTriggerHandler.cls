public class AccountContactRelationTriggerHandler {

    /*
     * Patrick Currin
     * Belkbot Solutions, LLC
     * Created March 2024
     * 
     * 1. Disallows adding a new AccountContactRelation from coming into being if not added by the 
     * "T&S Brass - Syteline Integration"-named profile. 
     * 
     * 2. Disallows adding or removing AccountContactRelations for a contact, if the Contact previously engaged is
     * an "E-Store" contact (E-Store is True)
     * 
     * 
     */ 
    
    private List<AccountContactRelation> acrsNew;
    private List<AccountContactRelation> acrsOld;
    
    public AccountContactRelationTriggerHandler(){}
    
    public AccountContactRelationTriggerHandler(List<AccountContactRelation> acrsNew, List<AccountContactRelation> acrsOld){
        this.acrsNew = acrsNew;
        this.acrsOld = acrsOld;
    }
    
    
    
    private Map<String, Id> profileIdsForAllowedRepAgencySecondaryAccountRelations = new Map<String, Id>(); 
    
    @testVisible
    private Set<Id> getSytelineIntegrationProfileIdSet(){
        
        string profileName = 'T&S Brass - Syteline Integration';
        
        try{
            
            if(!profileIdsForAllowedRepAgencySecondaryAccountRelations.keyset().contains(profileName)){
                profileIdsForAllowedRepAgencySecondaryAccountRelations.put(profileName, getSytelineIntegrationProfileId(profileName));
            }
            
            return new Set<Id>(profileIdsForAllowedRepAgencySecondaryAccountRelations.values());
            
        }catch(Exception ex){
            system.debug(ex);
            throw ex;
        }
        
    }
    
    @testVisible
    private Id getSytelineIntegrationProfileId(string profileName){
        
        
        try{
            
            return [SELECT Id FROM Profile WHERE Name = :profileName LIMIT 1].Id;
            
        }catch(Exception ex){
            system.debug(ex);
            throw ex;
        }
        
    }
    
    @testVisible
    private Id getRepAgencyAccountRecordTypeId(){
        return Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName().get('Rep_Agency').getRecordTypeId();        
    }
    
    
    public Boolean isCurrentUserSytelineProfileId(){
        
        // Gets current user profile Id
        Id profileId = UserInfo.getProfileId();
        
        // retrieves rep agency 
        if(getSytelineIntegrationProfileIdSet().contains(profileId)){
            return true;
        }else{
            return false;
        }
        
    }
    
    public void insertAccountContactRelations(){
                
        // This action is allowed for Syteline Integration Users Only
        check_RepAgency_PrimaryAccountRelationships();
        check_EStore_True_PreventNewAccountContactRelationships(); 
        
    }
    
    
    //public void updateAccountContactRelations(){
    //    
    //    check_EStore_True_PreventUpdateOfAccountContactRelationships();
    //    // This action is allowed for Syteline Integration Users Only
    //    
    //}

    public void deleteAccountContactRelations(){
        
        check_EStore_True_PreventDeleteOfAccountContactRelationships();
            // This action is allowed for Syteline Integration Users Only
        
    }
    
    
    private void check_RepAgency_PrimaryAccountRelationships(){
      
        // So, when a contact is initially entered into the system, then they may be assigned directly to a rep agency
        // What we need to do is stop any more ACRs from being inserted by anyone except the Syteline Integration User
        // if that contact is already associated to a primary rep agency.
        
        if(isCurrentUserSytelineProfileId() == false){ 
        // If they were a Syteline Profile then they could do whatever they want, but they aren't so what's next?
        
            List<Contact> contactsNew = new List<Contact>();
            Set<Id> contactNewIds = new Set<Id>();
            for(AccountContactRelation acr : acrsNew){
                contactNewIds.add(acr.ContactId);
            }
            contactsNew = [SELECT Id, FirstName, LastName, Name FROM Contact WHERE Id IN :contactNewIds];
            Map<Id, Contact> mapContactsNew = new Map<Id, Contact>(contactsNew);
            
            List<Account> repAgencies;
            Map<Id, Account> mapRepAgencies = new Map<Id, Account>();
            try{
                Id repAgencyRecTypeId = getRepAgencyAccountRecordTypeId();
                repAgencies = [SELECT Id, Name FROM Account WHERE RecordTypeId = :repAgencyRecTypeId];
                mapRepAgencies = new Map<Id, Account>(repAgencies);
                system.debug('$$$ mapRepAgencies: ' + mapRepAgencies);
            }catch(QueryException qex){
                
            }
            
            // Find any ACRs already associated with the incoming ACRs	
            List<AccountContactRelation> associatedACRs = [SELECT Id,
                                                           ContactId,
                                                           AccountId,
                                                           IsDirect,
                                                           IsActive
                                                           FROM AccountContactRelation
                                                           WHERE IsActive = true
                                                           AND AccountId IN :mapRepAgencies.keyset()
                                                          ];
            Set<Id> repAgencyContactIdSet = new Set<Id>();
            Map<Id, Id> mapRepAgencyContactsToAccountIds = new Map<Id, Id>();
            for(AccountContactRelation acr : associatedACRs){
                repAgencyContactIdSet.add(acr.ContactId);
                mapRepAgencyContactsToAccountIds.put(acr.ContactId, acr.AccountId);
            }
            Set<Id> associatedRepAgencyAccountIds = new Set<Id>();
            for(Id acctId : mapRepAgencyContactsToAccountIds.values()){
                associatedRepAgencyAccountIds.add(acctId);
            }
            List<Account> associatedAccounts = new List<Account>();
            Map<Id, Account> mapAssociatedAccounts = new Map<Id, Account>();
            try{
            	associatedAccounts = [SELECT Id, Name FROM Account WHERE Id IN :associatedRepAgencyAccountIds];
            }catch(QueryException ex){
                
            }
            mapAssociatedAccounts = new Map<Id, Account>(associatedAccounts);
            
            system.debug('mapAssociatedAccounts: ' + mapAssociatedAccounts);
        
            
            
            for(AccountContactRelation acrnew : acrsNew){
                
                if(repAgencyContactIdSet.contains(acrnew.ContactId)){
                    
                    Contact c = mapContactsNew.get(acrnew.ContactId);
                    
                    Id repAcctId = mapRepAgencyContactsToAccountIds.get(acrnew.ContactId);
                    system.debug('$$$ Con\'s repAcctId: ' + repAcctId);
                    Account repAcct = mapAssociatedAccounts.get(repAcctId);
                    system.debug('$$$ repAcct: ' + repAcct);
                    
                    string errorMessage = '$$$ Contact ([' + c.Id + ']' + c.Name + ') already a primary Rep Agency relation in the system([' + repAcct.Id + ']' + repAcct.Name + '). Only Syteline Integration Users can add secondary Rep Agency relationships in Salesforce, because downstream it will cause data visibility issues with the Syteline Database. Please speak with an administrator if this is a problem. ';
            
                    
                    acrnew.addError(errorMessage);
                }   
                
                
            }
        
        }
    }
        
        
    private void check_EStore_True_PreventNewAccountContactRelationships(){
        
        if(isCurrentUserSytelineProfileId() == false){ 
            
            Set<Id> contactIds = new Set<Id>();
            // All ContactIds
            for(AccountContactRelation acr : acrsNew){
                contactIds.add(acr.ContactId);                
            }
            
            List<Contact> contacts = [SELECT Id, E_Store__c FROM Contact WHERE Id IN :contactIds];
            Map<Id, Contact> mapIdToContact = new Map<Id, Contact>(contacts);
            
            
            for(AccountContactRelation acr : acrsNew){
             
                Contact tempCon = mapIdToContact.get(acr.ContactId);
                    
                // This maintains an inability for any non-SI-Users tpo create a new relation if the contact has EStore = true
                if(tempCon.E_Store__c == true){
                    acr.addError('This AccountContactRelation cannot be INSERTED because only Syteline Integration Profile Users are allowed to change relations for E-Store Contacts ... ');
                }
                
            }
            
        }
        
    }
    
    
    
    
    public void check_EStore_True_PreventDeleteOfAccountContactRelationships(){
        
        if(isCurrentUserSytelineProfileId() == false){ 
            
            Set<Id> contactIds = new Set<Id>();
            // All ContactIds
            for(AccountContactRelation acr : acrsOld){
                contactIds.add(acr.ContactId);                
            }
            
            List<Contact> contacts = [SELECT Id, E_Store__c FROM Contact WHERE Id IN :contactIds];
            Map<Id, Contact> mapIdToContact = new Map<Id, Contact>(contacts);
            
            
            for(Integer i = 0; i < acrsOld.size(); i++){
                
                Contact tempCon = mapIdToContact.get(acrsOld[i].ContactId);
                
                // This maintains an inability for any non-SI-Users tpo create a new relation if the contact has EStore = true
                if(tempCon.E_Store__c == true){
                    acrsOld[i].addError('This AccountContactRelation cannot be DELETED because only Syteline Integration Profile Users are allowed to change relations for E-Store Contacts ... ');
                }
                
            }
            
        }
        
    }
    
    
    
    
    
}