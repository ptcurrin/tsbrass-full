@isTest
public class BOARD_API_Test {

    
    static testmethod void SUCCESS_GETDATA_for_YTDSalesUpdate(){
        
        BOARD_API_MOCKS.isSuccessTokenCallout = true;
        BOARD_API_MOCKS.isSuccessListCallout = true;
        
        Test.setMock(HttpCalloutMock.class, new BOARD_API_MOCKS());
        
        BOARD_API bapi = new BOARD_API();
        
        bapi.GETDATA_for_YTDSalesUpdate(null);
        
    }
    
    
     
    static testmethod void FAILED_GETDATA_for_YTDSalesUpdate(){
        
        BOARD_API_MOCKS.isSuccessTokenCallout = true;
        BOARD_API_MOCKS.isSuccessListCallout = false;
         
        Test.setMock(HttpCalloutMock.class, new BOARD_API_MOCKS());
        
        BOARD_API bapi = new BOARD_API();
        
        bapi.GETDATA_for_YTDSalesUpdate(null);
        
    }
    
    
    static testmethod void TokenSuccess_AND_BIxSalesSuccess(){
        
        BOARD_API_MOCKS.isSuccessTokenCallout = true;
        
        Test.setMock(HttpCalloutMock.class, new BOARD_API_MOCKS());
        
        BOARD_API bapi = new BOARD_API();
        
        string token = bapi.GET_AccessToken();
        
        BOARD_API_MOCKS.isSuccessListCallout = true;
        
		bapi.GET_BIxSalesxChina(token);        
    }
    
    static testmethod void TokenSuccess_AND_BIxSalesFail(){
        
        BOARD_API_MOCKS.isSuccessTokenCallout = true;
        
        Test.setMock(HttpCalloutMock.class, new BOARD_API_MOCKS());
        
        BOARD_API bapi = new BOARD_API();
        
        string token = bapi.GET_AccessToken();
        
        BOARD_API_MOCKS.isSuccessListCallout = false;
        
		bapi.GET_BIxSalesxChina(token);        
    }

    
    static testmethod void TokenFail(){
        
        BOARD_API_MOCKS.isSuccessTokenCallout = false;
        
        Test.setMock(HttpCalloutMock.class, new BOARD_API_MOCKS());
        
        BOARD_API bapi = new BOARD_API();
        
        try{
        	string token = bapi.GET_AccessToken();
            
            system.assert(false); // should never get here
            
        }catch(Exception ex){}   
    }
    
    
    
    
    
}