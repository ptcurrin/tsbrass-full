//Trigger created by Vision-e to take multiple address lines entered on Scanning queue
//and output to 4 custom fields on Contact object

trigger ConvertAddress on Contact (before insert, before update) {
    //get text for error message shown if line length is more than 50 characters
    eContacts__Settings__c settings = eContacts__Settings__c.getOrgDefaults();
    string warningMsg = '';
    if(settings.Address_Length_Warning_Text__c != '' && settings.Address_Length_Warning_Text__c != null){
        warningMsg = settings.Address_Length_Warning_Text__c;
    }
    else{
        warningMsg = 'Each address line must be less than 50-characters';
    }
        
    list<Contact> updateList = new List<Contact>();
    if(trigger.isInsert && trigger.isBefore){
        for(Contact c : Trigger.new){
            if(c.eContacts__Created_By_eContacts__c == true){
                
                list<string> addparts = new list<string>();
                if(c.MailingStreet != null && c.MailingStreet != ''){
                //split address lines into list
                    addParts = c.MailingStreet.split('\n');
                }
                else{
                    addParts.add('');
                } 
                system.debug('Address Parts:' + addParts);
                
                //make sure that each line is less than 50 characters
                boolean continueUpdate = true;
                for(string line : addParts){
                    system.debug('line: ' + line.length());
                    if(line.length()>50){
                        continueUpdate = false;
                    }
                }
                
                if(continueUpdate == true){
                    if(addParts.size() > 0){
                        c.put('Address_1__c',addParts[0]);
                    }
                    if(addParts.size() > 1){
                        c.put('Address_2__c',addParts[1]);	
                    }
                    if(addParts.size() > 2){
                        c.put('Address_3__c',addParts[2]);	
                    }
                    if(addParts.size() > 3){
                        c.put('Address_4__c',addParts[3]);	
                    }
                    
                    
                    //add record to list to be updated
                    updateList.add(c);
                    
                }
                else {
                    c.addError(warningMsg);
                }
                
                
            }
        }
    }
    if(trigger.isBefore && trigger.isUpdate){
        for(Contact c : Trigger.new){
            Contact oldContact = trigger.oldMap.get(c.Id);
            
            if(c.MailingStreet != oldContact.MailingStreet){
                
                list<string> addparts = new list<string>();
                if(c.MailingStreet != null && c.MailingStreet != ''){
                //split address lines into list
                    addParts = c.MailingStreet.split('\n');
                }
                else{
                    addParts.add('');
                } 
                system.debug('Address Parts:' + addParts);
                
                //make sure that each line is less than 50 characters
                boolean continueUpdate = true;
                for(string line : addParts){
                    system.debug('line: ' + line.length());
                    if(line.length()>50){
                        continueUpdate = false;
                    }
                }
                
                if(continueUpdate == true){
                    //reset custom address
                    c.put('Address_1__c','');
                    c.put('Address_2__c','');
                    c.put('Address_3__c','');
                    c.put('Address_4__c','');
                    if(addParts.size() > 0){
                        c.put('Address_1__c',addParts[0]);
                    }
                    if(addParts.size() > 1){
                        c.put('Address_2__c',addParts[1]);	
                    }
                    if(addParts.size() > 2){
                        c.put('Address_3__c',addParts[2]);	
                    }
                    if(addParts.size() > 3){
                        c.put('Address_4__c',addParts[3]);	
                    }
                   	
                    
                    //add record to list to be updated
                    updateList.add(c);
                    
                }
                else {
                    c.addError(warningMsg);
                }
                
                
            }
        }
       
    }
    
}