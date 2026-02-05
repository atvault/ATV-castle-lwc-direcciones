public with sharing class ATV_QuoteShippingAddressCtrl {
    public class DireccionDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String label;
        @AuraEnabled public String street;
        @AuraEnabled public String city;
        @AuraEnabled public String state;
        @AuraEnabled public String postalCode;
        @AuraEnabled public String country;
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
                       NTS_fld_ShippingCountry__c
                FROM ATV_NTS_Direccion_de_Envio__c
                WHERE Account__c = :accountId
                ORDER BY CreatedDate DESC
                LIMIT 200
            ];

            for (ATV_NTS_Direccion_de_Envio__c r : recs) {
                DireccionDTO dto = new DireccionDTO();
                dto.id = r.Id;
                dto.street = r.NTS_fld_ShippingStreet__c;
                dto.city = r.NTS_fld_ShippingCity__c;
                // Usar NTS_fld_ShippingState__c o Estado_o_Provincia__c como fallback
                dto.state = String.isNotBlank(r.NTS_fld_ShippingState__c) 
                    ? r.NTS_fld_ShippingState__c 
                    : r.Estado_o_Provincia__c;
                dto.postalCode = r.ATV_fld_ShippingPostalCode__c;
                dto.country = r.NTS_fld_ShippingCountry__c;

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
            
            // Primera actualización: solo los campos de dirección (sin el lookup)
            System.debug('=== Paso 3: Primera actualización (campos de dirección) ===');
            Quote q1 = new Quote(Id = quoteId);
            
            if (String.isNotBlank(street)) {
                q1.ShippingStreet = street;
            } else {
                q1.ShippingStreet = null;
            }
            
            if (String.isNotBlank(city)) {
                q1.ShippingCity = city;
            } else {
                q1.ShippingCity = null;
            }
            
            if (String.isNotBlank(state)) {
                q1.ShippingState = state;
            } else {
                q1.ShippingState = null;
            }
            
            if (String.isNotBlank(postalCode)) {
                q1.ShippingPostalCode = postalCode;
            } else {
                q1.ShippingPostalCode = null;
            }
            
            if (String.isNotBlank(country)) {
                q1.ShippingCountry = country;
            } else {
                q1.ShippingCountry = null;
            }
            
            System.debug('Actualizando Quote con campos de dirección...');
            update q1;
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