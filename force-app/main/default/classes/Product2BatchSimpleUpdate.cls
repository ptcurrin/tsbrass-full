global virtual class Product2BatchSimpleUpdate
implements Database.Batchable<SObject>,
           Database.Stateful,
           Database.AllowsCallouts,
           System.Schedulable {

/*         
    Database.executeBatch(
    	new Product2BatchSimpleUpdate(3), // stop after 3 products
    	1                                // scope size MUST be 1
	);
*/   
                        
    // Optional test cap
    private Integer totalLimit;
    private Integer processed = 0;

    // Normal nightly mode
    public Product2BatchSimpleUpdate() {
        this.totalLimit = null;
    }

    // Hand test mode
    public Product2BatchSimpleUpdate(Integer totalLimit) {
        this.totalLimit = totalLimit;
    }

    // Scheduler
    global void execute(System.SchedulableContext ctx) {
        Database.executeBatch(new Product2BatchSimpleUpdate(), 1);
    }

    // START
    global Database.QueryLocator start(Database.BatchableContext bc) {

        Datetime todayStart = Datetime.newInstance(
            Date.today().year(),
            Date.today().month(),
            Date.today().day()
        );

        String q =
            'SELECT Id ' +
            'FROM Product2 ' +
            'WHERE IsActive = true ' +
            'AND (Spec_Last_Checked_At__c = null ' +
            'OR Spec_Last_Checked_At__c < :todayStart) ' +
            'ORDER BY ProductCode';

        // Optional hard cap for testing
        if (totalLimit != null) {
            q += ' LIMIT ' + totalLimit;
        }

        return Database.getQueryLocator(q);
    }

    // EXECUTE (always 1 record per run)
    global void execute(Database.BatchableContext bc, List<Product2> scope) {

        // Safety stop
        if (totalLimit != null && processed >= totalLimit) {
            return;
        }

        Product2 p = scope[0];

        new HttpGETCalloutForPDFFileStorage(p.Id)
            .addFileToProduct();

        processed++;
    }

    // FINISH
    global void finish(Database.BatchableContext bc) {
        // Nothing needed
    }
}