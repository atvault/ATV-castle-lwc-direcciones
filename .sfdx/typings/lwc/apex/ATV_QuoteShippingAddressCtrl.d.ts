declare module "@salesforce/apex/ATV_QuoteShippingAddressCtrl.getDirecciones" {
  export default function getDirecciones(param: {accountId: any}): Promise<any>;
}
declare module "@salesforce/apex/ATV_QuoteShippingAddressCtrl.getLocalidades" {
  export default function getLocalidades(param: {searchTerm: any}): Promise<any>;
}
declare module "@salesforce/apex/ATV_QuoteShippingAddressCtrl.getProvincias" {
  export default function getProvincias(): Promise<any>;
}
declare module "@salesforce/apex/ATV_QuoteShippingAddressCtrl.updateQuoteShippingAddress" {
  export default function updateQuoteShippingAddress(param: {quoteId: any, street: any, city: any, state: any, postalCode: any, country: any, selectedAddressId: any}): Promise<any>;
}
declare module "@salesforce/apex/ATV_QuoteShippingAddressCtrl.updateQuoteShippingWithLocalidad" {
  export default function updateQuoteShippingWithLocalidad(param: {quoteId: any, street: any, city: any, state: any, postalCode: any, country: any, selectedAddressId: any, localidadId: any, provinciaValue: any}): Promise<any>;
}
