public class BOARDCustomAccountIterable implements Iterable<Account>{ 

    public BOARDCustomAccountIterable(){}
    
    public BOARDCustomAccountIterable(Integer testLimit){
        this.testLimit = testLimit;
    }
    
    private Integer testLimit;
    
    public Iterator<Account> iterator(){
        
        BOARD_API bapi = new BOARD_API();        
        List<Account> acctsForUpdate = bapi.GETDATA_for_YTDSalesUpdate(testLimit);
        system.debug('BOARDCustomAccountIterable NUM ACCOUNTS PASSED: ' + acctsForUpdate.size());
        BOARDCustomAccountIterator bai = new BOARDCustomAccountIterator(acctsForUpdate);
    
        return bai;
        
    }
    
    
}