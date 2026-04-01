/**
 * Asigna Account__c cuando ID_Interno__c (dirección) coincide con Account.ID_NetSuite__c.
 * Uso: Database.executeBatch(new ATV_AssignDireccionAccountByNSBatch(), 50);
 */
public class ATV_AssignDireccionAccountByNSBatch implements Database.Batchable<SObject>, Database.Stateful {
    private Map<String, Id> nsToAccountId;

    public Database.QueryLocator start(Database.BatchableContext bc) {
        nsToAccountId = new Map<String, Id>();
        for (Account a : [SELECT Id, ID_NetSuite__c FROM Account WHERE ID_NetSuite__c != null]) {
            String k = normKey(a.ID_NetSuite__c);
            if (k != null) {
                nsToAccountId.put(k, a.Id);
            }
        }
        return Database.getQueryLocator(
            [
                SELECT Id, Account__c, ID_Interno__c
                FROM ATV_NTS_Direccion_de_Envio__c
                WHERE ID_Interno__c != null
            ]
        );
    }

    public void execute(Database.BatchableContext bc, List<SObject> scope) {
        List<ATV_NTS_Direccion_de_Envio__c> updates = new List<ATV_NTS_Direccion_de_Envio__c>();
        for (SObject so : scope) {
            ATV_NTS_Direccion_de_Envio__c d = (ATV_NTS_Direccion_de_Envio__c) so;
            String k = normKey(d.ID_Interno__c);
            if (k == null || !nsToAccountId.containsKey(k)) {
                continue;
            }
            Id target = nsToAccountId.get(k);
            if (d.Account__c != target) {
                updates.add(new ATV_NTS_Direccion_de_Envio__c(Id = d.Id, Account__c = target));
            }
        }
        if (!updates.isEmpty()) {
            Database.update(updates, false);
        }
    }

    public void finish(Database.BatchableContext bc) {
    }

    @TestVisible
    private static String normKey(Object val) {
        if (val == null) {
            return null;
        }
        try {
            if (val instanceof String) {
                String s = ((String) val).trim();
                if (String.isBlank(s)) {
                    return null;
                }
                Decimal d = Decimal.valueOf(s);
                return d.stripTrailingZeros().toPlainString();
            }
            Decimal d;
            if (val instanceof Decimal) {
                d = (Decimal) val;
            } else if (val instanceof Double) {
                d = Decimal.valueOf(String.valueOf((Double) val));
            } else if (val instanceof Integer) {
                d = Decimal.valueOf((Integer) val);
            } else if (val instanceof Long) {
                d = Decimal.valueOf((Long) val);
            } else {
                String s = String.valueOf(val).trim();
                if (String.isBlank(s)) {
                    return null;
                }
                d = Decimal.valueOf(s);
            }
            return d.stripTrailingZeros().toPlainString();
        } catch (Exception e) {
            String s = String.valueOf(val).trim();
            return String.isBlank(s) ? null : s;
        }
    }
}
