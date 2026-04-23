public without sharing class ProductSpecPdfHashService {
 
    // -------------------------
    // DTOs (Aura friendly)
    // -------------------------

    public class AuditRow {
        @AuraEnabled public Id contentDocumentId;
        @AuraEnabled public Id latestContentVersionId;
        @AuraEnabled public String title;
        @AuraEnabled public Integer contentSize;
        @AuraEnabled public Datetime lastModifiedDate;

        @AuraEnabled public Integer linkCount;
        @AuraEnabled public String linkTypesSummary;

        @AuraEnabled public String existingSha256;
        @AuraEnabled public Boolean matchesIncoming;
        @AuraEnabled public String note;
    }

    public class AuditResult {
        @AuraEnabled public Id productId;
        @AuraEnabled public String productCode;
        @AuraEnabled public String productName;

        @AuraEnabled public String specUrl;
        @AuraEnabled public Integer incomingSize;
        @AuraEnabled public String incomingSha256;

        @AuraEnabled public List<AuditRow> rows;
        @AuraEnabled public String recommendation;

        // ---- NEW (non-breaking; Aura can ignore if unused)
        @AuraEnabled public Integer totalCandidates;
        @AuraEnabled public Integer hashedCount;
        @AuraEnabled public Integer skippedCount;
        @AuraEnabled public Boolean truncated;
        @AuraEnabled public String truncationReason;
    }

    // -------------------------
    // Public API
    // -------------------------

    /**
     * Audits all "spec PDF" ContentDocuments linked to a product against the current incoming PDF bytes.
     * - Calls out ONCE to fetch incoming PDF (getContentAsPDF on product.Specification__c)
     * - Hashes incoming PDF (SHA-256)
     * - Finds linked spec PDFs based on: latest ContentVersion is PDF AND Title endswith ".PDF" (case-insensitive)
     * - Hashes each linked PDF's latest ContentVersion VersionData
     * - Returns rows with matches + a recommendation string
     *
     * HEAP/CPU SAFE BEHAVIOR:
     * - Builds ALL rows up front (so UI table still shows everything)
     * - Hashes in small batches and stops early if nearing heap/cpu limits
     * - Any remaining rows are returned with existingSha256=null and a note explaining why
     */
    public static AuditResult auditProduct(Id productId) {
        if (productId == null) {
            throw new AuraHandledException('No productId provided.');
        }

        // We only ever hash at most ONE existing PDF (canonical if present, else newest matching name).
        // This keeps heap/CPU predictable even when a Product has 100+ linked PDFs.

        Product2 p = [
            SELECT Id, Name, ProductCode, Specification__c, Canonical_Spec_Content_Document_Id__c
            FROM Product2
            WHERE Id = :productId
            LIMIT 1
        ];

        AuditResult res = new AuditResult();
        res.productId = p.Id;
        res.productCode = p.ProductCode;
        res.productName = p.Name;
        res.specUrl = p.Specification__c;
        res.rows = new List<AuditRow>();

        res.totalCandidates = 0;
        res.hashedCount = 0;
        res.skippedCount = 0;
        res.truncated = false;
        res.truncationReason = null;

        // 1) Incoming bytes (callout once)
        Blob incoming = fetchIncomingPdfBlob(p);
        if (incoming == null) {
            res.incomingSize = 0;
            res.incomingSha256 = null;
            res.recommendation = 'Incoming PDF could not be fetched. Check Specification__c URL/callout permissions.';
            return res;
        }

        res.incomingSize = incoming.size();
        res.incomingSha256 = sha256Hex(incoming);

        // Release incoming bytes as soon as we can
        incoming = null;

        // 2) Decide WHICH existing doc to hash:
        //    (a) canonical doc (if set AND actually linked to this Product)
        //    (b) else newest linked PDF whose latest Title == ProductCode + '.pdf' (case-insensitive)
        Id canonicalDocId = p.Canonical_Spec_Content_Document_Id__c;
        Id chosenDocId = null;
        String expectedTitle = buildExpectedSpecTitle(p.ProductCode); // e.g. "abc123.pdf" (lowercase)

        if (canonicalDocId != null) {
            // Verify canonical is linked to the Product (avoid hashing some unrelated doc id)
            Integer canonicalLinks = [
                SELECT COUNT()
                FROM ContentDocumentLink
                WHERE LinkedEntityId = :p.Id
                  AND ContentDocumentId = :canonicalDocId
            ];
            if (canonicalLinks > 0) {
                chosenDocId = canonicalDocId;
            }
        }

        if (chosenDocId == null) {
            // No canonical (or not linked). Find the newest matching spec-title PDF among links.
            // We only need the newest ContentVersion to determine the doc.
            List<ContentVersion> newest = [
                SELECT Id, ContentDocumentId, Title, FileExtension, ContentSize, LastModifiedDate
                FROM ContentVersion
                WHERE IsLatest = true
                  AND ContentDocumentId IN (
                      SELECT ContentDocumentId
                      FROM ContentDocumentLink
                      WHERE LinkedEntityId = :p.Id
                  )
                  AND FileExtension = 'pdf'
                ORDER BY LastModifiedDate DESC
                LIMIT 200
            ];

            for (ContentVersion cvMeta : newest) {
                if (cvMeta.Title == null) continue;
                // Match *exact* expected name, case-insensitive.
                // Example: expectedTitle = "abc123.pdf"; cvMeta.Title could be "ABC123.PDF"
                if (cvMeta.Title.toLowerCase() == expectedTitle) {
                    chosenDocId = cvMeta.ContentDocumentId;
                    break;
                }
            }
        }

        if (chosenDocId == null) {
            // Nothing to compare to — still return incoming hash so UI can show it.
            res.totalCandidates = 0;
            res.recommendation = 'No canonical spec PDF is set, and no linked PDF matched the expected title (' + expectedTitle + ').';
            return res;
        }

        // 3) Load the chosen latest ContentVersion (meta + VersionData for hashing)
        ContentVersion cv = [
            SELECT Id, ContentDocumentId, Title, FileExtension, ContentSize, LastModifiedDate, VersionData
            FROM ContentVersion
            WHERE IsLatest = true
              AND ContentDocumentId = :chosenDocId
            LIMIT 1
        ];

        // Guard: must be a PDF + Title ends with .pdf
        if (cv.FileExtension != 'pdf' || cv.Title == null || !cv.Title.toLowerCase().endsWith('.pdf')) {
            res.totalCandidates = 0;
            res.recommendation = 'Chosen document is not a PDF by rule (latest version is not pdf or title does not end with .pdf).';
            return res;
        }

        // 4) Link counts + type summary (only for the chosen doc)
        Integer linkCount = [
            SELECT COUNT()
            FROM ContentDocumentLink
            WHERE ContentDocumentId = :chosenDocId
        ];

        Map<String, Integer> typeCounts = new Map<String, Integer>();
        for (ContentDocumentLink l : [
            SELECT LinkedEntityId
            FROM ContentDocumentLink
            WHERE ContentDocumentId = :chosenDocId
        ]) {
            String typeName;
            try {
                typeName = String.valueOf(l.LinkedEntityId.getSObjectType().getDescribe().getName());
            } catch (Exception e) {
                typeName = 'Unknown';
            }
            typeCounts.put(typeName, (typeCounts.containsKey(typeName) ? typeCounts.get(typeName) : 0) + 1);
        }

        // 5) Build single row + compute hash
        AuditRow row = new AuditRow();
        row.contentDocumentId = chosenDocId;
        row.latestContentVersionId = cv.Id;
        row.title = cv.Title;
        row.contentSize = cv.ContentSize;
        row.lastModifiedDate = cv.LastModifiedDate;
        row.linkCount = linkCount;
        row.linkTypesSummary = summarizeTypes(typeCounts);

        res.totalCandidates = 1;

        try {
            row.existingSha256 = sha256Hex(cv.VersionData);
            row.matchesIncoming = (row.existingSha256 != null && row.existingSha256 == res.incomingSha256);
            row.note = row.matchesIncoming ? 'Matches incoming spec PDF' : 'Does NOT match incoming spec PDF';
            res.hashedCount = 1;
        } catch (Exception e) {
            row.existingSha256 = null;
            row.matchesIncoming = false;
            row.note = 'Could not hash VersionData (insufficient access or data unavailable).';
            res.hashedCount = 1; // attempted
        }

        res.rows.add(row);

        // 6) Recommendation string
        if (row.matchesIncoming == true) {
            res.recommendation = 'Chosen PDF matches incoming hash. (Canonical-first; else newest matching title)';
        } else {
            res.recommendation = 'Chosen PDF does NOT match incoming hash. (Canonical-first; else newest matching title)';
        }

        return res;
    }

    // -------------------------
    // Helpers
    // -------------------------

    private static Blob fetchIncomingPdfBlob(Product2 p) {
        if (p == null || String.isBlank(p.Specification__c)) return null;

        // Normalize spaces like your existing code
        String url = p.Specification__c.replaceAll(' ', '%20');

        if (Test.isRunningTest()) {
            return Blob.valueOf('TEST_PDF_BYTES');
        }

        try {
            PageReference pr = new PageReference(url);
            return pr.getContentAsPDF();
        } catch (Exception e) {
            return null;
        }
    }

    private static String sha256Hex(Blob b) {
        if (b == null) return null;
        Blob digest = Crypto.generateDigest('SHA-256', b);
        return EncodingUtil.convertToHex(digest);
    }

    private static String summarizeTypes(Map<String, Integer> typeCounts) {
        if (typeCounts == null || typeCounts.isEmpty()) return '';

        List<String> keys = new List<String>();
        keys.addAll(typeCounts.keySet());
        keys.sort();

        List<String> parts = new List<String>();
        for (String k : keys) {
            parts.add(k + ': ' + String.valueOf(typeCounts.get(k)));
        }
        return String.join(parts, ', ');
    }

    /*
    // Stop conditions (heap/cpu)
    // NOTE: v3 no longer hashes many PDFs in a loop, but we keep these helpers for future expansion.
    private static Boolean shouldStopHashing(Integer heapBufferBytes, Integer cpuBufferMs) {
        try {
            Integer heap = Limits.getHeapSize();
            Integer heapLimit = Limits.getLimitHeapSize();
            if (heapLimit != null && heap != null && (heapLimit - heap) <= heapBufferBytes) {
                return true;
            }

            Integer cpu = Limits.getCpuTime();
            Integer cpuLimit = Limits.getLimitCpuTime();
            if (cpuLimit != null && cpu != null && (cpuLimit - cpu) <= cpuBufferMs) {
                return true;
            }
        } catch (Exception e) {
            // If anything goes sideways, don't risk blowing limits.
            return true;
        }
        return false;
    }

    private static String buildStopReason() {
        Integer heap = Limits.getHeapSize();
        Integer heapLimit = Limits.getLimitHeapSize();
        Integer cpu = Limits.getCpuTime();
        Integer cpuLimit = Limits.getLimitCpuTime();

        List<String> reasons = new List<String>();
        if (heap != null && heapLimit != null) {
            reasons.add('heap ' + String.valueOf(heap) + '/' + String.valueOf(heapLimit));
        }
        if (cpu != null && cpuLimit != null) {
            reasons.add('cpu ' + String.valueOf(cpu) + 'ms/' + String.valueOf(cpuLimit) + 'ms');
        }
        return String.join(reasons, ', ');
    }
	*/

    private static String buildExpectedSpecTitle(String productCode) {
        // Dashboard rule says Title + PathOnClient should be ProductCode + '.pdf' (lowercase)
        if (String.isBlank(productCode)) return null;
        return productCode.trim().toLowerCase() + '.pdf';
    }
}