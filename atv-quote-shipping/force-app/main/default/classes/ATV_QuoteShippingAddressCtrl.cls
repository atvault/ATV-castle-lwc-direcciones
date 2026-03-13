public with sharing class ATV_QuoteShippingAddressCtrl {
    public class DireccionDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String label;
        @AuraEnabled public String street;
        @AuraEnabled public String city;
        /** Nombre de la Localidad (ATV_NTS_Localidad__r.Name) para mostrar con etiqueta "Localidad" en la UI */
        @AuraEnabled public String localidadName;
        @AuraEnabled public String state;
        @AuraEnabled public String postalCode;
        @AuraEnabled public String country;
        @AuraEnabled public Id localidadId;
        @AuraEnabled public String provinciaValue;
    }

    @AuraEnabled(cacheable=true)
    public static List<DireccionDTO> getDirecciones(Id accountId) {
        List<DireccionDTO> out = new List<DireccionDTO>();
        
        if (accountId == null) {
            return out;
        }

        try {
            List<ATV_NTS_Direccion_de_Envio__c> recs = [
                SELECT Id, Name,
                       NTS_fld_ShippingStreet__c,
                       NTS_fld_ShippingCity__c,
                       NTS_fld_ShippingState__c,
                       Estado_o_Provincia__c,
                       ATV_fld_ShippingPostalCode__c,
                       NTS_fld_ShippingCountry__c,
                       ATV_NTS_Localidad__c,
                       ATV_NTS_Localidad__r.Name,
                       ATV_NTS_Provincia__c
                FROM ATV_NTS_Direccion_de_Envio__c
                WHERE Account__c = :accountId
                ORDER BY CreatedDate DESC
                LIMIT 200
            ];

            for (ATV_NTS_Direccion_de_Envio__c r : recs) {
                DireccionDTO dto = new DireccionDTO();
                dto.id = r.Id;
                dto.street = r.NTS_fld_ShippingStreet__c;
                // Ciudad desde Localidad (objeto relacionado); si no hay, usar el campo ciudad de la dirección
                dto.localidadName = (r.ATV_NTS_Localidad__r != null && String.isNotBlank(r.ATV_NTS_Localidad__r.Name))
                    ? r.ATV_NTS_Localidad__r.Name
                    : null;
                dto.city = String.isNotBlank(dto.localidadName) ? dto.localidadName : r.NTS_fld_ShippingCity__c;
                // Usar NTS_fld_ShippingState__c o Estado_o_Provincia__c como fallback
                dto.state = String.isNotBlank(r.NTS_fld_ShippingState__c) 
                    ? r.NTS_fld_ShippingState__c 
                    : r.Estado_o_Provincia__c;
                dto.postalCode = r.ATV_fld_ShippingPostalCode__c;
                dto.country = r.NTS_fld_ShippingCountry__c;
                dto.localidadId = r.ATV_NTS_Localidad__c;
                dto.provinciaValue = r.ATV_NTS_Provincia__c;

                // Label "linda" para el dropdown
                List<String> parts = new List<String>();
                if (String.isNotBlank(r.Name)) {
                    parts.add(r.Name);
                }
                if (String.isNotBlank(dto.street)) {
                    parts.add(dto.street);
                }
                if (String.isNotBlank(dto.city)) {
                    parts.add(dto.city);
                }
                if (String.isNotBlank(dto.state)) {
                    parts.add(dto.state);
                }
                if (String.isNotBlank(dto.postalCode)) {
                    parts.add(dto.postalCode);
                }

                dto.label = parts.isEmpty() ? String.valueOf(r.Id) : String.join(parts, ' - ');

                out.add(dto);
            }
        } catch (QueryException e) {
            throw new AuraHandledException('Error de permisos o acceso: ' + e.getMessage());
        } catch (Exception e) {
            throw new AuraHandledException('Error al obtener direcciones: ' + e.getMessage() + ' - Tipo: ' + e.getTypeName());
        }
        
        return out;
    }

    // Opción para combobox: id + label (Localidades y Provincias)
    public class OptionDTO {
        @AuraEnabled public String value;
        @AuraEnabled public String label;
    }

    /**
     * Busca localidades en ATV_NTS_Localidades__c por nombre (10k+ registros).
     * Usa SOQL dinámico para no depender del metadata en el proyecto.
     */
    @AuraEnabled(cacheable=false)
    public static List<OptionDTO> getLocalidades(String searchTerm) {
        List<OptionDTO> out = new List<OptionDTO>();
        if (String.isBlank(searchTerm) || searchTerm.length() < 2) {
            return out;
        }
        try {
            String likeTerm = '%' + String.escapeSingleQuotes(searchTerm.trim()) + '%';
            List<SObject> recs = Database.query(
                'SELECT Id, Name FROM ATV_NTS_Localidades__c WHERE Name LIKE \'' + likeTerm + '\' ORDER BY Name LIMIT 50'
            );
            for (SObject r : recs) {
                OptionDTO o = new OptionDTO();
                o.value = (String) r.get('Id');
                o.label = (String) r.get('Name');
                if (String.isNotBlank(o.label)) {
                    out.add(o);
                }
            }
        } catch (Exception e) {
            throw new AuraHandledException('Error al buscar localidades: ' + e.getMessage());
        }
        return out;
    }

    /**
     * Devuelve opciones para Provincia desde el picklist de ATV_NTS_Direccion_de_Envio__c.ATV_NTS_Provincia__c (producción).
     */
    @AuraEnabled(cacheable=true)
    public static List<OptionDTO> getProvincias() {
        List<OptionDTO> out = new List<OptionDTO>();
        try {
            Schema.DescribeFieldResult df = ATV_NTS_Direccion_de_Envio__c.ATV_NTS_Provincia__c.getDescribe();
            if (df.getType() == Schema.DisplayType.Picklist) {
                for (Schema.PicklistEntry pe : df.getPicklistValues()) {
                    if (pe.isActive()) {
                        OptionDTO o = new OptionDTO();
                        o.value = pe.getValue();
                        o.label = pe.getLabel();
                        out.add(o);
                    }
                }
            }
        } catch (Exception e) {
            throw new AuraHandledException('Error al obtener provincias: ' + e.getMessage());
        }
        return out;
    }

    /** Firma original (7 params) para compatibilidad con tests y código existente en el org. */
    @AuraEnabled
    public static String updateQuoteShippingAddress(
        Id quoteId,
        String street,
        String city,
        String state,
        String postalCode,
        String country,
        Id selectedAddressId
    ) {
        return updateQuoteShippingWithLocalidad(quoteId, street, city, state, postalCode, country, selectedAddressId, null, null);
    }

    /** Actualiza Quote y opcionalmente la Dirección de envío con Localidad/Provincia. */
    @AuraEnabled
    public static String updateQuoteShippingWithLocalidad(
        Id quoteId,
        String street,
        String city,
        String state,
        String postalCode,
        String country,
        Id selectedAddressId,
        Id localidadId,
        String provinciaValue
    ) {
        if ((localidadId != null || String.isNotBlank(provinciaValue)) && selectedAddressId == null) {
            throw new AuraHandledException('Para asignar Localidad o Provincia tenés que seleccionar una dirección de envío.');
        }
        try {
            System.debug('=== INICIO updateQuoteShippingAddress ===');
            System.debug('QuoteId: ' + quoteId);
            System.debug('SelectedAddressId: ' + selectedAddressId);
            System.debug('Street: ' + street);
            System.debug('City: ' + city);
            System.debug('State: ' + state);
            System.debug('PostalCode: ' + postalCode);
            System.debug('Country: ' + country);
            
            // Obtener el Quote con su AccountId para validar el filtro del lookup
            System.debug('=== Paso 1: Obteniendo Quote ===');
            Quote quote = [
                SELECT Id, AccountId, QuoteAccountId
                FROM Quote
                WHERE Id = :quoteId
                LIMIT 1
            ];
            System.debug('Quote.AccountId: ' + quote.AccountId);
            System.debug('Quote.QuoteAccountId: ' + quote.QuoteAccountId);
            
            // Si hay una dirección seleccionada, validar que pertenezca a la cuenta de la Quote
            if (selectedAddressId != null && quote.AccountId != null) {
                System.debug('=== Paso 2: Validando dirección ===');
                List<ATV_NTS_Direccion_de_Envio__c> direcciones = [
                    SELECT Id, Account__c, Name
                    FROM ATV_NTS_Direccion_de_Envio__c
                    WHERE Id = :selectedAddressId
                    AND Account__c = :quote.AccountId
                    LIMIT 1
                ];
                
                System.debug('Direcciones encontradas: ' + direcciones.size());
                if (!direcciones.isEmpty()) {
                    System.debug('Dirección válida - Id: ' + direcciones[0].Id + ', Account__c: ' + direcciones[0].Account__c);
                }
                
                if (direcciones.isEmpty()) {
                    System.debug('ERROR: La dirección no pertenece a la cuenta');
                    throw new AuraHandledException('La dirección seleccionada no pertenece a la cuenta de la Quote. Quote.AccountId: ' + quote.AccountId + ', SelectedAddressId: ' + selectedAddressId);
                }
            }
            
            // Primera actualización: siempre aplicar shipping params a la Quote (permite limpiar con strings vacíos)
            System.debug('=== Paso 3: Primera actualización (campos de dirección y/o Localidad/Provincia) ===');
            Quote q1 = new Quote(Id = quoteId);
            
            q1.ShippingStreet = String.isNotBlank(street) ? street : null;
            q1.ShippingCity = String.isNotBlank(city) ? city : null;
            q1.ShippingState = String.isNotBlank(state) ? state : null;
            q1.ShippingPostalCode = String.isNotBlank(postalCode) ? postalCode : null;
            q1.ShippingCountry = String.isNotBlank(country) ? country : null;
            
            System.debug('Actualizando Quote...');
            update q1;
            
            // Localidad y Provincia impactan en el registro de Dirección de envío (no en Quote)
            if (selectedAddressId != null && (localidadId != null || String.isNotBlank(provinciaValue))) {
                System.debug('=== Actualizando Dirección de envío (Localidad/Provincia) ===');
                ATV_NTS_Direccion_de_Envio__c addr = new ATV_NTS_Direccion_de_Envio__c(Id = selectedAddressId);
                if (localidadId != null) {
                    addr.ATV_NTS_Localidad__c = localidadId;
                } else {
                    addr.ATV_NTS_Localidad__c = null;
                }
                if (String.isNotBlank(provinciaValue)) {
                    addr.ATV_NTS_Provincia__c = provinciaValue;
                } else {
                    addr.ATV_NTS_Provincia__c = null;
                }
                update addr;
                System.debug('Dirección de envío actualizada con Localidad/Provincia');
            }
            System.debug('Primera actualización exitosa');
            
            // Segunda actualización: solo el lookup (después de que los campos estén actualizados)
            if (selectedAddressId != null) {
                System.debug('=== Paso 4: Segunda actualización (lookup) ===');
                System.debug('Intentando actualizar ATV_Selected_Shipping_Address__c con: ' + selectedAddressId);
                
                // Obtener el Quote nuevamente para asegurar que tenemos los datos más recientes
                Quote quoteUpdated = [
                    SELECT Id, AccountId, QuoteAccountId
                    FROM Quote
                    WHERE Id = :quoteId
                    LIMIT 1
                ];
                System.debug('Quote después de primera actualización - AccountId: ' + quoteUpdated.AccountId + ', QuoteAccountId: ' + quoteUpdated.QuoteAccountId);
                
                Quote q2 = new Quote(Id = quoteId);
                q2.ATV_Selected_Shipping_Address__c = selectedAddressId;
                
                System.debug('Actualizando Quote con lookup...');
                update q2;
                System.debug('Segunda actualización exitosa');
            }
            
            System.debug('=== FIN updateQuoteShippingAddress - SUCCESS ===');
            return 'SUCCESS';
        } catch (DmlException e) {
            System.debug('=== ERROR DmlException ===');
            System.debug('Error Type: ' + e.getTypeName());
            System.debug('Error Message: ' + e.getMessage());
            System.debug('NumDml: ' + e.getNumDml());
            
            String errorMsg = 'Error al actualizar la Quote: ';
            for (Integer i = 0; i < e.getNumDml(); i++) {
                String dmlMsg = e.getDmlMessage(i);
                String dmlStatusCode = e.getDmlStatusCode(i);
                String[] dmlFields = e.getDmlFieldNames(i);
                
                System.debug('DML Error ' + i + ': ' + dmlMsg);
                System.debug('DML Status Code ' + i + ': ' + dmlStatusCode);
                System.debug('DML Fields ' + i + ': ' + String.join(dmlFields, ', '));
                
                errorMsg += dmlMsg;
                if (i < e.getNumDml() - 1) {
                    errorMsg += '; ';
                }
            }
            throw new AuraHandledException(errorMsg);
        } catch (Exception e) {
            System.debug('=== ERROR Exception ===');
            System.debug('Error Type: ' + e.getTypeName());
            System.debug('Error Message: ' + e.getMessage());
            System.debug('Stack Trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Error inesperado: ' + e.getMessage() + ' - Tipo: ' + e.getTypeName());
        }
    }
}