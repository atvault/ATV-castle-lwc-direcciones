public with sharing class ATV_QuoteBillingAddressCtrl {
    public class DireccionDTO {
        @AuraEnabled public Id id;
        @AuraEnabled public String label;
        @AuraEnabled public String street;
        @AuraEnabled public String city;
        @AuraEnabled public String localidadName;
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
                       NTS_fld_ShippingCountry__c,
                       ATV_NTS_Localidad__r.Name
                FROM ATV_NTS_Direccion_de_Envio__c
                WHERE Account__c = :accountId
                ORDER BY CreatedDate DESC
                LIMIT 200
            ];

            for (ATV_NTS_Direccion_de_Envio__c r : recs) {
                DireccionDTO dto = new DireccionDTO();
                dto.id = r.Id;
                dto.street = r.NTS_fld_ShippingStreet__c;
                dto.localidadName = (r.ATV_NTS_Localidad__r != null && String.isNotBlank(r.ATV_NTS_Localidad__r.Name))
                    ? r.ATV_NTS_Localidad__r.Name
                    : null;
                dto.city = String.isNotBlank(dto.localidadName) ? dto.localidadName : r.NTS_fld_ShippingCity__c;
                dto.state = String.isNotBlank(r.NTS_fld_ShippingState__c)
                    ? r.NTS_fld_ShippingState__c
                    : r.Estado_o_Provincia__c;
                dto.postalCode = r.ATV_fld_ShippingPostalCode__c;
                dto.country = r.NTS_fld_ShippingCountry__c;

                List<String> parts = new List<String>();
                if (String.isNotBlank(r.Name)) parts.add(r.Name);
                if (String.isNotBlank(dto.street)) parts.add(dto.street);
                if (String.isNotBlank(dto.city)) parts.add(dto.city);
                if (String.isNotBlank(dto.state)) parts.add(dto.state);
                if (String.isNotBlank(dto.postalCode)) parts.add(dto.postalCode);

                dto.label = parts.isEmpty() ? String.valueOf(r.Id) : String.join(parts, ' - ');
                out.add(dto);
            }
        } catch (QueryException e) {
            throw new AuraHandledException('Error de permisos o acceso: ' + e.getMessage());
        } catch (Exception e) {
            throw new AuraHandledException('Error al obtener direcciones de facturacion: ' + e.getMessage());
        }

        return out;
    }

    @AuraEnabled
    public static String updateQuoteBillingAddress(
        Id quoteId,
        String street,
        String city,
        String state,
        String postalCode,
        String country,
        Id selectedAddressId
    ) {
        try {
            Quote quote = [SELECT Id, AccountId FROM Quote WHERE Id = :quoteId LIMIT 1];

            if (selectedAddressId != null && quote.AccountId != null) {
                List<ATV_NTS_Direccion_de_Envio__c> direcciones = [
                    SELECT Id
                    FROM ATV_NTS_Direccion_de_Envio__c
                    WHERE Id = :selectedAddressId
                    AND Account__c = :quote.AccountId
                    LIMIT 1
                ];
                if (direcciones.isEmpty()) {
                    throw new AuraHandledException('La direccion seleccionada no pertenece a la cuenta de la Quote.');
                }
            }

            Quote q1 = new Quote(Id = quoteId);
            q1.BillingStreet = String.isNotBlank(street) ? street : null;
            q1.BillingCity = String.isNotBlank(city) ? city : null;
            q1.BillingState = String.isNotBlank(state) ? state : null;
            q1.BillingPostalCode = String.isNotBlank(postalCode) ? postalCode : null;
            q1.BillingCountry = String.isNotBlank(country) ? country : null;
            q1.ATV_Selected_Billing_Address__c = selectedAddressId;
            update q1;

            return 'SUCCESS';
        } catch (DmlException e) {
            throw new AuraHandledException('Error al actualizar la facturacion de la Quote: ' + e.getMessage());
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException('Error inesperado: ' + e.getMessage());
        }
    }
}
