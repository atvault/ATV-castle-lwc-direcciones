@IsTest
private class ATV_QuoteBillingAddressCtrlTest {
    private static Account makeAccount(String suffix) {
        Account a = new Account(Name = 'Test Acc Billing ' + suffix);
        insert a;
        return a;
    }

    private static Opportunity makeOpp(Account a) {
        Id stdPbId = Test.getStandardPricebookId();
        Opportunity o = new Opportunity(
            Name = 'Test Opp Billing ' + a.Name,
            AccountId = a.Id,
            StageName = 'MQL',
            CloseDate = Date.today().addDays(10),
            Pricebook2Id = stdPbId,
            Primary_Contact_c__c = true
        );
        insert o;
        return o;
    }

    private static Quote makeQuote(Account a, Opportunity o) {
        Quote q = new Quote(Name = 'Test Quote Billing ' + a.Name, OpportunityId = o.Id, Pricebook2Id = o.Pricebook2Id);
        insert q;
        return q;
    }

    private static PricebookEntry makePbe(Id pricebook2Id) {
        Product2 p = new Product2(Name = 'Test Product Billing ' + String.valueOf(Math.random()), IsActive = true);
        insert p;
        PricebookEntry pbe = new PricebookEntry(Pricebook2Id = pricebook2Id, Product2Id = p.Id, UnitPrice = 100, IsActive = true, UseStandardPrice = false);
        insert pbe;
        return pbe;
    }

    private static void addQuoteLineItem(Quote q) {
        PricebookEntry pbe = makePbe(q.Pricebook2Id);
        insert new QuoteLineItem(QuoteId = q.Id, PricebookEntryId = pbe.Id, Quantity = 1, UnitPrice = 100);
    }

    private static ATV_NTS_Direccion_de_Envio__c makeDireccion(Account a, String name, String street, String city, String state, String postal, String country) {
        ATV_NTS_Direccion_de_Envio__c d = new ATV_NTS_Direccion_de_Envio__c();
        d.Name = name;
        d.Account__c = a.Id;
        d.NTS_fld_ShippingStreet__c = street;
        d.NTS_fld_ShippingCity__c = city;
        d.NTS_fld_ShippingState__c = state;
        d.ATV_fld_ShippingPostalCode__c = postal;
        d.NTS_fld_ShippingCountry__c = country;
        insert d;
        return d;
    }

    @IsTest
    static void testGetDirecciones_nullAccount() {
        Test.startTest();
        List<ATV_QuoteBillingAddressCtrl.DireccionDTO> res = ATV_QuoteBillingAddressCtrl.getDirecciones(null);
        Test.stopTest();
        System.assertNotEquals(null, res);
        System.assertEquals(0, res.size());
    }

    @IsTest
    static void testUpdateQuoteBillingAddress_success() {
        Account a = makeAccount('A1');
        Opportunity o = makeOpp(a);
        Quote q = makeQuote(a, o);
        addQuoteLineItem(q);
        ATV_NTS_Direccion_de_Envio__c d = makeDireccion(a, 'Dir Billing', 'Av. Billing 123', 'Rosario', 'Santa Fe', 'S2000', 'AR');

        Test.startTest();
        String result = ATV_QuoteBillingAddressCtrl.updateQuoteBillingAddress(q.Id, 'Av. Billing 123', 'Rosario', 'Santa Fe', 'S2000', 'AR', d.Id);
        Test.stopTest();

        System.assertEquals('SUCCESS', result);
        Quote qAfter = [SELECT BillingStreet, BillingCity, BillingState, BillingPostalCode, BillingCountry, ATV_Selected_Billing_Address__c FROM Quote WHERE Id = :q.Id];
        System.assertEquals('Av. Billing 123', qAfter.BillingStreet);
        System.assertEquals('Rosario', qAfter.BillingCity);
        System.assertEquals('Santa Fe', qAfter.BillingState);
        System.assertEquals('S2000', qAfter.BillingPostalCode);
        System.assertEquals('AR', qAfter.BillingCountry);
        System.assertEquals(d.Id, qAfter.ATV_Selected_Billing_Address__c);
    }

    @IsTest
    static void testGetDirecciones_withRecords() {
        Account a = makeAccount('A-dir');
        makeDireccion(a, 'Dir 1', 'Calle 123', 'Rosario', 'Santa Fe', 'S2000', 'AR');
        makeDireccion(a, 'Dir 2', 'Av 456', 'CABA', 'Buenos Aires', 'C1000', 'AR');

        Test.startTest();
        List<ATV_QuoteBillingAddressCtrl.DireccionDTO> res = ATV_QuoteBillingAddressCtrl.getDirecciones(a.Id);
        Test.stopTest();

        System.assertEquals(2, res.size(), 'Debe traer dos direcciones');
        System.assertNotEquals(null, res[0].label, 'Debe construir label para combobox');
        System.assertNotEquals(null, res[0].city, 'Debe informar ciudad');
    }

    @IsTest
    static void testUpdateQuoteBillingAddress_invalidAddress_throwsAuraHandledException() {
        Account a1 = makeAccount('A2_1');
        Opportunity o1 = makeOpp(a1);
        Quote q1 = makeQuote(a1, o1);
        addQuoteLineItem(q1);

        Account a2 = makeAccount('A2_2');
        ATV_NTS_Direccion_de_Envio__c dOther = makeDireccion(
            a2,
            'Dir otra cuenta',
            'Calle 1',
            'CABA',
            'Buenos Aires',
            'C1000',
            'AR'
        );

        Boolean thrown = false;
        Test.startTest();
        try {
            ATV_QuoteBillingAddressCtrl.updateQuoteBillingAddress(
                q1.Id,
                'Calle 1',
                'CABA',
                'Buenos Aires',
                'C1000',
                'AR',
                dOther.Id
            );
        } catch (AuraHandledException e) {
            thrown = true;
        }
        Test.stopTest();

        System.assert(thrown, 'Debe lanzar excepcion cuando la direccion no pertenece a la cuenta.');
    }

    @IsTest
    static void testUpdateQuoteBillingAddress_dmlException_isCovered() {
        Account a = makeAccount('A-dml');
        Opportunity o = makeOpp(a);
        Quote q = makeQuote(a, o);
        addQuoteLineItem(q);

        String veryLongStreet = '';
        for (Integer i = 0; i < 400; i++) {
            veryLongStreet += 'X';
        }

        Boolean thrown = false;
        Test.startTest();
        try {
            ATV_QuoteBillingAddressCtrl.updateQuoteBillingAddress(
                q.Id,
                veryLongStreet,
                'City',
                'State',
                '0000',
                'AR',
                null
            );
        } catch (AuraHandledException e) {
            thrown = true;
        }
        Test.stopTest();

        System.assert(thrown, 'Debe lanzar excepcion cuando ocurre un DmlException.');
    }
}
