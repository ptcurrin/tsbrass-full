// Helper version: v4 (2026-01-23T03:41:25Z)
({

    _ts : function() {
        // Local time, 24h, with seconds (e.g. "15:04:09")
        try {
            return new Date().toLocaleTimeString([], { hour12: false, hour: '2-digit', minute: '2-digit', second: '2-digit' });
        } catch (e) {
            return new Date().toISOString();
        }
    },

    _setText : function(component, attrName, message) {
        component.set(attrName, "[" + this._ts() + "] " + message);
    },
    
    

    loadPage : function(component, resetSelection) {
        var helper = this;

        if (resetSelection) {
            component.set("v.selectedProductId", null);
            component.set("v.selectedProductLabel", null);
        }

        component.set("v.isLoading", true);
        helper._setText(component, "v.statusText", "Loading…");

        var action = component.get("c.getCompliancePage");
        action.setStorable({ refresh: true });
        action.setParams({
            searchTerm: component.get("v.searchTerm"),
            mode: component.get("v.mode"),
            pageNumber: component.get("v.pageNumber"),
            pageSize: component.get("v.pageSize")
        });

        action.setCallback(this, function(resp) {
            component.set("v.isLoading", false);

            if (resp.getState() !== "SUCCESS") {
                var errs = resp.getError();
                helper._setText(
                    component,
                    "v.statusText",
                    (errs && errs[0] && errs[0].message) ? errs[0].message : "Load failed."
                );
                return;
            }
            
            var page = resp.getReturnValue();
            
            component.set("v.totalFound", page.totalFound || 0);
            component.set("v.rangeLabel", page.rangeLabel || "0-0");
            
            component.set("v.rows", page.rows || []);
            component.set("v.hasMore", !!page.hasMore);
            
            var cols = component.get("v.columns");
            if (cols && cols.length > 0) {
                for (var i = 0; i < cols.length; i++) {
                    if (cols[i] && cols[i].type === 'action' && cols[i].typeAttributes) {
                        cols[i].typeAttributes.rowActions = helper.getRowActions.bind(helper, component);
                        break;
                    }
                }
            }
            component.set("v.columns", cols);

            helper._setText(
                component,
                "v.statusText",
                "Loaded " + (page.returnedCount || 0) + " row(s). Page " + page.pageNumber + "."
            );
        });

        $A.enqueueAction(action);
        
        var a = component.get("c.getComplianceStats");
        a.setCallback(this, function(r) {
            if (r.getState() === "SUCCESS") {
                component.set("v.globalStats", r.getReturnValue());
                // If you want timestamps, set statusText here using your _stamp helper
                // helper._setStatus(component, "Global stats loaded"); (whatever your helper method is)
            }
        });
        $A.enqueueAction(a);
        
    },

    getRowActions : function(component, row, doneCallback) {
        doneCallback([{ label: "Open Cleanup", name: "openCleanup" }]);
    },

    loadFilesTab : function(component) {
        var helper = this;

        if (component.get("v.auditIsRunning")) {
            console.log('[HashAudit] helper blocked: already running');
            return;
        }

        component.set("v.isLoading", true);
        helper._setText(component, "v.statusText", "Loading product files…");

        var action = component.get("c.getProductFileSummary");
        action.setParams({ productId: component.get("v.selectedProductId") });
        action.setCallback(this, function(resp) {
            component.set("v.isLoading", false);

            if (resp.getState() !== "SUCCESS") {
                var errs = resp.getError();
                helper._setText(
                    component,
                    "v.statusText",
                    (errs && errs[0] && errs[0].message) ? errs[0].message : "Load failed."
                );
                return;
            }

            var summary = resp.getReturnValue();
            component.set("v.fileSummary", summary);
            component.set("v.fileRows", (summary && summary.specPdfs) ? summary.specPdfs : []);

            helper._setText(
                component,
                "v.statusText",
                "Loaded " + ((summary && summary.specPdfs) ? summary.specPdfs.length : 0) + " spec PDF(s)."
            );
        });

        $A.enqueueAction(action);
    },

    loadDocLinks : function(component, contentDocumentId) {
        var helper = this;

        component.set("v.isLoading", true);
        helper._setText(component, "v.statusText", "Loading file links…");

        var action = component.get("c.getLinksForContentDocument");
        action.setParams({ contentDocumentId: contentDocumentId });
        action.setCallback(this, function(resp) {
            component.set("v.isLoading", false);

            if (resp.getState() !== "SUCCESS") {
                var errs = resp.getError();
                helper._setText(
                    component,
                    "v.statusText",
                    (errs && errs[0] && errs[0].message) ? errs[0].message : "Load links failed."
                );
                return;
            }

            var rows = resp.getReturnValue() || [];
            rows.forEach(function(r) {
                r.linkedEntityUrl = '/' + r.linkedEntityId;
                if (!r.linkedEntityLabel) {
                    r.linkedEntityLabel = r.linkedEntityId;
                }
                r.contentDocumentUrl = '/lightning/r/ContentDocument/' + r.contentDocumentId + '/view';
            });

            component.set("v.docLinkRows", rows);
            helper._setText(component, "v.statusText", "Loaded " + rows.length + " link(s)." );
        });

        $A.enqueueAction(action);
    },

    clearHashAuditUI : function(component) {
        component.set("v.auditResult", null);
        component.set("v.auditRows", []);
        this._setText(component, "v.statusText", "Hash audit ready…");
    },

    runHashAudit : function(component) {
        var helper = this;

        console.log('runHashAudit helper');
        try {
            var productId = component.get("v.selectedProductId");
            if (!productId) {
                helper._setText(component, "v.statusText", "Select a product first (from the dashboard).");
                return;
            }

            component.set("v.auditIsRunning", true);
            component.set("v.auditResult", null);
            component.set("v.auditRows", []);
            helper._setText(component, "v.statusText", "Running hash audit…");

            var action = component.get("c.runHashAuditCallApex");
            if (!action) {
                component.set("v.auditIsRunning", false);
                helper._setText(component, "v.statusText", "Apex action c.runHashAudit was not found. Check ProductFileComplianceController.");
                return;
            }

            console.log('productId: ' + productId);
            action.setParams({ productId: productId });

            action.setCallback(this, function(resp) {
                component.set("v.auditIsRunning", false);
                console.log('state: ' + resp.getState());

                if (resp.getState() !== "SUCCESS") {
                    var errs = resp.getError();
                    helper._setText(
                        component,
                        "v.statusText",
                        (errs && errs[0] && errs[0].message) ? errs[0].message : "Hash audit failed."
                    );
                    return;
                }

                var result = resp.getReturnValue();
                component.set("v.auditResult", result);
                component.set("v.auditRows", (result && result.rows) ? result.rows : []);
                helper._setText(component, "v.statusText", "Hash audit complete.");
            });

            $A.enqueueAction(action);

            window.setTimeout($A.getCallback(function() {
                if (component.get("v.auditIsRunning")) {
                    component.set("v.auditIsRunning", false);
                    helper._setText(component, "v.statusText", "Hash audit is taking too long (likely PDF fetch). Try again or inspect Specification__c URL.");
                }
            }), 45000);

        } catch (e) {
            component.set("v.auditIsRunning", false);
            helper._setText(component, "v.statusText", "Client error: " + (e && e.message ? e.message : e));
        }
    },

    loadMergeCandidates : function(component) {
        var helper = this;

        var productId = component.get("v.selectedProductId");
        if (!productId) {
            return;
        }

        component.set("v.mergeIsLoading", true);
        component.set("v.mergeSummary", null);
        component.set("v.mergeCandidates", []);
        helper._setText(component, "v.mergeStatusText", "Loading merge candidates…");

        var action = component.get("c.getMergeDiscovery");
        action.setParams({ productId: productId });
        action.setCallback(this, function(resp) {
            component.set("v.mergeIsLoading", false);

            if (resp.getState() !== "SUCCESS") {
                helper._setText(component, "v.mergeStatusText", "Load merge candidates failed: " + JSON.stringify(resp.getError()));
                return;
            }

            var result = resp.getReturnValue();
            component.set("v.mergeSummary", result);
            component.set("v.mergeCandidates", (result && result.candidates) ? result.candidates : []);

            var tmp = component.get("v.mergeCandidates") || [];
            component.set("v.mergeCandidates", tmp.map(function(r){ return Object.assign({}, r); }));

            var auditRows = component.get("v.auditRows") || [];
            if (auditRows.length) {
                var matchByDocId = {};
                auditRows.forEach(function(r){
                    if (r && r.contentDocumentId) {
                        matchByDocId[r.contentDocumentId] = r.matchesIncoming;
                    }
                });
                var cands = component.get("v.mergeCandidates") || [];
                cands.forEach(function(c){
                    if (c && c.contentDocumentId && matchByDocId.hasOwnProperty(c.contentDocumentId)) {
                        c.hashMatchesIncoming = matchByDocId[c.contentDocumentId];
                    }
                });
                component.set("v.mergeCandidates", cands);
            }

            if (result && result.canonicalDocId) {
                component.set("v.selectedCanonicalDocId", result.canonicalDocId);
            }

            var count = (result && result.candidates) ? result.candidates.length : 0;
            helper._setText(component, "v.mergeStatusText", "Loaded " + count + " candidate(s)." );
        });

        $A.enqueueAction(action);
    },

    refreshMergeHashes : function(component) {
        var helper = this;

        var productId = component.get("v.selectedProductId");
        if (!productId) {
            return;
        }

        component.set("v.auditIsRunning", true);
        helper._setText(component, "v.statusText", "Refreshing hash audit…");

        var action = component.get("c.runHashAuditCallApex");
        action.setParams({ productId: productId });
        action.setCallback(this, function(resp){
            component.set("v.auditIsRunning", false);

            if (resp.getState() !== "SUCCESS") {
                var errs = resp.getError();
                helper._setText(
                    component,
                    "v.statusText",
                    (errs && errs[0] && errs[0].message) ? errs[0].message : "Hash refresh failed."
                );
                return;
            }

            var result = resp.getReturnValue();
            component.set("v.auditResult", result);
            component.set("v.auditRows", (result && result.rows) ? result.rows : []);

            var matchByDocId = {};
            (result.rows || []).forEach(function(r){
                if (r && r.contentDocumentId) {
                    matchByDocId[r.contentDocumentId] = r.matchesIncoming;
                }
            });

            var cands = component.get("v.mergeCandidates") || [];
            cands.forEach(function(c){
                if (c && c.contentDocumentId && matchByDocId.hasOwnProperty(c.contentDocumentId)) {
                    c.hashMatchesIncoming = matchByDocId[c.contentDocumentId];
                }
            });
            component.set("v.mergeCandidates", cands);

            helper._setText(component, "v.statusText", "Hash refreshed and applied to merge candidates." );
        });

        $A.enqueueAction(action);
    },

    confirmAndSetCanonical : function(component, row) {
        var helper = this;

        var productId = component.get("v.selectedProductId");
        if (!productId) {
            helper._setText(component, "v.mergeStatusText", "Select a product first.");
            return;
        }

        var docId = row && row.contentDocumentId;
        if (!docId) {
            helper._setText(component, "v.mergeStatusText", "No ContentDocumentId found on this row.");
            return;
        }

        var title = row.title || "(no title)";
        var productLabel = component.get("v.selectedProductLabel") || productId;

        var msg =
            "Set this file as the canonical spec PDF?\n\n" +
            "Product: " + productLabel + "\n" +
            "File: " + title + "\n" +
            "ContentDocumentId: " + docId + "\n\n" +
            "This updates Product2.Canonical_Spec_Content_Document_Id__c " +
            "and sets Canonical_Spec_Set_At__c only if it is blank.";

        if (!window.confirm(msg)) {
            helper._setText(component, "v.mergeStatusText", "Cancelled. Canonical was not changed.");
            return;
        }

        component.set("v.isLoading", true);
        helper._setText(component, "v.mergeStatusText", "Saving canonical…");

        try {
            var t0 = $A.get("e.force:showToast");
            if (t0) {
                t0.setParams({ title: "Saving…", message: "Updating canonical for " + productLabel, type: "info", mode: "dismissible" });
                t0.fire();
            }
        } catch (e0) {}

        var action = component.get("c.setCanonicalSpecDoc");
        action.setParams({ productId: productId, contentDocumentId: docId });

        var helperRef = this;
        action.setCallback(this, function(resp) {
            component.set("v.isLoading", false);

            var state = resp.getState();
            if (state !== "SUCCESS") {
                var errs = resp.getError();
                var errMsg = (errs && errs[0] && errs[0].message) ? errs[0].message : ("Set canonical failed (" + state + ").");
                helperRef._setText(component, "v.mergeStatusText", errMsg);
                return;
            }

            var result = resp.getReturnValue();
            var savedDocId = (result && result.canonicalDocId) ? result.canonicalDocId : docId;
            component.set("v.selectedCanonicalDocId", savedDocId);

            var priorSummary = component.get("v.mergeSummary") || {};
            var summary = Object.assign({}, priorSummary);
            summary.canonicalDocId = savedDocId;
            summary.canonicalSetAt = (result && result.canonicalSetAt) ? result.canonicalSetAt : summary.canonicalSetAt;
            component.set("v.mergeSummary", summary);

            var current = component.get("v.mergeCandidates") || [];
            var updated = current.map(function(c) {
                var x = Object.assign({}, c);
                x.isCanonical = (x.contentDocumentId === savedDocId);
                return x;
            });

            component.set("v.mergeCandidates", []);
            component.set("v.mergeCandidates", updated);

            helperRef._setText(component, "v.mergeStatusText", "Canonical saved: " + savedDocId);

            helperRef.loadMergeCandidates(component);
            helperRef.loadFilesTab(component);
            helperRef.loadPage(component, false);
        });

        $A.enqueueAction(action);
    },

    buildMergePlan : function(component) {
        var helper = this;

        var productId = component.get("v.selectedProductId");
        var canonicalDocId = component.get("v.selectedCanonicalDocId");

        if (!productId) {
            helper._setText(component, "v.mergePlanStatusText", "Select a product first.");
            return;
        }
        if (!canonicalDocId) {
            helper._setText(component, "v.mergePlanStatusText", "Select a canonical doc first.");
            return;
        }

        component.set("v.mergePlanIsLoading", true);
        helper._setText(component, "v.mergePlanStatusText", "Building merge plan…");
        component.set("v.mergePlan", null);
        component.set("v.mergePlanRows", []);

        var action = component.get("c.getMergePlan");
        action.setParams({ productId: productId, canonicalDocId: canonicalDocId });
        action.setCallback(this, function(resp) {
            component.set("v.mergePlanIsLoading", false);

            if (resp.getState() !== "SUCCESS") {
                var errs = resp.getError();
                helper._setText(
                    component,
                    "v.mergePlanStatusText",
                    (errs && errs[0] && errs[0].message) ? errs[0].message : "Build merge plan failed."
                );
                return;
            }

            var plan = resp.getReturnValue();
            var rows = (plan && plan.rows) ? plan.rows : [];

            console.log('[MergePlan] first row =', (rows && rows.length) ? rows[0] : null);

            
            component.set("v.mergePlan", plan);
            component.set("v.mergePlanRows", rows);
            component.set("v.mergeDuplicateDocs", plan.duplicateDocs);

            var insertRows = [];
            var deleteRows = [];
            rows.forEach(function(r) {
                if (r.willInsert) {
                    var cloneI = Object.assign({}, r);
                    if (!cloneI.insertKey) {
                        cloneI.insertKey = (r.linkedEntityId || '') + '|' + (r.shareType || '') + '|' + (r.visibility || '');
                    }
                    insertRows.push(cloneI);
                }
                if (r.willDelete) {
                    deleteRows.push(Object.assign({}, r));
                }
            });
            
            console.log('[MergePlan] deleteRows sample =', deleteRows.slice(0, 3));


            component.set("v.mergeCurrentInsertRows", insertRows);
            component.set("v.mergeCurrentDeleteRows", deleteRows);
            component.set("v.selectedInsertKeys", insertRows.map(function(r){ return r.insertKey; }));
            component.set("v.selectedDeleteLinkIds", deleteRows.map(function(r){ return r.contentDocumentLinkIdToDelete; }));

            helper._setText(component, "v.mergePlanStatusText", "Plan loaded. Inserts: " + insertRows.length + " | Deletes: " + deleteRows.length);
        });

        $A.enqueueAction(action);
    },

    resetMergeState : function(component) {
        component.set("v.showMergeWizard", false);
        component.set("v.mergePlan", null);
        component.set("v.mergePlanRows", []);
        component.set("v.mergeDuplicateDocs", []);
        component.set("v.mergeStepIndex", 0);
        component.set("v.mergeStepDoc", null);
        component.set("v.mergeStepInsertRows", []);
        component.set("v.mergeStepDeleteRows", []);
        component.set("v.mergeStepSelectedInsertRows", []);
        component.set("v.mergeStepSelectedDeleteRows", []);
        component.set("v.mergeStepDeleteDocChecked", false);
        component.set("v.mergeExecLog", "");
        component.set("v.mergeExecStatusText", "");
        component.set("v.mergeExecIsRunning", false);
        console.log("[Merge] State reset");
    },

    loadCurrentStepPreview : function(component) {
        var helper = this;

        var idx = component.get("v.mergeRunIndex");
        var queue = component.get("v.mergeRunQueue") || [];
        var current = queue[idx];

        if (!current) {
            helper._setText(component, "v.mergeExecStatusText", "All done.");
            component.set("v.showMergeStepModal", false);
            return;
        }

        component.set("v.mergeCurrentDoc", current);

        var allPlanRows = component.get("v.mergePlanRows") || [];
        var filtered = allPlanRows.filter(function(r){
            return r && r.sourceDocId === current.sourceDocId;
        });

        var insertRows = filtered
            .filter(function(r){ return !!r.willInsert; })
            .map(function(r){
                var x = Object.assign({}, r);
                x.insertKey = (x.linkedEntityId || '') + '|' + (x.shareType || '') + '|' + (x.visibility || '');
                return x;
            });

        var deleteRows = filtered
            .filter(function(r){ return !!r.willDelete; })
            .map(function(r){ return Object.assign({}, r); });

        component.set("v.mergeCurrentInsertRows", insertRows);
        component.set("v.mergeCurrentDeleteRows", deleteRows);
        component.set("v.mergeSelectedInsertKeys", insertRows.map(function(r){ return r.insertKey; }));
        component.set("v.mergeSelectedDeleteLinkIds", deleteRows.map(function(r){ return r.contentDocumentLinkIdToDelete; }));

        helper._setText(component, "v.mergeExecStatusText", "Step " + (idx + 1) + " of " + queue.length + ": review inserts/deletes, then confirm." );
    },

    loadWizardStep : function(component) {
        var plan = component.get("v.mergePlan");
        var docs = component.get("v.mergeDuplicateDocs");
        var idx  = component.get("v.mergeStepIndex");
        var stepDoc = (docs && docs.length > idx) ? docs[idx] : null;

        component.set("v.mergeStepDoc", stepDoc);
        
        var map = component.get("v.mergeStepResultsByDocId") || {};
        var prior = stepDoc && stepDoc.duplicateDocId ? map[stepDoc.duplicateDocId] : null;
        
        if (prior) {
            component.set("v.mergeStepResult", prior);
            component.set("v.mergeExecLog", JSON.stringify(prior, null, 2));
            
            // if it was a real run that actually deleted the doc, keep step locked
            var isRollback = prior.rollbackMode === true;
            var docDeletedForReal = prior.deletedDuplicateDoc === true && prior.duplicateDocStillExists === false && !isRollback;
            component.set("v.mergeStepLocked", docDeletedForReal);
        } else {
            component.set("v.mergeStepResult", null);
            component.set("v.mergeExecLog", "");
            component.set("v.mergeStepLocked", false);
        }

        
        

        var rows = (plan && plan.rows) ? plan.rows : [];
        var inserts = [];
        var deletes = [];

        if (stepDoc && stepDoc.duplicateDocId) {
            rows.forEach(function(r){
                if (r.sourceDocId === stepDoc.duplicateDocId) {
                    if (r.willInsert) inserts.push(r);
                    if (r.willDelete) deletes.push(r);
                }
            });
        }
        
        component.set("v.mergeStepInsertRows", inserts);
        component.set("v.mergeStepDeleteRows", deletes);
        
        // STEP-LEVEL COVERAGE INDICATOR:
        // green if NONE of the planned deletes break coverage after the plan
        var covered = (deletes || []).every(function(r){
            return !r.deleteNotOnCanonical; // true means "this delete is safe / covered"
        });
        component.set("v.mergeStepDeletesCovered", covered);

        
        component.set("v.mergeStepSelectedInsertRows", []);
        component.set("v.mergeStepSelectedDeleteRows", []);
        component.set("v.mergeStepDeleteDocChecked", stepDoc && stepDoc.eligibleForDelete === true);
        //component.set("v.mergeExecLog", "");
        //component.set("v.mergeStepLocked", false);

        
    },

    executeMerge : function(component, rollbackOnly, strictAtomic) {
        var helper = this;

        var productId      = component.get("v.selectedProductId");
        var canonicalDocId = component.get("v.selectedCanonicalDocId");
        var stepDoc  = component.get("v.mergeStepDoc");
        var inserts  = component.get("v.mergeStepSelectedInsertRows") || [];
        var deletes  = component.get("v.mergeStepSelectedDeleteRows") || [];

        if (!stepDoc || !stepDoc.duplicateDocId) {
            alert("Merge wizard is missing the duplicate document context (duplicateDocId).");
            return;
        }

        var keepDuplicateDocId = stepDoc.duplicateDocId;
        var keepWasDeleteDocChecked = component.get("v.mergeStepDeleteDocChecked") === true;

        var insertLinks = (inserts || []).map(function(r) {
            return {
                linkedEntityId: r.linkedEntityId,
                shareType: r.shareType,
                visibility: r.visibility
            };
        });

        var deleteLinkIds = (deletes || []).map(function(r) {
            return r.contentDocumentLinkIdToDelete;
        });

        if (!Array.isArray(insertLinks)) insertLinks = [];
        if (!Array.isArray(deleteLinkIds)) deleteLinkIds = [];

        var deleteDoc = keepWasDeleteDocChecked;
        if (!stepDoc.eligibleForDelete) deleteDoc = false;

        component.set("v.mergeExecIsRunning", true);
        helper._setText(
            component,
            "v.mergeExecStatusText",
            rollbackOnly ? "Running rollback dry-run…" : "EXECUTING REAL MERGE…"
        );

        var action = component.get("c.executeMergeForOneDuplicate");
        action.setParams({
            productId: productId,
            canonicalDocId: canonicalDocId,
            duplicateDocId: keepDuplicateDocId,
            deleteDuplicateDoc: deleteDoc,
            insertLinks: insertLinks,
            deleteLinkIds: deleteLinkIds,
            rollbackOnly: rollbackOnly,
            strictAtomic: strictAtomic
        });

        action.setCallback(this, function(resp) {
            component.set("v.mergeExecIsRunning", false);
                        
            var state = resp.getState();
            if (state !== "SUCCESS") {
                var errs = resp.getError();
                component.set("v.mergeExecLog", JSON.stringify(errs, null, 2));
                
                component.set("v.mergeStepLocked", false);
                component.set("v.mergeStepResult", null);
                
                
                helper._setText(component, "v.mergeExecStatusText", "Merge failed (see log).");
                return;
                
            }
            
            var payload = resp.getReturnValue();
            component.set("v.mergeExecLog", JSON.stringify(payload, null, 2));
            
            var map = component.get("v.mergeStepResultsByDocId") || {};
            map[keepDuplicateDocId] = payload;
            component.set("v.mergeStepResultsByDocId", map);
            
            
            // STORE IT (this is the missing piece)
            component.set("v.mergeStepResult", payload);
            
            // LOCK only if this was a real run AND the doc is actually gone
            var isRollback = payload && (payload.rollbackMode === true);
            var docDeletedForReal =
                payload &&
                payload.deletedDuplicateDoc === true &&
                payload.duplicateDocStillExists === false &&
                isRollback === false; // <- this is the key fix for your JSON case
            
            component.set("v.mergeStepLocked", docDeletedForReal);
            
            
            
            
            
            // IMPORTANT: do NOT auto-refresh plan/candidates/doclinks here.
            // Leave the UI as-is so the tester can read the JSON.
            helper._setText(
                component,
                "v.mergeExecStatusText",
                (rollbackOnly ? "Dry-run complete." : "Merge complete.") + " (log captured; refresh manually)"
            );
            return;

            
        });

        $A.enqueueAction(action);
    }
})