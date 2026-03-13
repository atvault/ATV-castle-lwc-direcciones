@IsTest
private class ATV_QuoteShippingAddressCtrlTest {

    // ---------- Helpers ----------
    private static Account makeAccount(String nameSuffix) {
        Account a = new Account(Name = 'Test Acc ' + nameSuffix);
        insert a;
        return a;
    }

    // Comparación robusta para strings normalizados (upper/trim) por Flows/Triggers de la org
    private static void assertEqualsIgnoreCase(String expected, String actual, String msg) {
        String e = expected == null ? null : expected.trim().toUpperCase();
        String a = actual   == null ? null : actual.trim().toUpperCase();
        System.assertEquals(e, a, msg);
    }

    private static Opportunity makeOpp(Account a) {
        Id stdPbId = Test.getStandardPricebookId();

        Opportunity o = new Opportunity(
            Name = 'Test Opp ' + a.Name,
            AccountId = a.Id,
            StageName = 'MQL',                 // <-- BYPASS VRs (según tus reglas)
            CloseDate = Date.today().addDays(10),
            Pricebook2Id = stdPbId,
            Primary_Contact_c__c = true        // checkbox (según tu org)
        );
        insert o;
        return o;
    }

    private static Quote makeQuote(Account a, Opportunity o) {
        Quote q = new Quote(
            Name = 'Test Quote ' + a.Name,
            OpportunityId = o.Id,
            Pricebook2Id = o.Pricebook2Id
        );
        insert q;
        return q;
    }

    // Crea un producto + PricebookEntry dentro de un Pricebook específico
    private static PricebookEntry makePbe(Id pricebook2Id) {
        Product2 p = new Product2(
            Name = 'Test Product ' + String.valueOf(Math.random()),
            IsActive = true
        );
        insert p;

        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = pricebook2Id,
            Product2Id = p.Id,
            UnitPrice = 100,
            IsActive = true,
            UseStandardPrice = false
        );
        insert pbe;

