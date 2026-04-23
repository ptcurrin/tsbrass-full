trigger Pricebook2Trigger on Pricebook2 (before insert, before update) {

    
    
    for(Pricebook2 pb : Trigger.New){
        
        string newConcatName = '';
        
        if(pb.Quote_Object_Name_Concatenation__c != null){
            newConcatName += pb.Quote_Object_Name_Concatenation__c + ' ';
        }
        
        if(pb.Price_book_Country__c != null){
            newConcatName += pb.Price_book_Country__c + ' ';
        }
        
        if(pb.Calendar_Month__c != null){
            newConcatName += pb.Calendar_Month__c + ' ';
        }
        
        
        if(pb.Calendar_Year__c != null){
            newConcatName += pb.Calendar_Year__c + ' ';
        } 
        
        newConcatName += 'Price Book';
        
        if(newConcatName != pb.Name){
            pb.Name = newConcatName;
        }
        
    }
    
}