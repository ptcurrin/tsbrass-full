public class OpportunityIterator implements Iterator<Opportunity> {
    
    private List<Opportunity> opportunities;
    private Integer index;

    public OpportunityIterator(List<Opportunity> opportunities){
        this.opportunities = opportunities;
        this.index = 0;
    }
    
    public boolean hasNext(){
        return index < opportunities.size();
    }
    
    public Opportunity next(){
        if(hasNext()){
            return opportunities[index++];
        }else{
            throw new NoSuchElementException('Iterator has no more Opportunities. ');
        }
    }
    
    public class NoSuchElementException extends Exception {}
}