        return pbe;
    }

    private static void addQuoteLineItem(Quote q) {
        // Evita VRs del tipo "Falta agregar productos" en Quote
        PricebookEntry pbe = makePbe(q.Pricebook2Id);

        QuoteLineItem qli = new QuoteLineItem(
            QuoteId = q.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 1,
            UnitPrice = 100
        );
        insert qli;
    }

    private static ATV_NTS_Direccion_de_Envio__c makeDireccion(
        Account a,
        String name,
        String street,
        String city,
        String ntsState,
        String fallbackState,
        String postal,
        String country
    ) {
        ATV_NTS_Direccion_de_Envio__c d = new ATV_NTS_Direccion_de_Envio__c();
        d.Name = name;
        d.Account__c = a.Id;

        d.NTS_fld_ShippingStreet__c = street;
        d.NTS_fld_ShippingCity__c = city;
        d.NTS_fld_ShippingState__c = ntsState;
        d.Estado_o_Provincia__c = fallbackState;
        d.ATV_fld_ShippingPostalCode__c = postal;
        d.NTS_fld_ShippingCountry__c = country;

        insert d;
        return d;
    }

    // ---------- Tests getDirecciones ----------
    @IsTest
    static void testGetDirecciones_nullAccount() {
        Test.startTest();
        List<ATV_QuoteShippingAddressCtrl.DireccionDTO> res =
            ATV_QuoteShippingAddressCtrl.getDirecciones(null);
        Test.stopTest();

        System.assertNotEquals(null, res, 'Debe devolver lista (no null)');
        System.assertEquals(0, res.size(), 'Con accountId null debe devolver vacío');
    }

    @IsTest
    static void testGetDirecciones_withRecords_andStateFallback_andLabel() {
        Account a = makeAccount('A1');

        ATV_NTS_Direccion_de_Envio__c d1 = makeDireccion(
            a, 'Dir Uno', 'Calle 123', 'Rosario',
            null, 'Santa Fe', 'S2000', 'AR'
        );

        ATV_NTS_Direccion_de_Envio__c d2 = makeDireccion(
            a, 'Dir Dos', 'Av. Siempre Viva 742', 'CABA',
            'Buenos Aires', 'BA Fallback', 'C1000', 'AR'
        );

        Test.startTest();
        List<ATV_QuoteShippingAddressCtrl.DireccionDTO> res =
            ATV_QuoteShippingAddressCtrl.getDirecciones(a.Id);
        Test.stopTest();

        System.assertEquals(2, res.size(), 'Debe traer 2 direcciones');

        Map<Id, ATV_QuoteShippingAddressCtrl.DireccionDTO> byId =
            new Map<Id, ATV_QuoteShippingAddressCtrl.DireccionDTO>();
        for (ATV_QuoteShippingAddressCtrl.DireccionDTO dto : res) {
            byId.put(dto.id, dto);
        }

        // Estado: uno usa fallback, otro usa NTS
        System.assertEquals('Santa Fe', byId.get(d1.Id).state, 'Debe aplicar fallback Estado_o_Provincia__c');
        System.assertEquals('Buenos Aires', byId.get(d2.Id).state, 'Debe usar NTS_fld_ShippingState__c si está');

        String label1 = byId.get(d1.Id).label;
        System.assert(label1.contains('Dir Uno'));
        System.assert(label1.contains('Calle 123'));
        System.assert(label1.contains('Rosario'));
        System.assert(label1.contains('Santa Fe'));
        System.assert(label1.contains('S2000'));
    }

    // ---------- Tests updateQuoteShippingAddress ----------
    @IsTest
    static void testUpdateQuoteShippingAddress_success_withSelectedAddress() {
        Account a = makeAccount('A2');
        Opportunity o = makeOpp(a);
        Quote q = makeQuote(a, o);
        addQuoteLineItem(q);

        ATV_NTS_Direccion_de_Envio__c d = makeDireccion(
            a, 'Dir OK', 'Av. Eva Peron 9100', 'Rosario',
            'Santa Fe', null, 'S2013', 'AR'
        );

        Test.startTest();
        String result = ATV_QuoteShippingAddressCtrl.updateQuoteShippingAddress(
            q.Id,
            'Av. Eva Peron 9100',
            'Rosario',
            'Santa Fe',
            'S2013',
            'AR',
            d.Id
        );
        Test.stopTest();

        System.assertEquals('SUCCESS', result, 'Debe devolver SUCCESS');

        Quote qAfter = [
            SELECT ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, ShippingCountry,
                   ATV_Selected_Shipping_Address__c
            FROM Quote
            WHERE Id = :q.Id
        ];

        // Comparaciones case-insensitive por normalización automática de la org
        assertEqualsIgnoreCase('Av. Eva Peron 9100', qAfter.ShippingStreet, 'ShippingStreet debería coincidir (case-insensitive)');
        assertEqualsIgnoreCase('Rosario', qAfter.ShippingCity, 'ShippingCity debería coincidir (case-insensitive)');
        assertEqualsIgnoreCase('Santa Fe', qAfter.ShippingState, 'ShippingState debería coincidir (case-insensitive)');

        // PostalCode típicamente no se normaliza; lo dejamos exacto
        System.assertEquals('S2013', qAfter.ShippingPostalCode);

        assertEqualsIgnoreCase('AR', qAfter.ShippingCountry, 'ShippingCountry debería coincidir (case-insensitive)');

        System.assertEquals(d.Id, qAfter.ATV_Selected_Shipping_Address__c, 'Debe setear lookup a la dirección seleccionada');
    }

    @IsTest
    static void testUpdateQuoteShippingAddress_invalidAddress_throwsAuraHandledException() {
        Account a1 = makeAccount('A3_1');
        Opportunity o1 = makeOpp(a1);
        Quote q1 = makeQuote(a1, o1);
        addQuoteLineItem(q1);

        Account a2 = makeAccount('A3_2');
        ATV_NTS_Direccion_de_Envio__c dOther = makeDireccion(
            a2, 'Dir Otra Cuenta', 'Calle Falsa 123', 'CABA',
            'Buenos Aires', null, 'C1000', 'AR'
        );

        Boolean thrown = false;

        Test.startTest();
        try {
            ATV_QuoteShippingAddressCtrl.updateQuoteShippingAddress(
                q1.Id,
                'X',
                'Y',
                'Z',
                '0000',
                'AR',
                dOther.Id
            );
            System.assert(false, 'Se esperaba AuraHandledException y no se lanzó.');
        } catch (AuraHandledException ex) {
            thrown = true;
            // No validamos ex.getMessage(): en tests puede venir como "Script-thrown exception"
        }
        Test.stopTest();

        System.assert(thrown, 'Debe lanzar AuraHandledException cuando la dirección no pertenece a la cuenta.');
    }

    @IsTest
    static void testUpdateQuoteShippingAddress_blankStrings_clearsFields() {
        Account a = makeAccount('A4');
        Opportunity o = makeOpp(a);
        Quote q = makeQuote(a, o);
        addQuoteLineItem(q);

        q.ShippingStreet = 'Old';
        q.ShippingCity = 'Old';
        q.ShippingState = 'Old';
        q.ShippingPostalCode = 'Old';
        q.ShippingCountry = 'Old';
        update q;

        Test.startTest();
        String result = ATV_QuoteShippingAddressCtrl.updateQuoteShippingAddress(
            q.Id,
            '',      // blank => null
            '   ',   // blank => null
            null,    // null => null
            '',      // blank => null
            '',      // blank => null
            null     // sin lookup
        );
        Test.stopTest();

        System.assertEquals('SUCCESS', result);

        Quote qAfter = [
            SELECT ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, ShippingCountry,
                   ATV_Selected_Shipping_Address__c
            FROM Quote
            WHERE Id = :q.Id
        ];

        System.assertEquals(null, qAfter.ShippingStreet);
        System.assertEquals(null, qAfter.ShippingCity);
        System.assertEquals(null, qAfter.ShippingState);
        System.assertEquals(null, qAfter.ShippingPostalCode);
        System.assertEquals(null, qAfter.ShippingCountry);
        System.assertEquals(null, qAfter.ATV_Selected_Shipping_Address__c);
    }

    // ---------- Coverage del catch(DmlException) ----------
    @IsTest
    static void testUpdateQuoteShippingAddress_dmlException_isCovered() {
        Account a = makeAccount('A5');
        Opportunity o = makeOpp(a);
        Quote q = makeQuote(a, o);
        addQuoteLineItem(q);

        // Forzar STRING_TOO_LONG en ShippingStreet
        String veryLongStreet = '';
        for (Integer i = 0; i < 400; i++) {
            veryLongStreet += 'X';
        }

        Boolean thrown = false;

        Test.startTest();
        try {
            ATV_QuoteShippingAddressCtrl.updateQuoteShippingAddress(
                q.Id,
                veryLongStreet,  // rompe update q1
                'City',
                'State',
                '0000',
                'AR',
                null
            );
            System.assert(false, 'Se esperaba AuraHandledException por DmlException y no se lanzó.');
        } catch (AuraHandledException ex) {
            thrown = true;
        }
        Test.stopTest();

        System.assert(thrown, 'Debe lanzar AuraHandledException cuando ocurre un DmlException.');
    }

    // ---------- Tests getLocalidades ----------
    @IsTest
    static void testGetLocalidades_shortTerm_returnsEmpty() {
        Test.startTest();
        List<ATV_QuoteShippingAddressCtrl.OptionDTO> res = ATV_QuoteShippingAddressCtrl.getLocalidades('x');
        Test.stopTest();
        System.assertNotEquals(null, res);
        System.assertEquals(0, res.size(), 'Menos de 2 caracteres debe devolver vacío');
    }

    @IsTest
    static void testGetLocalidades_searchReturnsList() {
        Test.startTest();
        List<ATV_QuoteShippingAddressCtrl.OptionDTO> res = ATV_QuoteShippingAddressCtrl.getLocalidades('San');
        Test.stopTest();
        System.assertNotEquals(null, res);
        // Puede estar vacío si no hay datos en el org; solo verificamos que no lance
    }

    // ---------- Tests getProvincias ----------
    @IsTest
    static void testGetProvincias_returnsPicklistValues() {
        Test.startTest();
        List<ATV_QuoteShippingAddressCtrl.OptionDTO> res = ATV_QuoteShippingAddressCtrl.getProvincias();
        Test.stopTest();
        System.assertNotEquals(null, res);
        // El picklist en Direccion de Envio tiene valores; puede estar vacío en sandbox sin config
    }

    // ---------- Tests updateQuoteShippingWithLocalidad ----------
    @IsTest
    static void testUpdateQuoteShippingWithLocalidad_provinciaWithoutAddress_throws() {
        Account a = makeAccount('A6');
        Opportunity o = makeOpp(a);
        Quote q = makeQuote(a, o);
        addQuoteLineItem(q);

        Boolean thrown = false;
        Test.startTest();
        try {
            ATV_QuoteShippingAddressCtrl.updateQuoteShippingWithLocalidad(
                q.Id, null, null, null, null, null, null, null, 'Buenos Aires'
            );
        } catch (AuraHandledException e) {
            thrown = true;
        }
        Test.stopTest();
        System.assert(thrown, 'Debe lanzar si se pasa Provincia sin dirección seleccionada');
    }

    @IsTest
    static void testUpdateQuoteShippingWithLocalidad_withAddressAndLocalidad() {
        Account a = makeAccount('A7');
        Opportunity o = makeOpp(a);
        Quote q = makeQuote(a, o);
        addQuoteLineItem(q);

        ATV_NTS_Direccion_de_Envio__c d = makeDireccion(
            a, 'Dir L', 'Calle 1', 'CABA', 'Capital Federal', null, 'C1000', 'AR'
        );

        Test.startTest();
        String result = ATV_QuoteShippingAddressCtrl.updateQuoteShippingWithLocalidad(
            q.Id,
            'Calle 1',
            'CABA',
            'Capital Federal',
            'C1000',
            'AR',
            d.Id,
            null,
            'Capital Federal'
        );
        Test.stopTest();

        System.assertEquals('SUCCESS', result);
        ATV_NTS_Direccion_de_Envio__c dAfter = [SELECT ATV_NTS_Provincia__c FROM ATV_NTS_Direccion_de_Envio__c WHERE Id = :d.Id];
        System.assertEquals('Capital Federal', dAfter.ATV_NTS_Provincia__c);
    }
}