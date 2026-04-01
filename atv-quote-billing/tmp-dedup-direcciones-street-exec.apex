public class DedupDireccionesByStreetRunner {
    public String norm(String v) {
        return String.isBlank(v) ? '' : v.trim().toUpperCase();
    }

    public void run(Boolean doDelete) {
        List<ATV_NTS_Direccion_de_Envio__c> dirs = [
            SELECT Id, CreatedDate, NTS_fld_ShippingStreet__c
            FROM ATV_NTS_Direccion_de_Envio__c
            WHERE NTS_fld_ShippingStreet__c != null
            ORDER BY CreatedDate ASC, Id ASC
        ];

        Map<String, Id> streetToMaster = new Map<String, Id>();
        Map<Id, Id> loserToMaster = new Map<Id, Id>();

        for (ATV_NTS_Direccion_de_Envio__c d : dirs) {
            String key = norm(d.NTS_fld_ShippingStreet__c);
            if (!streetToMaster.containsKey(key)) {
                streetToMaster.put(key, d.Id);
            } else {
                loserToMaster.put(d.Id, streetToMaster.get(key));
            }
        }

        Set<Id> loserIds = loserToMaster.keySet();
        System.debug('DEDUPE_STREET|groups=' + streetToMaster.size());
        System.debug('DEDUPE_STREET|duplicates=' + loserIds.size());

        if (loserIds.isEmpty()) {
            System.debug('DEDUPE_STREET|No duplicates found.');
            return;
        }

        List<Quote> quotes = [
            SELECT Id,
                   ATV_Selected_Shipping_Address__c,
                   ATV_Selected_Billing_Address__c,
                   Direcciones__c,
                   Selected_Shipping_Address__c
            FROM Quote
            WHERE ATV_Selected_Shipping_Address__c IN :loserIds
               OR ATV_Selected_Billing_Address__c IN :loserIds
               OR Direcciones__c IN :loserIds
               OR Selected_Shipping_Address__c IN :loserIds
        ];

        Integer relinkedValues = 0;
        for (Quote q : quotes) {
            if (q.ATV_Selected_Shipping_Address__c != null && loserToMaster.containsKey(q.ATV_Selected_Shipping_Address__c)) {
                q.ATV_Selected_Shipping_Address__c = loserToMaster.get(q.ATV_Selected_Shipping_Address__c);
                relinkedValues++;
            }
            if (q.ATV_Selected_Billing_Address__c != null && loserToMaster.containsKey(q.ATV_Selected_Billing_Address__c)) {
                q.ATV_Selected_Billing_Address__c = loserToMaster.get(q.ATV_Selected_Billing_Address__c);
                relinkedValues++;
            }
            if (q.Direcciones__c != null && loserToMaster.containsKey(q.Direcciones__c)) {
                q.Direcciones__c = loserToMaster.get(q.Direcciones__c);
                relinkedValues++;
            }
            if (q.Selected_Shipping_Address__c != null && loserToMaster.containsKey(q.Selected_Shipping_Address__c)) {
                q.Selected_Shipping_Address__c = loserToMaster.get(q.Selected_Shipping_Address__c);
                relinkedValues++;
            }
        }

        System.debug('DEDUPE_STREET|quotes_to_update=' + quotes.size());
        System.debug('DEDUPE_STREET|lookup_values_to_relink=' + relinkedValues);
        System.debug('DEDUPE_STREET|mode=' + (doDelete ? 'EXECUTE' : 'DRY_RUN'));

        if (!doDelete) return;

        if (!quotes.isEmpty()) {
            update quotes;
        }

        List<ATV_NTS_Direccion_de_Envio__c> toDelete = new List<ATV_NTS_Direccion_de_Envio__c>();
        for (Id loserId : loserIds) {
            toDelete.add(new ATV_NTS_Direccion_de_Envio__c(Id = loserId));
        }

        Database.DeleteResult[] dr = Database.delete(toDelete, false);
        Integer ok = 0;
        Integer ko = 0;
        for (Database.DeleteResult r : dr) {
            if (r.isSuccess()) ok++; else ko++;
        }
        System.debug('DEDUPE_STREET|deleted_ok=' + ok);
        System.debug('DEDUPE_STREET|deleted_errors=' + ko);
    }
}
new DedupDireccionesByStreetRunner().run(true);

