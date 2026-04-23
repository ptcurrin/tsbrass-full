trigger QuoteLineTrigger on QuoteLineItem (before insert, before update) {

    List<QuoteLineItem> qlisToSave = new List<QuoteLineItem>();
    
    if(Trigger.isBefore){
        for(QuoteLineItem qli : Trigger.New){
            
            if(qli.TotalPrice != null){
                qli.Total_Price_UADFormat__c = 'د.إ‎' + qli.TotalPrice;
                qlisToSave.add(qli);
            }
            
        }
        
    }
    
}