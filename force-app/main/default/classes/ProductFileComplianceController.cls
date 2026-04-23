public without sharing class ProductFileComplianceController {
    
    // ---- Security Gate ----
    private static void requireAccess() {
        if (!FeatureManagement.checkPermission('Product_Cleanup_PDF_Access')) {
            // Custom Permission API name
            throw new AuraHandledException('You do not have access to this tool.');
        }
    }
    
    public class ComplianceStats {
        @AuraEnabled public Integer totalActive;
        @AuraEnabled public Integer clean;
        @AuraEnabled public Integer missingCanonical;
        @AuraEnabled public Integer duplicated;
        @AuraEnabled public Integer empty;
    }
    
    
    public class ComplianceRow {
        @AuraEnabled public Id productId;
        @AuraEnabled public String productCode;
        @AuraEnabled public String productName;
        
        @AuraEnabled public String canonicalDocId;
        @AuraEnabled public Datetime canonicalSetAt;
        @AuraEnabled public Boolean hasCanonical;
        
        @AuraEnabled public Integer linkedSpecPdfDocs; // per criteria: latest is PDF + title endswith .PDF
        @AuraEnabled public Boolean isSingleDoc;
        
        @AuraEnabled public String status; // CLEAN / MISSING_CANONICAL / DUPLICATED / EMPTY
    }
    

    
    public class CompliancePage {
        @AuraEnabled public List<ComplianceRow> rows;
        @AuraEnabled public Integer pageNumber;
        @AuraEnabled public Integer pageSize;
        @AuraEnabled public Integer returnedCount;
        @AuraEnabled public Boolean hasMore;
        
        // NEW
        @AuraEnabled public Integer totalFound;
        @AuraEnabled public String rangeLabel;   // e.g. "51-75"
    }

    
    
    
    public class DocLinkRow {
        @AuraEnabled public Id contentDocumentLinkId;
        @AuraEnabled public Id contentDocumentId;
        @AuraEnabled public Id linkedEntityId;
        @AuraEnabled public String linkedEntityLabel;
        
        @AuraEnabled public String linkedEntityType;
        @AuraEnabled public String shareType;
        @AuraEnabled public String visibility;
    }
    
    
    @AuraEnabled(cacheable=true)
    public static ComplianceStats getComplianceStats() {
        requireAccess();
        
        ComplianceStats s = new ComplianceStats();
        s.totalActive = (Integer)Database.countQuery('SELECT COUNT() FROM Product2 WHERE IsActive = true');
        
        // Aggregate qualifying spec-PDF links per Product2 (by LinkedEntityId)
        // Key idea: filter ContentDocumentId via semi-join to ContentVersion(IsLatest PDF)
        List<AggregateResult> agg = [
            SELECT LinkedEntityId pid, COUNT_DISTINCT(ContentDocumentId) c
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN (SELECT Id FROM Product2 WHERE IsActive = true)
            AND ContentDocumentId IN (
                SELECT ContentDocumentId
                FROM ContentVersion
                WHERE IsLatest = true
                AND (FileExtension = 'pdf' OR FileType = 'PDF')
            )
            GROUP BY LinkedEntityId
        ];
        
        Set<Id> oneSpec = new Set<Id>();
        Integer duplicated = 0;
        Integer atLeastOne = 0;
        
        for (AggregateResult ar : agg) {
            Id pid = (Id)ar.get('pid');
            Integer c = (Integer)ar.get('c');
            if (c == null) continue;
            if (c > 0) atLeastOne++;
            if (c == 1) oneSpec.add(pid);
            if (c > 1) duplicated++;
        }
        
        s.duplicated = duplicated;
        s.empty = s.totalActive - atLeastOne;
        
        // Now split the "exactly 1 spec PDF" products into CLEAN vs MISSING_CANONICAL
        Integer clean = 0;
        Integer missing = 0;
        
        if (!oneSpec.isEmpty()) {
            for (Product2 p : [
                SELECT Id, Canonical_Spec_Content_Document_Id__c
                FROM Product2
                WHERE Id IN :oneSpec
            ]) {
                if (String.isBlank(p.Canonical_Spec_Content_Document_Id__c)) missing++;
                else clean++;
            }
        }
        
        s.clean = clean;
        s.missingCanonical = missing;
        
        return s;
    }
    
    
    
    
    
    
    @AuraEnabled(cacheable=true)
    public static CompliancePage getCompliancePage(String searchTerm, String mode, Integer pageNumber, Integer pageSize) {
        
        System.debug('String searchTerm: ' + searchTerm);
        System.debug('String mode: ' + mode);
        System.debug('Integer pageNumber: ' + pageNumber);
        System.debug('Integer pageSize: ' + pageSize);
        
        requireAccess();
        
        if (pageNumber == null || pageNumber < 1) pageNumber = 1;
        if (pageSize == null || pageSize < 10) pageSize = 25;
        if (pageSize > 100) pageSize = 100;
        
        String term = (searchTerm == null) ? '' : searchTerm.trim();
        String likeTerm = '%' + term + '%';
        mode = String.isBlank(mode) ? 'ALL' : mode;
        
        Integer offsetRows = (pageNumber - 1) * pageSize;
        
        // Qualifying spec PDF docs = latest ContentVersion is PDF
        String qualifyingPdfDocSubquery =
            'SELECT ContentDocumentId FROM ContentVersion ' +
            'WHERE IsLatest = true AND (FileExtension = \'pdf\' OR FileType = \'PDF\')';
        
        // Common search fragment (dynamic SOQL-safe via bind variables)
        String searchWhere = '';
        if (term.length() >= 2) {
            searchWhere = ' AND (Name LIKE :likeTerm OR ProductCode LIKE :likeTerm)';
        }
        
        List<Product2> products = new List<Product2>();
        Integer totalFound = 0;
        
        // IMPORTANT:
        // You cannot use GROUP BY / HAVING inside a semi-join subquery in SOQL.
        // So for DUPLICATED / CLEAN / MISSING_CANONICAL we do a 2-step:
        //   (1) Aggregate ContentDocumentLink to get Product2 Ids
        //   (2) Query Product2 with Id IN :ids + paging
        
        if (mode == 'DUPLICATED') {
            
            Set<Id> dupProductIds = new Set<Id>();
            for (AggregateResult ar : [
                SELECT LinkedEntityId pid
                FROM ContentDocumentLink
                WHERE LinkedEntityId IN (SELECT Id FROM Product2 WHERE IsActive = true)
                AND ContentDocumentId IN (
                    SELECT ContentDocumentId
                    FROM ContentVersion
                    WHERE IsLatest = true
                    AND (FileExtension = 'pdf' OR FileType = 'PDF')
                )
                GROUP BY LinkedEntityId
                HAVING COUNT_DISTINCT(ContentDocumentId) > 1
            ]) {
                dupProductIds.add((Id)ar.get('pid'));
            }
            
            if (!dupProductIds.isEmpty()) {
                String countSoql =
                    'SELECT COUNT() FROM Product2 ' +
                    'WHERE IsActive = true AND Id IN :dupProductIds' + searchWhere;
                totalFound = Database.countQuery(countSoql);
            }
            
            if (dupProductIds.isEmpty() || totalFound == 0) {
                CompliancePage empty = new CompliancePage();
                empty.rows = new List<ComplianceRow>();
                empty.pageNumber = pageNumber;
                empty.pageSize = pageSize;
                empty.returnedCount = 0;
                empty.hasMore = false;
                empty.totalFound = 0;
                empty.rangeLabel = '0-0';
                return empty;
            }
            
            String soql =
                'SELECT Id, Name, ProductCode, Canonical_Spec_Content_Document_Id__c, Canonical_Spec_Set_At__c ' +
                'FROM Product2 ' +
                'WHERE IsActive = true AND Id IN :dupProductIds' + searchWhere + ' ' +
                'ORDER BY ProductCode ' +
                'LIMIT :pageSize OFFSET :offsetRows';
            
            products = Database.query(soql);
            
        } else if (mode == 'EMPTY') {
            
            // EMPTY can be expressed as a legal semi-join (no aggregates)
            String countSoql =
                'SELECT COUNT() FROM Product2 ' +
                'WHERE IsActive = true' + searchWhere +
                ' AND Id NOT IN (' +
                '   SELECT LinkedEntityId FROM ContentDocumentLink ' +
                '   WHERE ContentDocumentId IN (' + qualifyingPdfDocSubquery + ')' +
                ' )';
            totalFound = Database.countQuery(countSoql);
            
            if (totalFound == 0) {
                CompliancePage empty = new CompliancePage();
                empty.rows = new List<ComplianceRow>();
                empty.pageNumber = pageNumber;
                empty.pageSize = pageSize;
                empty.returnedCount = 0;
                empty.hasMore = false;
                empty.totalFound = 0;
                empty.rangeLabel = '0-0';
                return empty;
            }
            
            String soql =
                'SELECT Id, Name, ProductCode, Canonical_Spec_Content_Document_Id__c, Canonical_Spec_Set_At__c ' +
                'FROM Product2 ' +
                'WHERE IsActive = true' + searchWhere +
                ' AND Id NOT IN (' +
                '   SELECT LinkedEntityId FROM ContentDocumentLink ' +
                '   WHERE ContentDocumentId IN (' + qualifyingPdfDocSubquery + ')' +
                ' ) ' +
                'ORDER BY ProductCode ' +
                'LIMIT :pageSize OFFSET :offsetRows';
            
            products = Database.query(soql);
            
        } else if (mode == 'MISSING_CANONICAL' || mode == 'CLEAN') {
            
            // First: get products with exactly 1 qualifying PDF
            Set<Id> oneSpecProductIds = new Set<Id>();
            for (AggregateResult ar : [
                SELECT LinkedEntityId pid
                FROM ContentDocumentLink
                WHERE LinkedEntityId IN (SELECT Id FROM Product2 WHERE IsActive = true)
                AND ContentDocumentId IN (
                    SELECT ContentDocumentId
                    FROM ContentVersion
                    WHERE IsLatest = true
                    AND (FileExtension = 'pdf' OR FileType = 'PDF')
                )
                GROUP BY LinkedEntityId
                HAVING COUNT_DISTINCT(ContentDocumentId) = 1
            ]) {
                oneSpecProductIds.add((Id)ar.get('pid'));
            }
            
            if (oneSpecProductIds.isEmpty()) {
                CompliancePage empty = new CompliancePage();
                empty.rows = new List<ComplianceRow>();
                empty.pageNumber = pageNumber;
                empty.pageSize = pageSize;
                empty.returnedCount = 0;
                empty.hasMore = false;
                empty.totalFound = 0;
                empty.rangeLabel = '0-0';
                return empty;
            }
            
            // Then: split based on canonical field using normal Product2 filters
            String canonicalWhere = (mode == 'MISSING_CANONICAL')
                ? ' AND Canonical_Spec_Content_Document_Id__c = null'
                : ' AND Canonical_Spec_Content_Document_Id__c != null';
            
            String countSoql =
                'SELECT COUNT() FROM Product2 ' +
                'WHERE IsActive = true AND Id IN :oneSpecProductIds' +
                canonicalWhere + searchWhere;
            totalFound = Database.countQuery(countSoql);
            
            if (totalFound == 0) {
                CompliancePage empty = new CompliancePage();
                empty.rows = new List<ComplianceRow>();
                empty.pageNumber = pageNumber;
                empty.pageSize = pageSize;
                empty.returnedCount = 0;
                empty.hasMore = false;
                empty.totalFound = 0;
                empty.rangeLabel = '0-0';
                return empty;
            }
            
            String soql =
                'SELECT Id, Name, ProductCode, Canonical_Spec_Content_Document_Id__c, Canonical_Spec_Set_At__c ' +
                'FROM Product2 ' +
                'WHERE IsActive = true AND Id IN :oneSpecProductIds' +
                canonicalWhere + searchWhere + ' ' +
                'ORDER BY ProductCode ' +
                'LIMIT :pageSize OFFSET :offsetRows';
            
            products = Database.query(soql);
            
        } else {
            // ALL (no status filter at the SOQL level; computed for display)
            String countSoql =
                'SELECT COUNT() FROM Product2 ' +
                'WHERE IsActive = true' + searchWhere;
            totalFound = Database.countQuery(countSoql);
            
            if (totalFound == 0) {
                CompliancePage empty = new CompliancePage();
                empty.rows = new List<ComplianceRow>();
                empty.pageNumber = pageNumber;
                empty.pageSize = pageSize;
                empty.returnedCount = 0;
                empty.hasMore = false;
                empty.totalFound = 0;
                empty.rangeLabel = '0-0';
                return empty;
            }
            
            String soql =
                'SELECT Id, Name, ProductCode, Canonical_Spec_Content_Document_Id__c, Canonical_Spec_Set_At__c ' +
                'FROM Product2 ' +
                'WHERE IsActive = true' + searchWhere + ' ' +
                'ORDER BY ProductCode ' +
                'LIMIT :pageSize OFFSET :offsetRows';
            
            products = Database.query(soql);
        }
        
        // --- Everything below stays essentially the same as your original logic ---
        
        Set<Id> productIds = new Set<Id>();
        for (Product2 p : products) productIds.add(p.Id);
        
        // Map product -> docIds linked via ContentDocumentLink
        Map<Id, Set<Id>> docIdsByProduct = new Map<Id, Set<Id>>();
        Set<Id> allDocIds = new Set<Id>();
        
        if (!productIds.isEmpty()) {
            for (ContentDocumentLink cdl : [
                SELECT LinkedEntityId, ContentDocumentId
                FROM ContentDocumentLink
                WHERE LinkedEntityId IN :productIds
            ]) {
                Id pid = cdl.LinkedEntityId;
                if (!docIdsByProduct.containsKey(pid)) docIdsByProduct.put(pid, new Set<Id>());
                docIdsByProduct.get(pid).add(cdl.ContentDocumentId);
                allDocIds.add(cdl.ContentDocumentId);
            }
        }
        
        // Determine which docIds qualify as "spec PDFs" (latest ContentVersion is PDF)
        Set<Id> qualifyingSpecPdfDocIds = new Set<Id>();
        if (!allDocIds.isEmpty()) {
            for (ContentVersion cv : [
                SELECT ContentDocumentId, FileExtension, FileType
                FROM ContentVersion
                WHERE IsLatest = true
                AND ContentDocumentId IN :allDocIds
            ]) {
                if (cv.FileExtension == 'pdf' || cv.FileType == 'PDF') {
                    qualifyingSpecPdfDocIds.add(cv.ContentDocumentId);
                }
            }
        }
        
        List<ComplianceRow> rows = new List<ComplianceRow>();
        
        for (Product2 p : products) {
            Set<Id> linkedDocIds = docIdsByProduct.containsKey(p.Id) ? docIdsByProduct.get(p.Id) : new Set<Id>();
            
            Integer specPdfCount = 0;
            for (Id docId : linkedDocIds) {
                if (qualifyingSpecPdfDocIds.contains(docId)) specPdfCount++;
            }
            
            ComplianceRow r = new ComplianceRow();
            r.productId = p.Id;
            r.productName = p.Name;
            r.productCode = p.ProductCode;
            
            r.canonicalDocId = p.Canonical_Spec_Content_Document_Id__c;
            r.canonicalSetAt = p.Canonical_Spec_Set_At__c;
            r.hasCanonical = !String.isBlank(r.canonicalDocId);
            
            r.linkedSpecPdfDocs = specPdfCount;
            r.isSingleDoc = (specPdfCount == 1);
            
            if (specPdfCount == 0) {
                r.status = 'EMPTY';
            } else if (specPdfCount > 1) {
                r.status = 'DUPLICATED';
            } else if (!r.hasCanonical) {
                r.status = 'MISSING_CANONICAL';
            } else {
                r.status = 'CLEAN';
            }
            
            // Safety guard (should be redundant for non-ALL now)
            if (mode == 'ALL' || mode == r.status) {
                rows.add(r);
            }
        }
        
        // Range label: offset is based on filtered set; end uses returned row count
        Integer startRow = 0;
        Integer endRow = 0;
        if (totalFound > 0 && rows.size() > 0) {
            startRow = offsetRows + 1;
            endRow = Math.min(offsetRows + rows.size(), totalFound);
        }
        String rangeLabel = String.valueOf(startRow) + '-' + String.valueOf(endRow);
        
        CompliancePage page = new CompliancePage();
        page.rows = rows;
        page.pageNumber = pageNumber;
        page.pageSize = pageSize;
        page.returnedCount = rows.size();
        page.hasMore = (offsetRows + products.size()) < totalFound;
        
        page.totalFound = totalFound;
        page.rangeLabel = rangeLabel;
        
        return page;
    }
    
    
    /*
    
    @AuraEnabled(cacheable=true)
    public static CompliancePage getCompliancePage(String searchTerm, String mode, Integer pageNumber, Integer pageSize) {
        requireAccess();
        
        if (pageNumber == null || pageNumber < 1) pageNumber = 1;
        if (pageSize == null || pageSize < 10) pageSize = 25;
        if (pageSize > 100) pageSize = 100;
        
        String term = (searchTerm == null) ? '' : searchTerm.trim();
        String likeTerm = '%' + term + '%';
        mode = String.isBlank(mode) ? 'ALL' : mode;
        
        Integer offsetRows = (pageNumber - 1) * pageSize;
        
        List<Product2> products = (term.length() >= 2)
            ? [
                SELECT Id, Name, ProductCode,
                Canonical_Spec_Content_Document_Id__c ,
                Canonical_Spec_Set_At__c
                FROM Product2
                WHERE IsActive = true
                AND (Name LIKE :likeTerm OR ProductCode LIKE :likeTerm)
                ORDER BY ProductCode
                LIMIT :pageSize OFFSET :offsetRows
            ]
            : [
                SELECT Id, Name, ProductCode,
                Canonical_Spec_Content_Document_Id__c ,
                Canonical_Spec_Set_At__c
                FROM Product2
                WHERE IsActive = true
                ORDER BY ProductCode
                LIMIT :pageSize OFFSET :offsetRows
            ];
                
                Set<Id> productIds = new Set<Id>();
        for (Product2 p : products) productIds.add(p.Id);
        
        // Map product -> docIds linked via ContentDocumentLink
        Map<Id, Set<Id>> docIdsByProduct = new Map<Id, Set<Id>>();
        Set<Id> allDocIds = new Set<Id>();
        
        if (!productIds.isEmpty()) {
            for (ContentDocumentLink cdl : [
                SELECT LinkedEntityId, ContentDocumentId
                FROM ContentDocumentLink
                WHERE LinkedEntityId IN :productIds
            ]) {
                Id pid = cdl.LinkedEntityId;
                if (!docIdsByProduct.containsKey(pid)) docIdsByProduct.put(pid, new Set<Id>());
                docIdsByProduct.get(pid).add(cdl.ContentDocumentId);
                allDocIds.add(cdl.ContentDocumentId);
            }
        }
        
        // Determine which docIds qualify as "spec PDFs":
        // Primary truth: latest ContentVersion is PDF (do NOT depend on Title suffix)
        Set<Id> qualifyingSpecPdfDocIds = new Set<Id>();
        if (!allDocIds.isEmpty()) {
            for (ContentVersion cv : [
                SELECT ContentDocumentId, FileExtension, FileType
                FROM ContentVersion
                WHERE IsLatest = true
                AND ContentDocumentId IN :allDocIds
            ]) {
                if (cv.FileExtension == 'pdf' || cv.FileType == 'PDF') {
                    qualifyingSpecPdfDocIds.add(cv.ContentDocumentId);
                }
            }
        }

        
        List<ComplianceRow> rows = new List<ComplianceRow>();
        
        for (Product2 p : products) {
            Set<Id> linkedDocIds = docIdsByProduct.containsKey(p.Id) ? docIdsByProduct.get(p.Id) : new Set<Id>();
            
            Integer specPdfCount = 0;
            for (Id docId : linkedDocIds) {
                if (qualifyingSpecPdfDocIds.contains(docId)) specPdfCount++;
            }
            
            ComplianceRow r = new ComplianceRow();
            r.productId = p.Id;
            r.productName = p.Name;
            r.productCode = p.ProductCode;
            
            r.canonicalDocId = p.Canonical_Spec_Content_Document_Id__c ;
            r.canonicalSetAt = p.Canonical_Spec_Set_At__c;
            r.hasCanonical = !String.isBlank(r.canonicalDocId);
            
            r.linkedSpecPdfDocs = specPdfCount;
            r.isSingleDoc = (specPdfCount == 1);
            
            if (specPdfCount == 0) {
                r.status = 'EMPTY';
            } else if (specPdfCount > 1) {
                r.status = 'DUPLICATED';
            } else if (!r.hasCanonical) {
                r.status = 'MISSING_CANONICAL';
            } else {
                r.status = 'CLEAN';
            }

            
            if (mode == 'ALL' || mode == r.status) {
                rows.add(r);
            }
        }
        
        CompliancePage page = new CompliancePage();
        page.rows = rows;
        page.pageNumber = pageNumber;
        page.pageSize = pageSize;
        page.returnedCount = rows.size();
        page.hasMore = (products.size() == pageSize);
        return page;
    }
    
    
    */
    
    
    
    // =========================
    // Tab 2 (Read-only) DTOs
    // =========================
    
    public class ProductFileSummary {
        @AuraEnabled public Id productId;
        @AuraEnabled public String productName;
        @AuraEnabled public String productCode;
        @AuraEnabled public String canonicalDocId;
        @AuraEnabled public Datetime canonicalSetAt;
        
        @AuraEnabled public List<SpecPdfDoc> specPdfs;
    }
    
    public class SpecPdfDoc {
        @AuraEnabled public Id contentDocumentId;
        @AuraEnabled public Id latestContentVersionId;
        @AuraEnabled public String title;
        @AuraEnabled public Integer contentSize;
        @AuraEnabled public Datetime lastModifiedDate;
        @AuraEnabled public Integer linkCount;
        @AuraEnabled public String linkTypesSummary; // e.g. "Product2: 1, EmailMessage: 12"
        @AuraEnabled public Datetime contentDocumentCreatedDate; // <-- ADD THIS
    }
    
    // =========================
    // Tab 2 (Read-only) service
    // =========================
    
    @AuraEnabled
    public static ProductFileSummary getProductFileSummary(Id productId) {
        requireAccess();
        
        if (productId == null) {
            throw new AuraHandledException('No product selected.');
        }
        
        Product2 p = [
            SELECT Id, Name, ProductCode,
            Canonical_Spec_Content_Document_Id__c,
            Canonical_Spec_Set_At__c
            FROM Product2
            WHERE Id = :productId
            LIMIT 1
        ];
        
        // 1) Find all ContentDocuments linked to this Product2
        Set<Id> docIds = new Set<Id>();
        for (ContentDocumentLink l : [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :productId
        ]) {
            docIds.add(l.ContentDocumentId);
        }
        
        // 2) Filter to "spec PDFs" by dashboard rule:
        // latest ContentVersion is PDF AND Title (uppercased) ends with ".PDF"
        Map<Id, SpecPdfDoc> docsById = new Map<Id, SpecPdfDoc>();
        
        if (!docIds.isEmpty()) {
            for (ContentVersion cv : [
                SELECT Id, ContentDocumentId, Title, FileExtension, FileType, ContentSize, LastModifiedDate
                FROM ContentVersion
                WHERE IsLatest = true
                AND ContentDocumentId IN :docIds
            ]) {
                if (cv.FileExtension == 'pdf' || cv.FileType == 'PDF') {
                    
                    SpecPdfDoc d = new SpecPdfDoc();
                    d.contentDocumentId = cv.ContentDocumentId;
                    d.latestContentVersionId = cv.Id;
                    d.title = cv.Title;
                    d.contentSize = cv.ContentSize;
                    d.lastModifiedDate = cv.LastModifiedDate;
                    d.linkCount = 0; // fill next
                    docsById.put(cv.ContentDocumentId, d);
                }
            }
        }
        
        // 2b) Pull ContentDocument.CreatedDate for the qualifying docs
        if (!docsById.isEmpty()) {
            Map<Id, ContentDocument> cdById = new Map<Id, ContentDocument>([
                SELECT Id, CreatedDate
                FROM ContentDocument
                WHERE Id IN :docsById.keySet()
            ]);
            
            for (Id did : docsById.keySet()) {
                ContentDocument cd = cdById.get(did);
                if (cd != null) {
                    docsById.get(did).contentDocumentCreatedDate = cd.CreatedDate;
                }
            }
        }
        
        // 3) Count how many links each qualifying doc has (how many entities it’s attached to)
        if (!docsById.isEmpty()) {
            for (AggregateResult ar : [
                SELECT ContentDocumentId docId, COUNT(Id) cnt
                FROM ContentDocumentLink
                WHERE ContentDocumentId IN :docsById.keySet()
                GROUP BY ContentDocumentId
            ]) {
                Id did = (Id) ar.get('docId');
                Integer cnt = (Integer) ar.get('cnt');
                if (docsById.containsKey(did)) {
                    docsById.get(did).linkCount = cnt;
                }
            }
        }
        
        
        // 3b) Build link type breakdown for each doc (Product2 vs EmailMessage vs Task, etc.)
        Map<Id, Map<String, Integer>> typeCountsByDoc = new Map<Id, Map<String, Integer>>();
        
        for (ContentDocumentLink l : [
            SELECT ContentDocumentId, LinkedEntityId
            FROM ContentDocumentLink
            WHERE ContentDocumentId IN :docsById.keySet()
        ]) {
            // Determine the sObject type name from the LinkedEntityId
            String typeName;
            try {
                typeName = String.valueOf(l.LinkedEntityId.getSObjectType().getDescribe().getName());
            } catch (Exception e) {
                // Fallback: prefix only (rare)
                typeName = 'Unknown';
            }
            
            if (!typeCountsByDoc.containsKey(l.ContentDocumentId)) {
                typeCountsByDoc.put(l.ContentDocumentId, new Map<String, Integer>());
            }
            Map<String, Integer> typeCounts = typeCountsByDoc.get(l.ContentDocumentId);
            typeCounts.put(
                typeName,
                (typeCounts.containsKey(typeName) ? typeCounts.get(typeName) : 0) + 1
            );
            
        }
        
        // Write a human-friendly summary string onto each SpecPdfDoc
        for (Id docId : docsById.keySet()) {
            SpecPdfDoc d = docsById.get(docId);
            Map<String, Integer> typeCounts = typeCountsByDoc.get(docId);
            
            if (typeCounts == null || typeCounts.isEmpty()) {
                d.linkTypesSummary = '';
                continue;
            }
            
            List<String> keys = new List<String>();
            keys.addAll(typeCounts.keySet());
            
            keys.sort();
            
            List<String> parts = new List<String>();
            for (String k : keys) {
                parts.add(k + ': ' + String.valueOf(typeCounts.get(k)));
            }
            
            d.linkTypesSummary = String.join(parts, ', ');
        }
        
        
        
        // 4) Build result
        ProductFileSummary s = new ProductFileSummary();
        s.productId = p.Id;
        s.productName = p.Name;
        s.productCode = p.ProductCode;
        s.canonicalDocId = p.Canonical_Spec_Content_Document_Id__c;
        s.canonicalSetAt = p.Canonical_Spec_Set_At__c;
        
        s.specPdfs = new List<SpecPdfDoc>();
        s.specPdfs.addAll(docsById.values());
        
        // Ordering: ContentDocument.CreatedDate desc, then title, then doc id
        s.specPdfs.sort(new SpecPdfDocSorter());
        
        return s;
    }
    
    
    // Helper for deterministic ordering
    public class SpecPdfDocSorter implements System.Comparator<SpecPdfDoc>
    {
        public Integer compare(Object a, Object b) {
            SpecPdfDoc x = (SpecPdfDoc) a;
            SpecPdfDoc y = (SpecPdfDoc) b;
            
            // 1) Primary: ContentDocument.CreatedDate (DESC = newest first)
            Datetime xd = x.contentDocumentCreatedDate;
            Datetime yd = y.contentDocumentCreatedDate;
            
            if (xd != null && yd != null) {
                Long xt = xd.getTime();
                Long yt = yd.getTime();
                if (xt != yt) {
                    return (xt > yt) ? 1 : -1; // DESC
                }
            } else if (xd == null && yd != null) {
                return 1;  // nulls last
            } else if (xd != null && yd == null) {
                return -1; // nulls last
            }
            
            // 2) Secondary: title (case-insensitive)
            String xtitle = x.title == null ? '' : x.title;
            String ytitle = y.title == null ? '' : y.title;
            Integer byTitle = xtitle.toLowerCase().compareTo(ytitle.toLowerCase());
            if (byTitle != 0) return byTitle;
            
            // 3) Tertiary: doc id (stable)
            return String.valueOf(x.contentDocumentId).compareTo(String.valueOf(y.contentDocumentId));
        }
    }

    
    
    
    
    /*
    // Helper for deterministic ordering
    public class SpecPdfDocSorter implements System.Comparator<SpecPdfDoc>
    {
        public Integer compare(Object a, Object b) {
            SpecPdfDoc x = (SpecPdfDoc) a;
            SpecPdfDoc y = (SpecPdfDoc) b;
            
            String xt = x.title == null ? '' : x.title;
            String yt = y.title == null ? '' : y.title;
            
            Integer byTitle = xt.toLowerCase().compareTo(yt.toLowerCase());
            
            if (byTitle != 0) return byTitle;
            
            return String.valueOf(x.contentDocumentId).compareTo(String.valueOf(y.contentDocumentId));
        }
    }*/
    
    
    @AuraEnabled(cacheable=true)
    public static List<DocLinkRow> getLinksForContentDocument(Id contentDocumentId) {
        requireAccess();
        
        if (contentDocumentId == null) {
            throw new AuraHandledException('No ContentDocumentId provided.');
        }
        
        List<DocLinkRow> outRows = new List<DocLinkRow>();
        
        // Collect IDs by type for targeted label queries.
        Map<String, Set<Id>> idsByType = new Map<String, Set<Id>>();
        
        // First pass: fetch the links and record their types.
        for (ContentDocumentLink l : [
            SELECT Id, ContentDocumentId, LinkedEntityId, ShareType, Visibility
            FROM ContentDocumentLink
            WHERE ContentDocumentId = :contentDocumentId
            ORDER BY LinkedEntityId
        ]) {
            DocLinkRow r = new DocLinkRow();
            r.contentDocumentLinkId = l.Id;
            r.contentDocumentId = l.ContentDocumentId;
            r.linkedEntityId = l.LinkedEntityId;
            
            try {
                r.linkedEntityType = String.valueOf(l.LinkedEntityId.getSObjectType().getDescribe().getName());
            } catch (Exception e) {
                r.linkedEntityType = 'Unknown';
            }
            
            r.shareType = l.ShareType;
            r.visibility = l.Visibility;
            r.linkedEntityLabel = ''; // fill later (best-effort)
            outRows.add(r);
            
            if (!idsByType.containsKey(r.linkedEntityType)) {
                idsByType.put(r.linkedEntityType, new Set<Id>());
            }
            idsByType.get(r.linkedEntityType).add(r.linkedEntityId);
        }
        
        // Build a single label map across all supported types.
        Map<Id, String> labelById = new Map<Id, String>();
        
        // ---- Product2 (Name)
        Set<Id> productIds = idsByType.containsKey('Product2') ? idsByType.get('Product2') : new Set<Id>();
        if (!productIds.isEmpty()) {
            for (Product2 p : [SELECT Id, Name FROM Product2 WHERE Id IN :productIds]) {
                labelById.put(p.Id, p.Name);
            }
        }
        
        // ---- EmailMessage (Subject)
        Set<Id> emailIds = idsByType.containsKey('EmailMessage') ? idsByType.get('EmailMessage') : new Set<Id>();
        if (!emailIds.isEmpty()) {
            for (EmailMessage e : [SELECT Id, Subject FROM EmailMessage WHERE Id IN :emailIds]) {
                labelById.put(e.Id, e.Subject);
            }
        }
        
        // ---- Task (Subject)
        Set<Id> taskIds = idsByType.containsKey('Task') ? idsByType.get('Task') : new Set<Id>();
        if (!taskIds.isEmpty()) {
            for (Task t : [SELECT Id, Subject FROM Task WHERE Id IN :taskIds]) {
                labelById.put(t.Id, t.Subject);
            }
        }
        
        // ---- Event (Subject)
        Set<Id> eventIds = idsByType.containsKey('Event') ? idsByType.get('Event') : new Set<Id>();
        if (!eventIds.isEmpty()) {
            for (Event ev : [SELECT Id, Subject FROM Event WHERE Id IN :eventIds]) {
                labelById.put(ev.Id, ev.Subject);
            }
        }
        
        // ---- Account (Name)
        Set<Id> accountIds = idsByType.containsKey('Account') ? idsByType.get('Account') : new Set<Id>();
        if (!accountIds.isEmpty()) {
            for (Account a : [SELECT Id, Name FROM Account WHERE Id IN :accountIds]) {
                labelById.put(a.Id, a.Name);
            }
        }
        
        // ---- Contact (Name)
        Set<Id> contactIds = idsByType.containsKey('Contact') ? idsByType.get('Contact') : new Set<Id>();
        if (!contactIds.isEmpty()) {
            for (Contact c : [SELECT Id, Name FROM Contact WHERE Id IN :contactIds]) {
                labelById.put(c.Id, c.Name);
            }
        }
        
        // ---- Opportunity (Name)
        Set<Id> oppIds = idsByType.containsKey('Opportunity') ? idsByType.get('Opportunity') : new Set<Id>();
        if (!oppIds.isEmpty()) {
            for (Opportunity o : [SELECT Id, Name FROM Opportunity WHERE Id IN :oppIds]) {
                labelById.put(o.Id, o.Name);
            }
        }
        
        // ---- Case (CaseNumber + optional Subject)
        Set<Id> caseIds = idsByType.containsKey('Case') ? idsByType.get('Case') : new Set<Id>();
        if (!caseIds.isEmpty()) {
            for (Case cs : [SELECT Id, CaseNumber, Subject FROM Case WHERE Id IN :caseIds]) {
                String subj = cs.Subject == null ? '' : (' — ' + cs.Subject);
                    labelById.put(cs.Id, cs.CaseNumber + subj);
            }
        }
        
        // ---- User (Name)
        Set<Id> userIds = idsByType.containsKey('User') ? idsByType.get('User') : new Set<Id>();
        if (!userIds.isEmpty()) {
            for (User u : [SELECT Id, Name FROM User WHERE Id IN :userIds]) {
                labelById.put(u.Id, u.Name);
            }
        }
        
        // ---- Group (Name) - queues / public groups
        Set<Id> groupIds = idsByType.containsKey('Group') ? idsByType.get('Group') : new Set<Id>();
        if (!groupIds.isEmpty()) {
            for (Group g : [SELECT Id, Name FROM Group WHERE Id IN :groupIds]) {
                labelById.put(g.Id, g.Name);
            }
        }
        
        // ---- Lead (Name)
        Set<Id> leadIds = idsByType.containsKey('Lead') ? idsByType.get('Lead') : new Set<Id>();
        if (!leadIds.isEmpty()) {
            for (Lead ld : [SELECT Id, Name FROM Lead WHERE Id IN :leadIds]) {
                labelById.put(ld.Id, ld.Name);
            }
        }
        
        // ---- Quote (QuoteNumber preferred, else Name)
        Set<Id> quoteIds = idsByType.containsKey('Quote') ? idsByType.get('Quote') : new Set<Id>();
        if (!quoteIds.isEmpty()) {
            for (Quote q : [SELECT Id, Name, QuoteNumber FROM Quote WHERE Id IN :quoteIds]) {
                String lbl = (q.QuoteNumber != null) ? q.QuoteNumber : q.Name;
                labelById.put(q.Id, lbl);
            }
        }
        
        // ---- Order (OrderNumber)
        Set<Id> orderIds = idsByType.containsKey('Order') ? idsByType.get('Order') : new Set<Id>();
        if (!orderIds.isEmpty()) {
            for (Order od : [SELECT Id, OrderNumber FROM Order WHERE Id IN :orderIds]) {
                labelById.put(od.Id, od.OrderNumber);
            }
        }
        
        // ---- Contract (ContractNumber)
        Set<Id> contractIds = idsByType.containsKey('Contract') ? idsByType.get('Contract') : new Set<Id>();
        if (!contractIds.isEmpty()) {
            for (Contract ct : [SELECT Id, ContractNumber FROM Contract WHERE Id IN :contractIds]) {
                labelById.put(ct.Id, ct.ContractNumber);
            }
        }
        
        // ---- Pricebook2 (Name)
        Set<Id> pricebookIds = idsByType.containsKey('Pricebook2') ? idsByType.get('Pricebook2') : new Set<Id>();
        if (!pricebookIds.isEmpty()) {
            for (Pricebook2 pb : [SELECT Id, Name FROM Pricebook2 WHERE Id IN :pricebookIds]) {
                labelById.put(pb.Id, pb.Name);
            }
        }
        
        // ---- Asset (Name)
        Set<Id> assetIds = idsByType.containsKey('Asset') ? idsByType.get('Asset') : new Set<Id>();
        if (!assetIds.isEmpty()) {
            for (Asset a : [SELECT Id, Name FROM Asset WHERE Id IN :assetIds]) {
                labelById.put(a.Id, a.Name);
            }
        }
        
        // Final pass: attach labels where we have them; otherwise keep blank.
        for (DocLinkRow r : outRows) {
            if (labelById.containsKey(r.linkedEntityId)) {
                r.linkedEntityLabel = labelById.get(r.linkedEntityId);
            } else {
                r.linkedEntityLabel = '';
            }
        }
        
        return outRows;
    }
    
    
    
    
    @AuraEnabled
    public static ProductSpecPdfHashService.AuditResult runHashAuditCallApex(Id productId) {
        
        system.debug('runHashAUDIT on product Id: ' + productId);
        
        requireAccess(); // your custom permission check
        return ProductSpecPdfHashService.auditProduct(productId);
    }
    
    
    
    
    
    
    // =========================
    // Tab 4 (Read-only) DTOs
    // =========================
    public class MergeDiscoveryResult {
        @AuraEnabled public Id productId;
        @AuraEnabled public String productName;
        @AuraEnabled public String productCode;
        
        @AuraEnabled public String canonicalDocId;
        @AuraEnabled public Datetime canonicalSetAt;
        
        @AuraEnabled public List<MergeCandidateRow> candidates;
    }
    
    public class MergeCandidateRow {
        @AuraEnabled public Id contentDocumentId;
        @AuraEnabled public Id latestContentVersionId;
        @AuraEnabled public String title;
        @AuraEnabled public Integer contentSize;
        @AuraEnabled public Datetime lastModifiedDate;
        
        @AuraEnabled public Integer linkCount;
        @AuraEnabled public String linkTypesSummary;
        
        @AuraEnabled public Boolean isCanonical;
        
        // Tab 4 will display this read-only later (from audit join / refresh)
        @AuraEnabled public Boolean hashMatchesIncoming;
        @AuraEnabled public Datetime contentDocumentCreatedDate; // NEW (date + time)
    }
    
    // =========================
    // Tab 4 (Read-only) service
    // =========================
    @AuraEnabled
    public static MergeDiscoveryResult getMergeDiscovery(Id productId) {
        requireAccess();
        
        if (productId == null) {
            throw new AuraHandledException('No product selected.');
        }
        
        // 1) Product + canonical fields
        Product2 p = [
            SELECT Id, Name, ProductCode,
            Canonical_Spec_Content_Document_Id__c,
            Canonical_Spec_Set_At__c
            FROM Product2
            WHERE Id = :productId
            LIMIT 1
        ];
        
        // 2) All docs linked to Product2
        Set<Id> docIds = new Set<Id>();
        for (ContentDocumentLink l : [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :productId
        ]) {
            docIds.add(l.ContentDocumentId);
        }
        
        // 3) Filter to "spec PDFs" by dashboard rule:
        // Latest ContentVersion is PDF AND Title.toUpperCase().endsWith('.PDF')
        Map<Id, MergeCandidateRow> rowsByDocId = new Map<Id, MergeCandidateRow>();
        
        if (!docIds.isEmpty()) {
            for (ContentVersion cv : [
                SELECT Id, ContentDocumentId, Title, FileExtension, FileType, ContentSize, LastModifiedDate
                FROM ContentVersion
                WHERE IsLatest = true
                AND ContentDocumentId IN :docIds
            ]) {
                if (cv.FileExtension == 'pdf' || cv.FileType == 'PDF') {
                    
                    MergeCandidateRow r = new MergeCandidateRow();
                    r.contentDocumentId = cv.ContentDocumentId;
                    r.latestContentVersionId = cv.Id;
                    r.title = cv.Title;
                    r.contentSize = cv.ContentSize;
                    r.lastModifiedDate = cv.LastModifiedDate;
                    
                    r.linkCount = 0;
                    r.linkTypesSummary = '';
                    r.isCanonical = false;
                    r.hashMatchesIncoming = null; // unknown at discovery time
                    
                    rowsByDocId.put(cv.ContentDocumentId, r);
                }
            }
        }
        
        
        // 3b) NEW: Pull ContentDocument.CreatedDate for the qualifying docs
        if (!rowsByDocId.isEmpty()) {
            Map<Id, ContentDocument> cdById = new Map<Id, ContentDocument>([
                SELECT Id, CreatedDate
                FROM ContentDocument
                WHERE Id IN :rowsByDocId.keySet()
            ]);
            
            for (Id did : rowsByDocId.keySet()) {
                ContentDocument cd = cdById.get(did);
                if (cd != null) {
                    rowsByDocId.get(did).contentDocumentCreatedDate = cd.CreatedDate;
                }
            }
        }

        
        
        
        // If nothing qualifies, still return a summary object (empty list)
        if (rowsByDocId.isEmpty()) {
            MergeDiscoveryResult emptyOut = new MergeDiscoveryResult();
            emptyOut.productId = p.Id;
            emptyOut.productName = p.Name;
            emptyOut.productCode = p.ProductCode;
            emptyOut.canonicalDocId = p.Canonical_Spec_Content_Document_Id__c;
            emptyOut.canonicalSetAt = p.Canonical_Spec_Set_At__c;
            emptyOut.candidates = new List<MergeCandidateRow>();
            return emptyOut;
        }
        
        // 4) Link counts per doc
        for (AggregateResult ar : [
            SELECT ContentDocumentId docId, COUNT(Id) cnt
            FROM ContentDocumentLink
            WHERE ContentDocumentId IN :rowsByDocId.keySet()
            GROUP BY ContentDocumentId
        ]) {
            Id did = (Id) ar.get('docId');
            Integer cnt = (Integer) ar.get('cnt');
            if (rowsByDocId.containsKey(did)) {
                rowsByDocId.get(did).linkCount = cnt;
            }
        }
        
        // 5) Link type breakdown (Product2 vs EmailMessage vs etc)
        Map<Id, Map<String, Integer>> typeCountsByDoc = new Map<Id, Map<String, Integer>>();
        
        for (ContentDocumentLink l : [
            SELECT ContentDocumentId, LinkedEntityId
            FROM ContentDocumentLink
            WHERE ContentDocumentId IN :rowsByDocId.keySet()
        ]) {
            String typeName;
            try {
                typeName = String.valueOf(l.LinkedEntityId.getSObjectType().getDescribe().getName());
            } catch (Exception e) {
                typeName = 'Unknown';
            }
            
            if (!typeCountsByDoc.containsKey(l.ContentDocumentId)) {
                typeCountsByDoc.put(l.ContentDocumentId, new Map<String, Integer>());
            }
            
            Map<String, Integer> counts = typeCountsByDoc.get(l.ContentDocumentId);
            counts.put(typeName, (counts.containsKey(typeName) ? counts.get(typeName) : 0) + 1);
        }
        
        // Write summary strings, sorted by type name
        for (Id did : rowsByDocId.keySet()) {
            MergeCandidateRow r = rowsByDocId.get(did);
            Map<String, Integer> typeCounts = typeCountsByDoc.get(did);
            
            if (typeCounts == null || typeCounts.isEmpty()) {
                r.linkTypesSummary = '';
                continue;
            }
            
            List<String> keys = new List<String>();
            keys.addAll(typeCounts.keySet());
            keys.sort();
            
            List<String> parts = new List<String>();
            for (String k : keys) {
                parts.add(k + ': ' + String.valueOf(typeCounts.get(k)));
            }
            r.linkTypesSummary = String.join(parts, ', ');
        }
        
        // 6) Flag canonical row if present and in the candidate set
        String canonicalId = p.Canonical_Spec_Content_Document_Id__c;
        if (!String.isBlank(canonicalId)) {
            try {
                Id canonicalDocId = (Id) canonicalId;
                if (rowsByDocId.containsKey(canonicalDocId)) {
                    rowsByDocId.get(canonicalDocId).isCanonical = true;
                }
            } catch (Exception e) {
                // If field contains a non-Id string somehow, ignore flagging.
            }
        }
        
        // 7) Build result
        MergeDiscoveryResult out = new MergeDiscoveryResult();
        out.productId = p.Id;
        out.productName = p.Name;
        out.productCode = p.ProductCode;
        out.canonicalDocId = p.Canonical_Spec_Content_Document_Id__c;
        out.canonicalSetAt = p.Canonical_Spec_Set_At__c;
        
        out.candidates = new List<MergeCandidateRow>();
        out.candidates.addAll(rowsByDocId.values());
        out.candidates.sort(new MergeCandidateSorter()); // deterministic order
        
        return out;
    }
    
    
    
    public class MergeCandidateSorter implements System.Comparator<MergeCandidateRow> {
        public Integer compare(MergeCandidateRow x, MergeCandidateRow y) {
            
            Datetime xd = (x == null) ? null : x.contentDocumentCreatedDate;
            Datetime yd = (y == null) ? null : y.contentDocumentCreatedDate;
            
            if (xd == null && yd != null) return 1;   // nulls last
            if (xd != null && yd == null) return -1;  // nulls last
            if (xd != null && yd != null) {
                Long xl = xd.getTime();
                Long yl = yd.getTime();
                
                // DESC (newest first)
                if (xl > yl) return -1;
                if (xl < yl) return 1;
            }
            
            String xt = (x == null || x.title == null) ? '' : x.title;
            String yt = (y == null || y.title == null) ? '' : y.title;
            
            Integer byTitle = xt.toLowerCase().compareTo(yt.toLowerCase());
            if (byTitle != 0) return byTitle;
            
            String xid = (x == null || x.contentDocumentId == null) ? '' : String.valueOf(x.contentDocumentId);
            String yid = (y == null || y.contentDocumentId == null) ? '' : String.valueOf(y.contentDocumentId);
            return xid.compareTo(yid);
        }
    }

    
    
    
    /*
    
    public class MergeCandidateSorter implements System.Comparator<MergeCandidateRow> {
        public Integer compare(MergeCandidateRow x, MergeCandidateRow y) {
            
            // NEW: CreatedDate first (nulls last)
            Datetime xd = (x == null) ? null : x.contentDocumentCreatedDate;
            Datetime yd = (y == null) ? null : y.contentDocumentCreatedDate;
            
            if (xd == null && yd != null) return 1;
            if (xd != null && yd == null) return -1;
            if (xd != null && yd != null) {
                Long xl = xd.getTime();
                Long yl = yd.getTime();
                if (xl < yl) return -1;
                if (xl > yl) return 1;
            }
            
            // then Title (case-insensitive)
            String xt = (x == null || x.title == null) ? '' : x.title;
            String yt = (y == null || y.title == null) ? '' : y.title;
            
            Integer byTitle = xt.toLowerCase().compareTo(yt.toLowerCase());
            if (byTitle != 0) return byTitle;
            
            // final tie-breaker: ContentDocumentId
            String xid = (x == null || x.contentDocumentId == null) ? '' : String.valueOf(x.contentDocumentId);
            String yid = (y == null || y.contentDocumentId == null) ? '' : String.valueOf(y.contentDocumentId);
            return xid.compareTo(yid);
        }
    }

    
    }*/
    
    
    public class CanonicalSetResult {
        @AuraEnabled public Id productId;
        @AuraEnabled public String canonicalDocId;
        @AuraEnabled public Datetime canonicalSetAt;
    }
    
    @AuraEnabled
    public static CanonicalSetResult setCanonicalSpecDoc(Id productId, Id contentDocumentId) {
        requireAccess();
        
        if (productId == null) {
            throw new AuraHandledException('No productId provided.');
        }
        if (contentDocumentId == null) {
            throw new AuraHandledException('No contentDocumentId provided.');
        }
        
        // Lock the product row to avoid races with batch/button users
        Product2 p = [
            SELECT Id,
            Canonical_Spec_Content_Document_Id__c,
            Canonical_Spec_Set_At__c
            FROM Product2
            WHERE Id = :productId
            FOR UPDATE
        ];
        
        
        // Validate the chosen doc is linked to this Product2
        List<ContentDocumentLink> links = [
            SELECT Id
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :productId
            AND ContentDocumentId = :contentDocumentId
            LIMIT 1
        ];
        if (links.isEmpty()) {
            throw new AuraHandledException('Selected document is not linked to this product.');
        }
        
        // Validate latest version is a PDF (primary truth; do not depend on Title)
        ContentVersion latest = [
            SELECT Id, FileExtension, FileType
            FROM ContentVersion
            WHERE IsLatest = true
            AND ContentDocumentId = :contentDocumentId
            LIMIT 1
        ];
        if (!(latest.FileExtension == 'pdf' || latest.FileType == 'PDF')) {
            throw new AuraHandledException('Selected document is not a PDF (latest version).');
        }
        
        
        
        // Save canonical doc id
        p.Canonical_Spec_Content_Document_Id__c = (String)contentDocumentId;
        
        // Only set datetime the first time (per your rule)
        if (p.Canonical_Spec_Set_At__c == null) {
            p.Canonical_Spec_Set_At__c = Datetime.now();
        }
        
        update p;
        
        CanonicalSetResult out = new CanonicalSetResult();
        out.productId = p.Id;
        out.canonicalDocId = p.Canonical_Spec_Content_Document_Id__c;
        out.canonicalSetAt = p.Canonical_Spec_Set_At__c;
        return out;
    }
    
    
    
        // =========================
    // Tab 4 (Dry Run) Merge Plan DTOs
    // =========================
    public class MergePlanResult {
        @AuraEnabled public Id productId;
        @AuraEnabled public Id canonicalDocId;

        @AuraEnabled public Integer totalRows;
        @AuraEnabled public Integer deleteCount;
        @AuraEnabled public Integer insertCount;
        @AuraEnabled public Integer skipInsertCount; // canonical link already exists

        
        @AuraEnabled public String expectedTitle;
        @AuraEnabled public Integer eligibleDuplicateDocCount;
        @AuraEnabled public Integer ineligibleDuplicateDocCount;
        @AuraEnabled public List<DuplicateDocPlan> duplicateDocs;
        
    	@AuraEnabled public Boolean allDeletesRepresentedOnCanonical;
   
        @AuraEnabled public List<MergePlanRow> rows;
    }

    // One-to-one plan row: "delete old CDL" + "insert new CDL (maybe)"
    public class MergePlanRow {
        @AuraEnabled public Id sourceDocId;                  // duplicate doc
        @AuraEnabled public Id canonicalDocId;               // canonical doc
        @AuraEnabled public Id contentDocumentLinkIdToDelete;

        @AuraEnabled public Id linkedEntityId;
        @AuraEnabled public String linkedEntityType;
        @AuraEnabled public String linkedEntityLabel;        // best-effort

        @AuraEnabled public String shareType;
        @AuraEnabled public String visibility;

        @AuraEnabled public Boolean willDelete;              // always true for rows we include
        @AuraEnabled public Boolean willInsert;              // false if canonical already linked
        @AuraEnabled public String reason;                   // e.g. "Canonical already linked; delete only"
        
        @AuraEnabled public String sourceDocTitle;     // duplicate doc title
        @AuraEnabled public Id insertCanonicalDocId;   // canonical doc id for insert (if any)
        @AuraEnabled public Id deleteSourceDocId;      // duplicate doc id for delete
        @AuraEnabled public Boolean skippedBecauseProtectedEntity;
        @AuraEnabled public String protectedReason;
        
        @AuraEnabled public Boolean canonicalAlreadyHasLink;
        @AuraEnabled public Boolean deleteNotOnCanonical;
        @AuraEnabled public Boolean representedOnCanonicalAfterPlan;

        
    }
    
    public class DuplicateDocPlan {
        @AuraEnabled public Id duplicateDocId;
        @AuraEnabled public Id latestContentVersionId;
        @AuraEnabled public String title;
        @AuraEnabled public String fileExtension;
        
        @AuraEnabled public Boolean eligibleForDelete;
        @AuraEnabled public String eligibilityReason;
        
        @AuraEnabled public Integer totalLinks;
        @AuraEnabled public Integer plannedDeletes; // # CDL rows we will delete from this doc
        @AuraEnabled public Integer plannedInserts; // # CDL rows we will insert to canonical
    }

    
    @AuraEnabled(cacheable=true)
    public static MergePlanResult getMergePlan(Id productId, Id canonicalDocId) {
        requireAccess();
        
        if (productId == null) throw new AuraHandledException('No product selected.');
        if (canonicalDocId == null) throw new AuraHandledException('No canonicalDocId provided.');
        
        // --- Load ProductCode so we can enforce the "ProductCode.pdf" rule ---
        Product2 p = [
            SELECT Id, ProductCode, Name, Canonical_Spec_Set_At__c, Canonical_Spec_Content_Document_Id__c
            FROM Product2
            WHERE Id = :productId
            LIMIT 1
        ];
        if (String.isBlank(p.ProductCode)) {
            throw new AuraHandledException('Selected product has no ProductCode. Cannot compute expected spec filename.');
        }
        String expectedTitle = (p.ProductCode + '.pdf').toLowerCase();
        
        // Ensure canonicalDocId is linked to this Product at all (cheap sanity)
        Integer canonicalLinkCount = [
            SELECT COUNT()
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :productId
            AND ContentDocumentId = :canonicalDocId
        ];
        if (canonicalLinkCount == 0) {
            throw new AuraHandledException('Selected canonical doc is not linked to this Product. Load candidates again and reselect.');
        }
        
        // 1) Find all ContentDocuments linked to the Product
        Set<Id> productLinkedDocIds = new Set<Id>();
        for (ContentDocumentLink l : [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :productId
        ]) {
            productLinkedDocIds.add(l.ContentDocumentId);
        }
        
        MergePlanResult out = new MergePlanResult();
        out.productId = productId;
        out.canonicalDocId = canonicalDocId;
        out.expectedTitle = expectedTitle;
        out.rows = new List<MergePlanRow>();
        out.duplicateDocs = new List<DuplicateDocPlan>();
        
        if (productLinkedDocIds.isEmpty()) {
            out.totalRows = 0;
            out.deleteCount = 0;
            out.insertCount = 0;
            out.skipInsertCount = 0;
            out.eligibleDuplicateDocCount = 0;
            out.ineligibleDuplicateDocCount = 0;
            return out;
        }
        
        // 2) Get latest ContentVersion for docs linked to Product.
        // We'll use this both for filtering AND for UI titles.
        Map<Id, ContentVersion> latestByDocId = new Map<Id, ContentVersion>();
        for (ContentVersion cv : [
            SELECT Id, ContentDocumentId, FileExtension, Title
            FROM ContentVersion
            WHERE IsLatest = true
            AND ContentDocumentId IN :productLinkedDocIds
        ]) {
            latestByDocId.put(cv.ContentDocumentId, cv);
        }
        
        // Canonical must qualify as PDF + Title ends with .PDF (dashboard rule)
        ContentVersion canonicalLatest = latestByDocId.get(canonicalDocId);
        if (canonicalLatest == null ||
            canonicalLatest.FileExtension != 'pdf' ||
            canonicalLatest.Title == null ||
            !canonicalLatest.Title.toUpperCase().endsWith('.PDF')) {
                throw new AuraHandledException('Selected canonical doc does not qualify as a Spec PDF per dashboard rule.');
            }
        
        // 3) Build the qualifying set (dashboard rule) linked to this product
        Set<Id> qualifyingDocIds = new Set<Id>();
        for (Id docId : productLinkedDocIds) {
            ContentVersion cv = latestByDocId.get(docId);
            if (cv != null && cv.FileExtension == 'pdf' && cv.Title != null && cv.Title.toUpperCase().endsWith('.PDF')) {
                qualifyingDocIds.add(docId);
            }
        }
        
        // Duplicate candidates = qualifying - canonical
        Set<Id> duplicateDocIds = new Set<Id>();
        duplicateDocIds.addAll(qualifyingDocIds);
        duplicateDocIds.remove(canonicalDocId);
        
        if (duplicateDocIds.isEmpty()) {
            out.totalRows = 0;
            out.deleteCount = 0;
            out.insertCount = 0;
            out.skipInsertCount = 0;
            out.eligibleDuplicateDocCount = 0;
            out.ineligibleDuplicateDocCount = 0;
            return out;
        }
        
        // 4) Determine which duplicate docs are eligible for deletion using the strict rule:
        // - latest is pdf
        // - latest title normalized == productCode.pdf
        Set<Id> eligibleDuplicateDocIds = new Set<Id>();
        Integer eligible = 0, ineligible = 0;
        
        for (Id dupDocId : duplicateDocIds) {
            ContentVersion cv = latestByDocId.get(dupDocId);
            DuplicateDocPlan dd = new DuplicateDocPlan();
            dd.duplicateDocId = dupDocId;
            dd.latestContentVersionId = (cv != null) ? cv.Id : null;
            dd.title = (cv != null) ? cv.Title : null;
            dd.fileExtension = (cv != null) ? cv.FileExtension : null;
            
            if (cv == null) {
                dd.eligibleForDelete = false;
                dd.eligibilityReason = 'No latest ContentVersion found.';
                ineligible++;
            } else if (cv.FileExtension != 'pdf') {
                dd.eligibleForDelete = false;
                dd.eligibilityReason = 'Latest version is not a PDF.';
                ineligible++;
            } else if (String.isBlank(cv.Title)) {
                dd.eligibleForDelete = false;
                dd.eligibilityReason = 'Latest Title is blank.';
                ineligible++;
            } else if (cv.Title.toLowerCase() != expectedTitle) {
                dd.eligibleForDelete = false;
                dd.eligibilityReason = 'Title does not match expected spec filename: ' + expectedTitle;
                ineligible++;
            } else {
                dd.eligibleForDelete = true;
                dd.eligibilityReason = 'Eligible (PDF + title matches ' + expectedTitle + ').';
                eligibleDuplicateDocIds.add(dupDocId);
                eligible++;
            }
            
            out.duplicateDocs.add(dd);
        }
        
        out.eligibleDuplicateDocCount = eligible;
        out.ineligibleDuplicateDocCount = ineligible;
        
        // If nothing eligible, we can still return a plan (it will be empty rows)
        if (eligibleDuplicateDocIds.isEmpty()) {
            out.totalRows = 0;
            out.deleteCount = 0;
            out.insertCount = 0;
            out.skipInsertCount = 0;
            return out;
        }
        
        // 5) Canonical existing links (keyed) so we avoid duplicate insert
        Set<String> canonicalKeys = new Set<String>();
        for (ContentDocumentLink l : [
            SELECT LinkedEntityId, ShareType, Visibility
            FROM ContentDocumentLink
            WHERE ContentDocumentId = :canonicalDocId
        ]) {
            canonicalKeys.add(makeLinkKey(l.LinkedEntityId, l.ShareType, l.Visibility));
        }
        
        // 6) Pull all links for eligible duplicate docs
        List<ContentDocumentLink> dupLinks = [
            SELECT Id, ContentDocumentId, LinkedEntityId, ShareType, Visibility
            FROM ContentDocumentLink
            WHERE ContentDocumentId IN :eligibleDuplicateDocIds
            ORDER BY ContentDocumentId, LinkedEntityId
        ];
        
        // 7) Protect certain linked entities from being "moved"
        // - Product2 link: do NOT move/relink product
        // - ContentDocument owner/user-ish links are not usually CDLs, but keep a generic protection hook
        Set<Id> protectedEntityIds = new Set<Id>{ productId };
            
            Map<Id, String> labelById = buildLinkedEntityLabels(dupLinks);
        
        Integer insertCount = 0;
        Integer deleteCount = 0;
        Integer skipInsertCount = 0;
        
        // quick map for duplicate doc titles
        Map<Id, String> titleByDocId = new Map<Id, String>();
        for (Id did : eligibleDuplicateDocIds) {
            ContentVersion cv = latestByDocId.get(did);
            titleByDocId.put(did, cv != null ? cv.Title : null);
        }
        
        // tracking counts per duplicate doc for DuplicateDocPlan rollups
        Map<Id, Integer> totalLinksByDoc = new Map<Id, Integer>();
        Map<Id, Integer> plannedDeletesByDoc = new Map<Id, Integer>();
        Map<Id, Integer> plannedInsertsByDoc = new Map<Id, Integer>();
        
        for (ContentDocumentLink oldLink : dupLinks) {
            totalLinksByDoc.put(oldLink.ContentDocumentId,
                                (totalLinksByDoc.containsKey(oldLink.ContentDocumentId) ? totalLinksByDoc.get(oldLink.ContentDocumentId) : 0) + 1
                               );
            
            // PROTECT: User-linked CDLs (005...) – do not plan delete/insert.
            // These often cannot be deleted (FIELD_INTEGRITY_EXCEPTION).
            if (oldLink.LinkedEntityId != null && String.valueOf(oldLink.LinkedEntityId).startsWith('005')) {
                MergePlanRow r = new MergePlanRow();
                r.sourceDocId = oldLink.ContentDocumentId;
                r.sourceDocTitle = titleByDocId.get(oldLink.ContentDocumentId);
                r.canonicalDocId = canonicalDocId;
                
                r.linkedEntityId = oldLink.LinkedEntityId;
                r.shareType = oldLink.ShareType;
                r.visibility = oldLink.Visibility;
                r.linkedEntityLabel = labelById.get(oldLink.LinkedEntityId);
                
                r.willDelete = false;
                r.willInsert = false;
                r.skippedBecauseProtectedEntity = true;
                r.protectedReason = 'Protected entity (User file share). No relink/delete planned for this CDL.';
                r.reason = 'Skipped.';
                out.rows.add(r);
                continue;
            }

            
            
            // Do not touch protected entities (Product2 link, etc.)
            if (protectedEntityIds.contains(oldLink.LinkedEntityId)) {
                MergePlanRow r = new MergePlanRow();
                r.sourceDocId = oldLink.ContentDocumentId;
                r.sourceDocTitle = titleByDocId.get(oldLink.ContentDocumentId);
                r.canonicalDocId = canonicalDocId;
                
                r.linkedEntityId = oldLink.LinkedEntityId;
                r.shareType = oldLink.ShareType;
                r.visibility = oldLink.Visibility;
                r.linkedEntityLabel = labelById.get(oldLink.LinkedEntityId);
                
                r.willDelete = false;
                r.willInsert = false;
                r.skippedBecauseProtectedEntity = true;
                r.protectedReason = 'Protected entity (Product2 link). No relink/delete planned for this CDL.';
                r.reason = 'Skipped.';
                
                out.rows.add(r);
                continue;
            }
            
            String key = makeLinkKey(oldLink.LinkedEntityId, oldLink.ShareType, oldLink.Visibility);
            Boolean canonicalAlreadyLinked = canonicalKeys.contains(key);
            
            MergePlanRow r2 = new MergePlanRow();
            r2.sourceDocId = oldLink.ContentDocumentId;
            r2.sourceDocTitle = titleByDocId.get(oldLink.ContentDocumentId);
            
            r2.canonicalDocId = canonicalDocId;
            
            // 1-to-1: delete the old link always (for non-protected entities)
            r2.contentDocumentLinkIdToDelete = oldLink.Id;
            r2.deleteSourceDocId = oldLink.ContentDocumentId;
            r2.willDelete = true;
            
            // 1-to-1: insert canonical link only if it doesn't already exist
            r2.insertCanonicalDocId = canonicalDocId;
            r2.willInsert = !canonicalAlreadyLinked;
            
            r2.linkedEntityId = oldLink.LinkedEntityId;
            r2.shareType = oldLink.ShareType;
            r2.visibility = oldLink.Visibility;
            
            try {
                r2.linkedEntityType = String.valueOf(oldLink.LinkedEntityId.getSObjectType().getDescribe().getName());
            } catch (Exception e) {
                r2.linkedEntityType = 'Unknown';
            }
            r2.linkedEntityLabel = labelById.get(oldLink.LinkedEntityId);
            
            r2.reason = canonicalAlreadyLinked
                ? 'Canonical already linked to this entity (same ShareType/Visibility). Delete old link only.'
                : 'Move link to canonical (insert + delete).';
            
            // --- NEW: “coverage” booleans for UI ---
            r2.canonicalAlreadyHasLink = canonicalAlreadyLinked;     // same value you already computed
            r2.deleteNotOnCanonical = !canonicalAlreadyLinked;       // inverse for red flag column
            r2.representedOnCanonicalAfterPlan = canonicalAlreadyLinked || r2.willInsert;
            
            
            out.rows.add(r2);
            
            deleteCount++;
            plannedDeletesByDoc.put(oldLink.ContentDocumentId,
                                    (plannedDeletesByDoc.containsKey(oldLink.ContentDocumentId) ? plannedDeletesByDoc.get(oldLink.ContentDocumentId) : 0) + 1
                                   );
            
            if (r2.willInsert) {
                insertCount++;
                plannedInsertsByDoc.put(oldLink.ContentDocumentId,
                                        (plannedInsertsByDoc.containsKey(oldLink.ContentDocumentId) ? plannedInsertsByDoc.get(oldLink.ContentDocumentId) : 0) + 1
                                       );
            } else {
                skipInsertCount++;
            }
        }
        
        // Roll up counts back into out.duplicateDocs
        for (DuplicateDocPlan dd2 : out.duplicateDocs) {
            Integer t = totalLinksByDoc.get(dd2.duplicateDocId);
            Integer pd = plannedDeletesByDoc.get(dd2.duplicateDocId);
            Integer pi = plannedInsertsByDoc.get(dd2.duplicateDocId);
            
            dd2.totalLinks = (t == null ? 0 : t);
            dd2.plannedDeletes = (pd == null ? 0 : pd);
            dd2.plannedInserts = (pi == null ? 0 : pi);
        }
        
        out.totalRows = out.rows.size();
        out.deleteCount = deleteCount;
        out.insertCount = insertCount;
        out.skipInsertCount = skipInsertCount;
        
        
        
        // --- NEW: overall “safe to delete” flag for UI checkbox ---
        Boolean allCovered = true;
        for (MergePlanRow r : out.rows) {
            if (r != null && r.willDelete == true && r.representedOnCanonicalAfterPlan != true) {
                allCovered = false;
                break;
            }
        }
        out.allDeletesRepresentedOnCanonical = allCovered;

        
        
        
        
        return out;
    }


    private static String makeLinkKey(Id linkedEntityId, String shareType, String visibility) {
        return String.valueOf(linkedEntityId) + '|' +
               String.valueOf(shareType) + '|' +
               String.valueOf(visibility);
    }

    // Best-effort label building (same supported types as your Tab 2 link viewer)
    private static Map<Id, String> buildLinkedEntityLabels(List<ContentDocumentLink> links) {
        Map<String, Set<Id>> idsByType = new Map<String, Set<Id>>();
        for (ContentDocumentLink l : links) {
            String typeName;
            try {
                typeName = String.valueOf(l.LinkedEntityId.getSObjectType().getDescribe().getName());
            } catch (Exception e) {
                typeName = 'Unknown';
            }
            if (!idsByType.containsKey(typeName)) idsByType.put(typeName, new Set<Id>());
            idsByType.get(typeName).add(l.LinkedEntityId);
        }

        Map<Id, String> labelById = new Map<Id, String>();

        Set<Id> productIds = idsByType.get('Product2');
        if (productIds != null && !productIds.isEmpty())
            for (Product2 p : [SELECT Id, Name FROM Product2 WHERE Id IN :productIds]) labelById.put(p.Id, p.Name);

        Set<Id> emailIds = idsByType.get('EmailMessage');
        if (emailIds != null && !emailIds.isEmpty())
            for (EmailMessage e : [SELECT Id, Subject FROM EmailMessage WHERE Id IN :emailIds]) labelById.put(e.Id, e.Subject);

        Set<Id> taskIds = idsByType.get('Task');
        if (taskIds != null && !taskIds.isEmpty())
            for (Task t : [SELECT Id, Subject FROM Task WHERE Id IN :taskIds]) labelById.put(t.Id, t.Subject);

        Set<Id> eventIds = idsByType.get('Event');
        if (eventIds != null && !eventIds.isEmpty())
            for (Event ev : [SELECT Id, Subject FROM Event WHERE Id IN :eventIds]) labelById.put(ev.Id, ev.Subject);

        Set<Id> accountIds = idsByType.get('Account');
        if (accountIds != null && !accountIds.isEmpty())
            for (Account a : [SELECT Id, Name FROM Account WHERE Id IN :accountIds]) labelById.put(a.Id, a.Name);

        Set<Id> contactIds = idsByType.get('Contact');
        if (contactIds != null && !contactIds.isEmpty())
            for (Contact c : [SELECT Id, Name FROM Contact WHERE Id IN :contactIds]) labelById.put(c.Id, c.Name);

        Set<Id> oppIds = idsByType.get('Opportunity');
        if (oppIds != null && !oppIds.isEmpty())
            for (Opportunity o : [SELECT Id, Name FROM Opportunity WHERE Id IN :oppIds]) labelById.put(o.Id, o.Name);

        Set<Id> caseIds = idsByType.get('Case');
        if (caseIds != null && !caseIds.isEmpty())
            for (Case cs : [SELECT Id, CaseNumber, Subject FROM Case WHERE Id IN :caseIds]) {
                String subj = cs.Subject == null ? '' : (' — ' + cs.Subject);
                labelById.put(cs.Id, cs.CaseNumber + subj);
            }

        Set<Id> userIds = idsByType.get('User');
        if (userIds != null && !userIds.isEmpty())
            for (User u : [SELECT Id, Name FROM User WHERE Id IN :userIds]) labelById.put(u.Id, u.Name);

        Set<Id> groupIds = idsByType.get('Group');
        if (groupIds != null && !groupIds.isEmpty())
            for (Group g : [SELECT Id, Name FROM Group WHERE Id IN :groupIds]) labelById.put(g.Id, g.Name);

        Set<Id> leadIds = idsByType.get('Lead');
        if (leadIds != null && !leadIds.isEmpty())
            for (Lead ld : [SELECT Id, Name FROM Lead WHERE Id IN :leadIds]) labelById.put(ld.Id, ld.Name);

        Set<Id> quoteIds = idsByType.get('Quote');
        if (quoteIds != null && !quoteIds.isEmpty())
            for (Quote q : [SELECT Id, Name, QuoteNumber FROM Quote WHERE Id IN :quoteIds]) {
                String lbl = (q.QuoteNumber != null) ? q.QuoteNumber : q.Name;
                labelById.put(q.Id, lbl);
            }

        Set<Id> orderIds = idsByType.get('Order');
        if (orderIds != null && !orderIds.isEmpty())
            for (Order od : [SELECT Id, OrderNumber FROM Order WHERE Id IN :orderIds]) labelById.put(od.Id, od.OrderNumber);

        Set<Id> contractIds = idsByType.get('Contract');
        if (contractIds != null && !contractIds.isEmpty())
            for (Contract ct : [SELECT Id, ContractNumber FROM Contract WHERE Id IN :contractIds]) labelById.put(ct.Id, ct.ContractNumber);

        Set<Id> pricebookIds = idsByType.get('Pricebook2');
        if (pricebookIds != null && !pricebookIds.isEmpty())
            for (Pricebook2 pb : [SELECT Id, Name FROM Pricebook2 WHERE Id IN :pricebookIds]) labelById.put(pb.Id, pb.Name);

        Set<Id> assetIds = idsByType.get('Asset');
        if (assetIds != null && !assetIds.isEmpty())
            for (Asset a : [SELECT Id, Name FROM Asset WHERE Id IN :assetIds]) labelById.put(a.Id, a.Name);

        return labelById;
    }
    
    
    public class MergeExecutionResult {
        @AuraEnabled public Boolean rollbackMode;
        @AuraEnabled public Boolean rolledBack;
        
        @AuraEnabled public Integer insertedLinksAttempted;
        @AuraEnabled public Integer insertedLinksSucceeded;
        @AuraEnabled public Integer deletedLinksAttempted;
        @AuraEnabled public Integer deletedLinksSucceeded;
        
        @AuraEnabled public Integer deletedDocuments; // 0/1
        @AuraEnabled public Boolean deletedDuplicateDoc;
        
        @AuraEnabled public List<LinkInsertOutcome> insertedLinks = new List<LinkInsertOutcome>();
        @AuraEnabled public List<LinkDeleteOutcome> deletedLinks = new List<LinkDeleteOutcome>();
        
        @AuraEnabled public List<String> warnings = new List<String>();
        
        @AuraEnabled public Id duplicateDocId;
        @AuraEnabled public String duplicateDocTitle;
        
        @AuraEnabled public Id canonicalDocId;
        @AuraEnabled public String canonicalDocTitle;
        
        @AuraEnabled public Boolean wasSuccessful;   // overall success flag for UI
        @AuraEnabled public String successMessage;   // short boldable UI text
        
        @AuraEnabled public Boolean duplicateDocStillExists;

    }
    
    public class LinkInsertOutcome {
        @AuraEnabled public Id linkedEntityId;
        @AuraEnabled public String linkedEntityPrefix;
        @AuraEnabled public String shareType;
        @AuraEnabled public String visibility;
        
        @AuraEnabled public Id createdContentDocumentLinkId; // will exist even in rollback, but record won’t persist
        @AuraEnabled public Boolean success;
        @AuraEnabled public String error;
    }
    
    public class LinkDeleteOutcome {
        @AuraEnabled public Id contentDocumentLinkId;
        @AuraEnabled public Id linkedEntityId;
        @AuraEnabled public String linkedEntityPrefix;
        
        @AuraEnabled public Boolean success;
        @AuraEnabled public String error;
    }

    
    
    @AuraEnabled
    public static MergeExecutionResult executeMergeForOneDuplicate(
        Id productId,
        Id canonicalDocId,
        Id duplicateDocId,
        Boolean deleteDuplicateDoc,
        List<Map<String,Object>> insertLinks, // linkedEntityId/shareType/visibility
        List<Id> deleteLinkIds,
        Boolean rollbackOnly,
        Boolean strictAtomic // NEW: true=rollback on gate fail; false=commit successes and return results
    ) {
        MergeExecutionResult res = new MergeExecutionResult();
        res.rollbackMode = rollbackOnly;
        
        // Always take a savepoint so we can rollback either for dry-run or strict atomic failure
        Savepoint sp = Database.setSavepoint();
        
        // ----------------------------
        // Guard rails
        // ----------------------------
        try {
            requireContentDocumentPrefix(canonicalDocId);
        } catch (AuraHandledException e) {
            throw new AuraHandledException('canonicalDocId must be a ContentDocument (069...).');
        }
        
        try {
            requireContentDocumentPrefix(duplicateDocId);
        } catch (AuraHandledException e) {
            throw new AuraHandledException('duplicateDocId must be a ContentDocument (069...).');
        }
        
        res.duplicateDocId = duplicateDocId;
        res.canonicalDocId = canonicalDocId;
        
        // SECURITY: duplicate doc must be linked to the selected product
        Integer dupLinkedToProduct = [
            SELECT COUNT()
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :productId
            AND ContentDocumentId = :duplicateDocId
        ];
        if (dupLinkedToProduct == 0) {
            throw new AuraHandledException(
                'SECURITY BLOCK: duplicateDocId is not linked to the selected product.'
            );
        }
        
        // SECURITY: never allow canonical to be treated as the duplicate
        if (duplicateDocId == canonicalDocId) {
            throw new AuraHandledException(
                'SECURITY BLOCK: duplicateDocId cannot equal canonicalDocId.'
            );
        }


        
        // Best-effort titles (query once; safe even if doc gets deleted later)
        Map<Id, String> titleByDoc = new Map<Id, String>();
        for (ContentVersion cv : [
            SELECT ContentDocumentId, Title
            FROM ContentVersion
            WHERE IsLatest = true
            AND ContentDocumentId IN :new Set<Id>{ duplicateDocId, canonicalDocId }
        ]) {
            titleByDoc.put(cv.ContentDocumentId, cv.Title);
        }
        res.duplicateDocTitle = titleByDoc.get(duplicateDocId);
        res.canonicalDocTitle = titleByDoc.get(canonicalDocId);
        
        if (res.warnings == null) res.warnings = new List<String>();
        if (res.insertedLinks == null) res.insertedLinks = new List<LinkInsertOutcome>();
        if (res.deletedLinks == null) res.deletedLinks = new List<LinkDeleteOutcome>();
        
        // ----------------------------
        // Load requested CDLs for delete
        // ----------------------------
        Map<Id, ContentDocumentLink> cdlById = new Map<Id, ContentDocumentLink>();
        if (deleteLinkIds != null && !deleteLinkIds.isEmpty()) {
            for (ContentDocumentLink cdl : [
                SELECT Id, LinkedEntityId, ContentDocumentId, ShareType, Visibility
                FROM ContentDocumentLink
                WHERE Id IN :deleteLinkIds
            ]) {
                cdlById.put(cdl.Id, cdl);
            }
        }
        
        // Validate delete IDs
        for (Id requestedId : (deleteLinkIds == null ? new List<Id>() : deleteLinkIds)) {
            try {
                requireContentDocumentLinkPrefix(requestedId);
            } catch (AuraHandledException e) {
                throw new AuraHandledException('Refusing to delete non-ContentDocumentLink id: ' + requestedId);
            }
            
            if (!cdlById.containsKey(requestedId)) {
                res.warnings.add('Requested delete CDL not found: ' + requestedId);
            }
        }
        
        // ----------------------------
        // INSERTS (create CDLs on canonical)
        // ----------------------------
        List<ContentDocumentLink> toInsert = new List<ContentDocumentLink>();
        
        if (insertLinks != null) {
            for (Map<String,Object> row : insertLinks) {
                Id linkedEntityId = (Id)row.get('linkedEntityId');
                String shareType = (String)row.get('shareType');
                String visibility = (String)row.get('visibility');
                
                LinkInsertOutcome out = new LinkInsertOutcome();
                out.linkedEntityId = linkedEntityId;
                out.linkedEntityPrefix = (linkedEntityId == null) ? null : String.valueOf(linkedEntityId).left(3);
                out.shareType = shareType;
                out.visibility = visibility;
                res.insertedLinks.add(out);
                
                if (linkedEntityId == null) {
                    out.success = false;
                    out.error = 'linkedEntityId is null';
                    continue;
                }
                
                toInsert.add(new ContentDocumentLink(
                    ContentDocumentId = canonicalDocId,
                    LinkedEntityId   = linkedEntityId,
                    ShareType        = shareType,
                    Visibility       = visibility
                ));
            }
        }
        
        res.insertedLinksAttempted = toInsert.size();
        res.insertedLinksSucceeded = 0;
        
        if (!toInsert.isEmpty()) {
            Database.SaveResult[] ins = Database.insert(toInsert, false);
            
            // Map results back onto outcomes that represent attempted inserts (skip the null-id ones)
            Integer outIdx = 0;
            for (Integer i = 0; i < toInsert.size(); i++) {
                while (outIdx < res.insertedLinks.size() && res.insertedLinks[outIdx].success != null) {
                    outIdx++;
                }
                if (outIdx >= res.insertedLinks.size()) break;
                
                Database.SaveResult sr = ins[i];
                LinkInsertOutcome out = res.insertedLinks[outIdx];
                
                if (sr.isSuccess()) {
                    out.success = true;
                    out.createdContentDocumentLinkId = sr.getId();
                    res.insertedLinksSucceeded++;
                } else {
                    out.success = false;
                    out.error = sr.getErrors()[0].getStatusCode() + ': ' + sr.getErrors()[0].getMessage();
                }
                outIdx++;
            }
        }
        
        // Build set of successful substitute entities (used to gate deletes-per-entity)
        Set<Id> successfulInsertedEntityIds = new Set<Id>();
        for (LinkInsertOutcome o : res.insertedLinks) {
            if (o != null && o.success == true && o.linkedEntityId != null) {
                successfulInsertedEntityIds.add(o.linkedEntityId);
            }
        }
        
        // Also key inserts by (entity|share|vis) so deletes can be gated at the same granularity as the merge plan
        Set<String> successfulInsertedKeys = new Set<String>();
        for (LinkInsertOutcome o : res.insertedLinks) {
            if (o != null && o.success == true && o.linkedEntityId != null) {
                successfulInsertedKeys.add(makeLinkKey(o.linkedEntityId, o.shareType, o.visibility));
            }
        }
        
        // If canonical is ALREADY linked to an entity with the same ShareType/Visibility,
        // we should allow deleting the duplicate link even when no insert is needed.
        Set<Id> deleteEntityIds = new Set<Id>();
        for (ContentDocumentLink c : cdlById.values()) {
            if (c != null && c.LinkedEntityId != null) {
                deleteEntityIds.add(c.LinkedEntityId);
            }
        }
        
        Set<String> canonicalExistingKeys = new Set<String>();
        if (!deleteEntityIds.isEmpty()) {
            for (ContentDocumentLink existing : [
                SELECT LinkedEntityId, ShareType, Visibility
                FROM ContentDocumentLink
                WHERE ContentDocumentId = :canonicalDocId
                AND LinkedEntityId IN :deleteEntityIds
            ]) {
                canonicalExistingKeys.add(makeLinkKey(existing.LinkedEntityId, existing.ShareType, existing.Visibility));
            }
        }
        
        // ----------------------------
        // DELETES (only delete if a successful substitute insert exists for same entity)
        // ----------------------------
        List<ContentDocumentLink> toDelete = new List<ContentDocumentLink>();
        
        if (deleteLinkIds != null) {
            for (Id cdlId : deleteLinkIds) {
                if (!cdlById.containsKey(cdlId)) continue;
                
                ContentDocumentLink cdl = cdlById.get(cdlId);
                
                // Only delete links on the duplicate document
                if (cdl.ContentDocumentId != duplicateDocId) {
                    res.warnings.add('Skipping delete CDL not on duplicate doc: ' + cdlId);
                    continue;
                }
                
                LinkDeleteOutcome out = new LinkDeleteOutcome();
                out.contentDocumentLinkId = cdl.Id;
                out.linkedEntityId = cdl.LinkedEntityId;
                out.linkedEntityPrefix = (cdl.LinkedEntityId == null) ? null : String.valueOf(cdl.LinkedEntityId).left(3);
                res.deletedLinks.add(out);
                
                // PROTECT: User file shares (LinkedEntityId prefix 005) are not deletable here.
                // They often throw FIELD_INTEGRITY_EXCEPTION on delete.
                if (cdl.LinkedEntityId != null && String.valueOf(cdl.LinkedEntityId).startsWith('005')) {
                    out.success = false;
                    out.error = 'Blocked: User-linked ContentDocumentLink (005...) cannot be deleted by this tool.';
                    continue;
                }
                
                // Require substitute insert success for same entity
                String delKey = makeLinkKey(cdl.LinkedEntityId, cdl.ShareType, cdl.Visibility);
                
                // Allow delete if either:
                //  (A) we successfully inserted the canonical link for this exact key in THIS run, OR
                //  (B) the canonical link for this exact key already exists (no insert needed)
                Boolean okToDelete =
                    (cdl.LinkedEntityId != null) &&
                    (successfulInsertedKeys.contains(delKey) || canonicalExistingKeys.contains(delKey));
                
                if (!okToDelete) {
                    out.success = false;
                    out.error = 'Blocked: No substitute canonical link for this entity/share/visibility (neither inserted now nor already present).';
                    continue;
                }
                
                toDelete.add(new ContentDocumentLink(Id = cdl.Id));
            }
        }
        
        res.deletedLinksAttempted = toDelete.size();
        res.deletedLinksSucceeded = 0;
        
        if (!toDelete.isEmpty()) {
            Database.DeleteResult[] del = Database.delete(toDelete, false);
            Integer outRow = 0;
            
            // deletedLinks includes blocked rows too; only advance to rows that were actually attempted
            for (Integer i = 0; i < del.size(); i++) {
                // find next outcome row that represents an attempted delete
                while (outRow < res.deletedLinks.size() && res.deletedLinks[outRow].success != null) {
                    outRow++;
                }
                if (outRow >= res.deletedLinks.size()) break;
                
                Database.DeleteResult dr = del[i];
                LinkDeleteOutcome out = res.deletedLinks[outRow];
                
                if (dr.isSuccess()) {
                    out.success = true;
                    res.deletedLinksSucceeded++;
                } else {
                    out.success = false;
                    out.error = dr.getErrors()[0].getStatusCode() + ': ' + dr.getErrors()[0].getMessage();
                }
                outRow++;
            }
        }
        
        // ----------------------------
        // GATE
        // - If any inserts were requested, all attempted inserts must succeed.
        // - If any deletes were requested (i.e., we attempted deletes), all attempted deletes must succeed.
        //   (Blocked deletes do not count as "attempted" here; they already carry success=false with reason.)
        // ----------------------------
        Integer insAttempted = (res.insertedLinksAttempted == null) ? 0 : res.insertedLinksAttempted;
        Integer insSucceeded = (res.insertedLinksSucceeded == null) ? 0 : res.insertedLinksSucceeded;
        Integer delAttempted = (res.deletedLinksAttempted == null) ? 0 : res.deletedLinksAttempted;
        Integer delSucceeded = (res.deletedLinksSucceeded == null) ? 0 : res.deletedLinksSucceeded;
        
        Boolean insertsAllOk = (insAttempted == 0) || (insSucceeded == insAttempted);
        Boolean deletesAllOk = (delAttempted == 0) || (delSucceeded == delAttempted);
        
        if (!insertsAllOk || !deletesAllOk) {
            // Build short reasons
            List<String> reasons = new List<String>();
            if (!insertsAllOk) {
                reasons.add('Insert links failed (' + insSucceeded + '/' + insAttempted + ' succeeded).');
                Integer added = 0;
                for (LinkInsertOutcome o : res.insertedLinks) {
                    if (o != null && o.success == false && String.isNotBlank(o.error)) {
                        reasons.add('Insert error: ' + o.error);
                        if (++added >= 3) break;
                    }
                }
            }
            if (!deletesAllOk) {
                reasons.add('Delete links failed (' + delSucceeded + '/' + delAttempted + ' succeeded).');
                Integer added = 0;
                for (LinkDeleteOutcome o : res.deletedLinks) {
                    if (o != null && o.success == false && String.isNotBlank(o.error)) {
                        reasons.add('Delete error: ' + o.error);
                        if (++added >= 3) break;
                    }
                }
            }
            
            String msg = 'Merge gate failed — not all marked operations succeeded. ' + String.join(reasons, ' ');
            
            if (rollbackOnly || (strictAtomic == true)) {
                Database.rollback(sp);
                res.rolledBack = true;
                throw new AuraHandledException(msg);
            } else {
                // Commit successes: do NOT rollback, just return results with a warning message
                res.rolledBack = false;
                res.warnings.add(msg);
            }
        }
        
        // ----------------------------
        // Delete duplicate ContentDocument (optional) — only do this if:
        // - caller asked for it
        // - AND gate passed in strict modes
        // - AND in non-strict mode, only if inserts/deletes were clean (avoid deleting the doc on partial)
        // ----------------------------
        res.deletedDocuments = 0;
        res.deletedDuplicateDoc = false;
        
        Boolean safeToDeleteDoc =
            (deleteDuplicateDoc == true) &&
            insertsAllOk &&
            deletesAllOk;
        
        if (safeToDeleteDoc) {
            delete new ContentDocument(Id = duplicateDocId);
            res.deletedDocuments = 1;
            res.deletedDuplicateDoc = true;
        } else if (deleteDuplicateDoc == true && !(insertsAllOk && deletesAllOk)) {
            res.warnings.add('Duplicate ContentDocument was NOT deleted because merge gate did not fully pass.');
        }
        
        res.duplicateDocStillExists = [
            SELECT COUNT() FROM ContentDocument WHERE Id = :duplicateDocId
        ] > 0;
        
        // Success = no rollback and no gate failure in strict mode
        Boolean committed = (rollbackOnly != true) && (res.rolledBack != true);
        
        // You can decide your definition; this one means: gate passed and (if requested) doc delete happened or was not requested
        Boolean gatePassed = insertsAllOk && deletesAllOk;
        Boolean docOk = (deleteDuplicateDoc != true) || (res.deletedDuplicateDoc == true);
        
        res.wasSuccessful = committed && gatePassed && docOk;
        res.successMessage =
            res.wasSuccessful
            ? 'SUCCESS — changes committed.'
            : 'NOT SUCCESSFUL — review warnings/log.';
        
        // ----------------------------
        // Dry run rollback
        // ----------------------------
        if (rollbackOnly) {
            Database.rollback(sp);
            res.rolledBack = true;
        } else if (res.rolledBack == null) {
            res.rolledBack = false;
        }
        
        return res;
    }


   
    
    private static void requireContentDocumentPrefix(Id idVal) {
        if (idVal == null) {
            throw new AuraHandledException('Null Id passed to delete.');
        }
        
        String s = String.valueOf(idVal);
        
        if (!s.startsWith('069')) {
            throw new AuraHandledException(
                'SECURITY BLOCK: Attempt to delete non-ContentDocument Id: ' + s
            );
        }
    }
    
    private static void requireContentDocumentLinkPrefix(Id idVal) {
        if (idVal == null) {
            throw new AuraHandledException('Null Id passed to delete.');
        }
        
        String s = String.valueOf(idVal);
        
        if (!s.startsWith('06A')) {
            throw new AuraHandledException(
                'SECURITY BLOCK: Attempt to delete non-ContentDocumentLink Id: ' + s
            );
        }
    }
    
	// This is a great place to say, this is what I saved at 2026-01-23 at 1:15am - it appears to be 1770 lines long, but hey! who knows?
    
}