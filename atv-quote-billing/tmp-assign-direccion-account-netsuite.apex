/**
 * Asigna Account__c en direcciones donde ID_Interno__c coincide con Account.ID_NetSuite__c.
 * Dry-run: run(false) | Ejecutar: run(true)
 */
public class AssignDireccionAccountByNetSuite {
    /** Normaliza texto o número a una clave comparable (ej. "3285", "3285.0" -> "3285"). */
    public String normKey(Object val) {
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

    public void run(Boolean doUpdate) {
        Map<String, Id> nsToAccountId = new Map<String, Id>();
        Map<String, Integer> dupCount = new Map<String, Integer>();

        for (Account a : [
            SELECT Id, ID_NetSuite__c
            FROM Account
            WHERE ID_NetSuite__c != null
        ]) {
            String k = normKey(a.ID_NetSuite__c);
            if (k == null) {
                continue;
            }
            if (nsToAccountId.containsKey(k) && nsToAccountId.get(k) != a.Id) {
                dupCount.put(k, dupCount.containsKey(k) ? dupCount.get(k) + 1 : 2);
            }
            nsToAccountId.put(k, a.Id);
        }

        List<ATV_NTS_Direccion_de_Envio__c> dirs = [
            SELECT Id, Account__c, ID_Interno__c
            FROM ATV_NTS_Direccion_de_Envio__c
            WHERE ID_Interno__c != null
        ];

        Integer alreadyOk = 0;
        Integer noMatch = 0;
        Integer toChange = 0;
        List<ATV_NTS_Direccion_de_Envio__c> updates = new List<ATV_NTS_Direccion_de_Envio__c>();

        for (ATV_NTS_Direccion_de_Envio__c d : dirs) {
            String k = normKey(d.ID_Interno__c);
            if (k == null || !nsToAccountId.containsKey(k)) {
                noMatch++;
                continue;
            }
            Id targetAcc = nsToAccountId.get(k);
            if (d.Account__c == targetAcc) {
                alreadyOk++;
            } else {
                toChange++;
                if (doUpdate) {
                    updates.add(
                        new ATV_NTS_Direccion_de_Envio__c(Id = d.Id, Account__c = targetAcc)
                    );
                }
            }
        }

        System.debug('NS_ASSIGN|mode=' + (doUpdate ? 'EXECUTE' : 'DRY_RUN'));
        System.debug('NS_ASSIGN|accounts_with_netsuite_id=' + nsToAccountId.size());
        System.debug('NS_ASSIGN|duplicate_netsuite_keys=' + dupCount.size());
        System.debug('NS_ASSIGN|direcciones_with_id_interno=' + dirs.size());
        System.debug('NS_ASSIGN|already_correct_account=' + alreadyOk);
        System.debug('NS_ASSIGN|no_matching_account=' + noMatch);
        System.debug('NS_ASSIGN|rows_to_update=' + toChange);

        if (!doUpdate || updates.isEmpty()) {
            return;
        }

        Database.SaveResult[] srs = Database.update(updates, false);
        Integer ok = 0;
        Integer err = 0;
        for (Database.SaveResult sr : srs) {
            if (sr.isSuccess()) {
                ok++;
            } else {
                err++;
            }
        }
        System.debug('NS_ASSIGN|updated_ok=' + ok);
        System.debug('NS_ASSIGN|updated_errors=' + err);
    }
}
new AssignDireccionAccountByNetSuite().run(false);
