public class DedupDireccionesRunner {
    public String norm(String v) {
        return String.isBlank(v) ? '' : v.trim().toUpperCase();
    }

    public void run(Boolean doDelete) {
        List<ATV_NTS_Direccion_de_Envio__c> dirs = [
            SELECT Id, CreatedDate, Account__c,
                   NTS_fld_ShippingStreet__c,
                   NTS_fld_ShippingCity__c,
                   NTS_fld_ShippingState__c,
                   ATV_fld_ShippingPostalCode__c,
                   NTS_fld_ShippingCountry__c,
                   ATV_NTS_Localidad__c,
                   ATV_NTS_Provincia__c
            FROM ATV_NTS_Direccion_de_Envio__c
            ORDER BY CreatedDate ASC, Id ASC
        ];

        Map<String, Id> keyToMaster = new Map<String, Id>();
        Map<Id, Id> loserToMaster = new Map<Id, Id>();

        for (ATV_NTS_Direccion_de_Envio__c d : dirs) {
            String key = String.valueOf(d.Account__c) + '|' +
                norm(d.NTS_fld_ShippingStreet__c) + '|' +
                norm(d.NTS_fld_ShippingCity__c) + '|' +
                norm(d.NTS_fld_ShippingState__c) + '|' +
                norm(d.ATV_fld_ShippingPostalCode__c) + '|' +
                norm(d.NTS_fld_ShippingCountry__c) + '|' +
                String.valueOf(d.ATV_NTS_Localidad__c) + '|' +
                norm(d.ATV_NTS_Provincia__c);

            if (!keyToMaster.containsKey(key)) {
                keyToMaster.put(key, d.Id);
            } else {
                loserToMaster.put(d.Id, keyToMaster.get(key));
            }
        }

        Set<Id> loserIds = loserToMaster.keySet();
        System.debug('DEDUPE|groups=' + keyToMaster.size());
        System.debug('DEDUPE|duplicates=' + loserIds.size());

        if (loserIds.isEmpty()) {
            System.debug('DEDUPE|No duplicates found.');
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

        System.debug('DEDUPE|quotes_to_update=' + quotes.size());
        System.debug('DEDUPE|lookup_values_to_relink=' + relinkedValues);
        System.debug('DEDUPE|mode=' + (doDelete ? 'EXECUTE' : 'DRY_RUN'));

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
        System.debug('DEDUPE|deleted_ok=' + ok);
        System.debug('DEDUPE|deleted_errors=' + ko);
    }
}
new DedupDireccionesRunner().run(true);

