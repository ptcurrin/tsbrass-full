public class BOARDCustomAccountIterator implements Iterator<Account>{ 

    private List<Account> accounts = new List<Account>();
    private Integer currentIndex;
    
    public BOARDCustomAccountIterator(List<Account> accounts){
        
        this.accounts = accounts;
        this.currentIndex = 0;
    }
    
    public Boolean hasNext(){ 
        return currentIndex < accounts.size();
    }    
     
    public Account next(){
        if(hasNext()) {
            return accounts[currentIndex++];
        } else {
            throw new NoSuchElementException('Iterator has no more elements.');
        }
    } 
    
}