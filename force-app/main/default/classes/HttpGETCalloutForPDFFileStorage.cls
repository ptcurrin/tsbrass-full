public virtual without sharing class HttpGETCalloutForPDFFileStorage {
 
    final private Product2 product { get; set; }
    
    private Id resolvedDocId;
    private Integer pdfCountByType;
    private Boolean isRogue;

    private String outcomeStatus;
    private String outcomeMessage;

    // Deferred writes (reset every run)
    private Boolean needsProductWrite = false;
    private Blob pendingPdf;
    private Id pendingDocId;
    private Boolean createNewDoc = false;
    private Boolean addNewVersion = false;

    // ================= CONSTRUCTOR =================

    public HttpGETCalloutForPDFFileStorage(String product2Id) {
        this.product = [
            SELECT Id,
                   ProductCode,
                   Specification__c,
                   Canonical_Spec_Content_Document_Id__c,
                   Canonical_Spec_Set_At__c,
                   Spec_Last_Checked_At__c,
                   Spec_Last_Check_Status__c,
                   Spec_Last_Check_Message__c,
                   Spec_Last_Stored_Sha256__c
            FROM Product2
            WHERE Id = :product2Id
            LIMIT 1
        ];
    }

    // ================= MAIN =================

    public Boolean addFileToProduct() {

        try {
            // ---- RESET ALL PER-RUN STATE (prevents state leakage) ----
            outcomeStatus = null;
            outcomeMessage = null;

            needsProductWrite = false;
            pendingPdf = null;
            pendingDocId = null;
            createNewDoc = false;
            addNewVersion = false;
            // ---------------------------------------------------------

            resolveStateAndMaybeBootstrapCanonical();

            /* =================================================
               ROGUE (NO CALLOUT REQUIRED)
            ================================================= */

            if (isRogue) {

                if (!String.isBlank(product.Canonical_Spec_Content_Document_Id__c)) {

                    List<ContentVersion> canon = [
                        SELECT VersionData
                        FROM ContentVersion
                        WHERE IsLatest = true
                        AND ContentDocumentId = :product.Canonical_Spec_Content_Document_Id__c
                        LIMIT 1
                    ];

                    if (canon.isEmpty()) {
                        outcomeStatus = 'CanonicalMissing';
                        outcomeMessage =
                            'Canonical has no latest version. CanonDocId=' +
                            product.Canonical_Spec_Content_Document_Id__c;
                        needsProductWrite = true;
                        return finalize(false);
                    }

                    product.Spec_Last_Stored_Sha256__c =
                        sha256Hex(canon[0].VersionData);

                    needsProductWrite = true;

                    outcomeStatus = 'Rogue';
                    outcomeMessage =
                        'ROGUE: Canonical hashed only. CanonDocId=' +
                        product.Canonical_Spec_Content_Document_Id__c;

                    return finalize(true);
                }

                outcomeStatus = 'Rogue';
                outcomeMessage = 'ROGUE: Multiple PDFs, no canonical';
                needsProductWrite = true;
                return finalize(true);
            }

            /* =================================================
               CALLOUT (ALWAYS FIRST)
            ================================================= */

            pendingPdf = getPostCalloutResponseContents();

            // ✅ CRITICAL: do NOT overwrite CalloutError / NoSpecUrl here
            if (pendingPdf == null || pendingPdf.size() == 0) {

                if (String.isBlank(outcomeStatus)) {
                    outcomeStatus = 'EmptyPdf';
                    outcomeMessage = 'Callout returned empty PDF (null/0 bytes).';
                } else {
                    outcomeMessage = (outcomeMessage == null ? '' : outcomeMessage) +
                        ' (Callout phase returned null/0 bytes.)';
                }

                needsProductWrite = true;
                return finalize(false);
            }

            String incomingSha = sha256Hex(pendingPdf);

            /* =================================================
               NO EXISTING PDF
            ================================================= */

            if (resolvedDocId == null) {

                if (pdfCountByType == 1) {
                    outcomeStatus = 'WrongName';
                    outcomeMessage =
                        'PDF exists but wrong name; refusing to touch it. Expected="' +
                        expectedPdfName() + '".';
                    needsProductWrite = true;
                    return finalize(true);
                }

                // CREATE
                createNewDoc = true;
                product.Spec_Last_Stored_Sha256__c = incomingSha;
                needsProductWrite = true;

                outcomeStatus = 'Created';
                outcomeMessage = 'First PDF created (post-callout).';
                return finalize(true);
            }

            /* =================================================
               EXISTING PDF
            ================================================= */

            ContentVersion latest = [
                SELECT VersionData
                FROM ContentVersion
                WHERE IsLatest = true
                AND ContentDocumentId = :resolvedDocId
                LIMIT 1
            ];

            String existingSha = sha256Hex(latest.VersionData);

            // We learned the current stored hash even if no change.
            product.Spec_Last_Stored_Sha256__c = existingSha;
            needsProductWrite = true;

            if (incomingSha == existingSha) {
                outcomeStatus = 'NoChange';
                outcomeMessage = 'No change detected. DocId=' + resolvedDocId;
                return finalize(true);
            }

            // UPDATE
            addNewVersion = true;
            product.Spec_Last_Stored_Sha256__c = incomingSha;

            outcomeStatus = 'Updated';
            outcomeMessage = 'New version created (post-callout). DocId=' + resolvedDocId;
            return finalize(true);

        } catch (Exception ex) {

            outcomeStatus = 'Exception';
            outcomeMessage = ex.getTypeName() + ': ' + ex.getMessage();
            needsProductWrite = true;
            return finalize(false);
        }
    }

    // ================= STATE =================

    private void resolveStateAndMaybeBootstrapCanonical() {

        resolvedDocId = null;
        pdfCountByType = 0;
        isRogue = false;

        Set<Id> docIds = new Set<Id>();

        for (ContentDocumentLink l : [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :product.Id
        ]) {
            docIds.add(l.ContentDocumentId);
        }

        if (docIds.isEmpty()) return;

        List<ContentVersion> latest = [
            SELECT ContentDocumentId,
                   FileExtension,
                   FileType,
                   Title,
                   PathOnClient
            FROM ContentVersion
            WHERE IsLatest = true
            AND ContentDocumentId IN :docIds
        ];

        String expected = expectedPdfName();

        Set<Id> pdfDocs = new Set<Id>();
        Set<Id> specDocs = new Set<Id>();

        for (ContentVersion cv : latest) {

            Boolean isPdf =
                (cv.FileExtension != null &&
                 cv.FileExtension.toUpperCase() == 'PDF')
                ||
                (cv.FileType != null &&
                 cv.FileType == 'PDF');

            if (!isPdf) continue;

            pdfDocs.add(cv.ContentDocumentId);

            String t = cv.Title == null ? '' : cv.Title.trim().toUpperCase();
            String p = cv.PathOnClient == null ? '' : cv.PathOnClient.trim().toUpperCase();

            if (p.contains('/')) p = p.substring(p.lastIndexOf('/') + 1);

            if (t == expected || p == expected) {
                specDocs.add(cv.ContentDocumentId);
            }
        }

        pdfCountByType = pdfDocs.size();
        isRogue = (pdfCountByType >= 2);

        if (!isRogue && specDocs.size() == 1) {
            resolvedDocId = new List<Id>(specDocs)[0];

            // ✅ FIX: bootstrap canonical for clean, unambiguous products
            if (String.isBlank(product.Canonical_Spec_Content_Document_Id__c)) {
                setCanonicalIfBlank(resolvedDocId);
                needsProductWrite = true; // ensure Product2 update happens in finalize()
            }
        }
    }

    // ================= FINALIZE =================

    private Boolean finalize(Boolean ok) {

        /* -------- FILE WRITES (AFTER CALLOUT) -------- */

        if (createNewDoc) {
            pendingDocId = createNewSpecDocumentAndLink(pendingPdf);
            setCanonicalIfBlank(pendingDocId);
        }

        if (addNewVersion) {
            addNewVersionToExistingDocument(resolvedDocId, pendingPdf);
            setCanonicalIfBlank(resolvedDocId);
        }

        /* -------- PRODUCT WRITE (ONCE) -------- */

        product.Spec_Last_Checked_At__c = Datetime.now();
        product.Spec_Last_Check_Status__c =
            outcomeStatus == null ? 'NoChange' : outcomeStatus;
        product.Spec_Last_Check_Message__c = outcomeMessage;

        if (needsProductWrite) {
            update product;
        }

        return ok;
    }

    // ================= FILE OPS =================

    private Id createNewSpecDocumentAndLink(Blob body) {

        String name = expectedPdfName();

        ContentVersion cv = new ContentVersion();
        cv.ContentLocation = 'S';
        cv.PathOnClient = name;
        cv.Title = name;
        cv.VersionData = body;
        insert cv;

        Id docId = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cv.Id
        ].ContentDocumentId;

        insert new ContentDocumentLink(
            ContentDocumentId = docId,
            LinkedEntityId = product.Id,
            ShareType = 'I',
            Visibility = 'AllUsers'
        );

        return docId;
    }

    private void addNewVersionToExistingDocument(Id docId, Blob body) {

        ContentVersion cv = new ContentVersion();
        cv.ContentDocumentId = docId;
        cv.PathOnClient = expectedPdfName();
        cv.Title = expectedPdfName();
        cv.VersionData = body;
        insert cv;
    }

    // ================= HELPERS =================

    private void setCanonicalIfBlank(Id docId) {

        if (String.isBlank(product.Canonical_Spec_Content_Document_Id__c)) {

            product.Canonical_Spec_Content_Document_Id__c = (String)docId;

            if (product.Canonical_Spec_Set_At__c == null) {
                product.Canonical_Spec_Set_At__c = Datetime.now();
            }
        }
    }

    private String expectedPdfName() {
        String pc = product.ProductCode == null ? '' : product.ProductCode.trim();
        return (pc + '.PDF').toUpperCase();
    }

    private static String sha256Hex(Blob b) {
        return EncodingUtil.convertToHex(
            Crypto.generateDigest('SHA-256', b)
        );
    }

    // ================= CALLOUT =================

    public virtual Blob getPostCalloutResponseContents() {

        if (String.isBlank(product.Specification__c)) {
            outcomeStatus = 'NoSpecUrl';
            outcomeMessage = 'Specification__c blank';
            return null;
        }

        if (Test.isRunningTest()) {
            return Blob.valueOf('10101010');
        }

        try {
            PageReference page =
                new PageReference(product.Specification__c.replace(' ', '%20'));

            return page.getContentAsPDF();

        } catch (Exception ex) {
            outcomeStatus = 'CalloutError';
            outcomeMessage = ex.getTypeName() + ': ' + ex.getMessage();
            return null;
        }
    }
}