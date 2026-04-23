public class EmailMessagesRelationStation {

    public Id relatedId {get;set;}
    List<EmailMessage> messages {get;set;}
    public boolean returnNoPreviousBodyStrings {get;set;}
    
    public EmailMessagesRelationStation(Id relatedIdIn){
        this.relatedId = relatedIdIn;
        
        returnNoPreviousBodyStrings = false;
        if (String.valueOf(this.relatedId).startsWith('006')) {
            
            Opportunity o = [SELECT Id,
                            Quote_Email_Body_Do_Not_Append_Previous__c 
                            FROM Opportunity
                            WHERE Id = :this.relatedId];
            
            returnNoPreviousBodyStrings = o.Quote_Email_Body_Do_Not_Append_Previous__c;
            
            System.debug('That Id is an Opportunity Id.');
        }
        
        
        messages = new List<EmailMessage>();
        
        try{
            
            messages = [SELECT Id,
                        BccAddress,
                        CCAddress,
                        CreatedById,
                        CreatedDate,
                        FirstOpenedDate,
                        ValidatedFromAddress,
                        FromAddress,
                        FromName,
                        HasAttachment,
                        Headers,
                        HtmlBody,
                        //Initial_OppQuote_Send_Date__c,
                        IsExternallyVisible,
                        Incoming,
                        LastModifiedById,
                        LastModifiedDate,
                        LastOpenedDate,
                        MessageDate,
                        MessageIdentifier,
                        ParentId,
                        RelatedToId,
                        Status,
                        Subject,
                        TextBody,
                        ToAddress
                        FROM EmailMessage
                        WHERE RelatedToId = :this.relatedId
                        ORDER BY MessageDate DESC
                       ];            
            
            for(EmailMessage mssg : messages){
                
                system.debug('EmailMessagesRelationStation: ' + mssg.MessageDate + ' - '  + mssg.Subject);
                
            }
            
        }catch(QueryException qex){
            
            system.debug('QEX: ' + qex);
            throw qex;
            
        }   
        
        
        
    }
    
    public Boolean hasMessages(){
        
        if(!messages.isEmpty()){
            return true;
        }else{
            return false;
        }
        
    }
    
    public List<EmailMessage> getMessages(){
        
        for(EmailMessage em : messages){
            system.debug('ALLMessages: ' + em.MessageDate + ' - ' + em.Subject);
        }
        
        return messages;
        
    }
    
    public EmailMessage getLatestRelatedMessage(){
        
        system.debug('Station.getLastRelatedMessage: ' + messages[0].MessageDate);
        system.debug('Station.getLastRelatedMessage: ' + messages[0]);
        
        if(messages.isEmpty()){
            return null;
        }
        
        return messages[0];
        
    }
    
    public EmailMessage getOldestRelatedMessage(){
        
        system.debug('Station.getOldestRelatedMessage: ' + messages[messages.size() - 1]);
        
        if(messages.isEmpty()){
            return null;
        }
        
        return messages[messages.size() - 1];
        
    }
    
    public String generatePreviousRichTextHTMLBodies(){
        
        String pastMessages = '';
        
        if(messages == null || messages.isEmpty()){
            
        }else{
            for(EmailMessage m : messages){
                if(m.HtmlBody != null){
                    pastMessages += '<br><br>' + m.MessageDate + '<br>' + m.HTMLBody;
                }
            }
        }
        
        system.debug('pastMessage.Length: ' + pastMessages.length());
        
        if(returnNoPreviousBodyStrings == true){
            return '';
        }
        
        return pastMessages;
    }
    
    /*
    public String generatePreviousRichTextHTMLBodiesStacked(){
        
        String pastMessages = '';
        integer counter = 0;
        if(messages == null || messages.isEmpty()){
            
        }else{
            
            string chr = '--';
            string currentCHR = '';
            
            
            for(EmailMessage m : messages){
                
                for(integer i = 0; i < counter; i++){
                    currentCHR += chr;
                }
                string htmlbody = m.HTMLBody;
                htmlbody = htmlbody.replaceAll('<br>', '<br><p>' + currentCHR);
                if(m.HtmlBody != null){
                    pastMessages += '<br><br><p>' + currentCHR + m.MessageDate + '<br>' + HTMLBody + '</p>';
                }
                
                currentCHR = '';
                counter++;
            }
        }
        
        return pastMessages;
    }
    */
}