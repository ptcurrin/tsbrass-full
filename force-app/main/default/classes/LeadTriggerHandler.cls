public class LeadTriggerHandler {
    
    private List<Lead> new_RecordType_ConvertedLeads;
    private List<LeadConvertedDuplicationField__mdt> fieldList;
    
    private List<Lead> newLeads;
    private List<Lead> oldLeads;
    private Map<Id,Lead> mapNewLeads;
    private Map<Id,Lead> mapOldLeads;
    
    public LeadTriggerHandler(List<Lead> newLeads,  Map<Id,Lead> mapNewLeads, Map<Id,Lead> mapOldLeads, List<Lead> oldLeads){
        
        new_RecordType_ConvertedLeads = new List<Lead>();
        
        this.newLeads = newLeads;
        this.mapNewLeads = mapNewLeads;
        this.oldLeads = oldLeads;
        this.mapOldLeads = mapOldLeads;
        
        this.fieldList = [SELECT Id,
                          DeveloperName,
                          FromFieldDeveloperName__c,
                          ToFieldDeveloperName__c
                          FROM LeadConvertedDuplicationField__mdt
                         ];
        
    }
    
    public void onTriggerAfterUpdate(){
        
        for(Lead newLead : this.newLeads){
            
            Lead oldLead = mapOldLeads.get(newLead.Id);
            system.debug('oldLead converted?: ' + oldLead.IsConverted);
            system.debug('newLead converted?: ' + newLead.IsConverted + ' >>> ' + newLead.Status);
            
            if(isPresentLeadBeingConverted(newLead, oldLead)){ 
                
                buildRecordLead(newLead);
                
                
                
            }
            
            
            
        }
        
        List<Database.SaveResult> results;
            
        if(!new_RecordType_ConvertedLeads.isEmpty()){
        	results = Database.insert(new_RecordType_ConvertedLeads);
        }
        
        if(results != null && !results.isEmpty()){
            
            Set<Id> leadResultsSet = new Set<Id>();
            for(Database.SaveResult sr : results){
                if(sr.isSuccess()){
                    leadResultsSet.add(sr.getId());
                }
            }
            
            List<Lead> leadsSuccess = new List<Lead>();
            
            try{
                
                leadsSuccess = [SELECT Id, 
                                Converted_Contact__c, 
                                eContacts__Business_Card__c,
                                eContacts__Secondary_Image__c,
                                eContacts__Signature_Image__c
                                FROM Lead WHERE Id IN :leadResultsSet];
                
            }catch(Exception ex){
                
            }
            
            for(Lead newestLead : leadsSuccess){
                
                if(newestLead.Converted_Contact__c != null ){
                    Contact c = new Contact();
                    c.Id = newestLead.Converted_Contact__c;
                    c.eContacts__Business_Card__c = newestLead.eContacts__Business_Card__c;
                    c.eContacts__Secondary_Image__c = newestLead.eContacts__Secondary_Image__c;
                    c.eContacts__Signature_Image__c = newestLead.eContacts__Signature_Image__c;
                    update(c);
                }
                
            }
        }
    }
    
    private boolean isPresentLeadBeingConverted(Lead newLead, Lead oldLead){
        
        if(newLead.IsConverted && oldLead.IsConverted == false){
            return true;
        }
        return false;
    }
    
    private void buildRecordLead(Lead presentLead){
        
        Lead newConvertedLead = new Lead();
        newConvertedLead.Status = 'Qualified Read Only';
        
        for(LeadConvertedDuplicationField__mdt field : this.fieldList){
            
            system.debug('$$$ TO: ' + field.ToFieldDeveloperName__c + ', ' + 'FROM: ' + field.FromFieldDeveloperName__c);
            system.debug('$$$ [' + field.ToFieldDeveloperName__c + '] VAL >>>  ' + presentLead.get(field.FromFieldDeveloperName__c));
            
            newConvertedLead.put(field.ToFieldDeveloperName__c, presentLead.get(field.FromFieldDeveloperName__c));
        
        }
        
        // This was instantiated on construction, so it can be added to
        new_RecordType_ConvertedLeads.add(newConvertedLead);
        
    } 
        
    
}