@isTest(SeeAllData=true)
public class OpportunityQuoteEmail_FollowupBtcHndTest {

    static testmethod void WhatWillTheSystemDo(){
        
        OpportunityQuoteEmail_FollowupBatch batch = new OpportunityQuoteEmail_FollowupBatch();
        
        Test.startTest();
        
        Database.executeBatch(batch);
        
        Test.stopTest();
        
        
    }
    
}