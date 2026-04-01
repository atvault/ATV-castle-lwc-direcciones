@IsTest
private class ATV_AssignDireccionAccountByNSBatchTest {
    @IsTest
    static void normKey_normalizes_numeric_strings() {
        System.assertEquals('12345', ATV_AssignDireccionAccountByNSBatch.normKey('12345'));
        System.assertEquals('12345', ATV_AssignDireccionAccountByNSBatch.normKey('012345'));
        System.assertEquals(null, ATV_AssignDireccionAccountByNSBatch.normKey('   '));
    }

    @IsTest
    static void normKey_coerces_numbers() {
        System.assertEquals('99', ATV_AssignDireccionAccountByNSBatch.normKey(99));
        System.assertEquals('100', ATV_AssignDireccionAccountByNSBatch.normKey(100L));
        Double dbl = 3.14;
        System.assertEquals('3.14', ATV_AssignDireccionAccountByNSBatch.normKey(dbl));
        System.assertEquals('7', ATV_AssignDireccionAccountByNSBatch.normKey(Decimal.valueOf('7.0')));
    }

    @IsTest
    static void normKey_non_numeric_returns_trimmed() {
        System.assertEquals('ABC-X', ATV_AssignDireccionAccountByNSBatch.normKey('ABC-X'));
    }

    @IsTest
    static void batch_sets_account_from_matching_id() {
        Account acc = new Account(Name = 'Batch NS Test', ID_NetSuite__c = 888001);
        insert acc;

        ATV_NTS_Direccion_de_Envio__c dir = new ATV_NTS_Direccion_de_Envio__c(
            Name = 'Dir test NS',
            ID_Interno__c = '888001'
        );
        insert dir;

        Test.startTest();
        Database.executeBatch(new ATV_AssignDireccionAccountByNSBatch(), 50);
        Test.stopTest();

        dir = [SELECT Account__c FROM ATV_NTS_Direccion_de_Envio__c WHERE Id = :dir.Id];
        System.assertEquals(acc.Id, dir.Account__c);
    }

    @IsTest
    static void batch_skips_when_no_matching_account() {
        ATV_NTS_Direccion_de_Envio__c dir = new ATV_NTS_Direccion_de_Envio__c(
            Name = 'Dir no match',
            ID_Interno__c = '999999991'
        );
        insert dir;

        Test.startTest();
        Database.executeBatch(new ATV_AssignDireccionAccountByNSBatch(), 50);
        Test.stopTest();

        dir = [SELECT Account__c FROM ATV_NTS_Direccion_de_Envio__c WHERE Id = :dir.Id];
        System.assertEquals(null, dir.Account__c);
    }

    @IsTest
    static void batch_skips_when_account_already_correct() {
        Account acc = new Account(Name = 'Batch NS ok', ID_NetSuite__c = 777200);
        insert acc;

        ATV_NTS_Direccion_de_Envio__c dir = new ATV_NTS_Direccion_de_Envio__c(
            Name = 'Dir already linked',
            ID_Interno__c = '777200',
            Account__c = acc.Id
        );
        insert dir;

        Test.startTest();
        Database.executeBatch(new ATV_AssignDireccionAccountByNSBatch(), 50);
        Test.stopTest();

        dir = [SELECT Account__c FROM ATV_NTS_Direccion_de_Envio__c WHERE Id = :dir.Id];
        System.assertEquals(acc.Id, dir.Account__c);
    }
}
