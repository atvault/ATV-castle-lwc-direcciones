# ATV Quote Shipping — Selector de dirección de envío

Proyecto Salesforce DX que agrega a la **Quote** (Cotización) un componente Lightning para elegir una dirección de envío de la cuenta y aplicarla a los campos estándar de envío del Quote (Ship To). La **ciudad** se obtiene del objeto **Localidad** relacionado cuando la dirección tiene una localidad asociada.

---

## Tabla de contenidos

1. [Descripción general](#descripción-general)
2. [Requisitos](#requisitos)
3. [Estructura del proyecto](#estructura-del-proyecto)
4. [Configuración inicial](#configuración-inicial)
5. [Objetos y campos involucrados](#objetos-y-campos-involucrados)
6. [Flujo de uso](#flujo-de-uso)
7. [Despliegue](#despliegue)
8. [Manual técnico](#manual-técnico)
9. [Scripts disponibles](#scripts-disponibles)
10. [Configuración en el org (Dirección de envío)](#configuración-en-el-org-dirección-de-envío)
11. [Solución de problemas](#solución-de-problemas)

---

## Descripción general

- **Objetivo:** En la página de registro de Quote (Lightning), mostrar un listado de direcciones de envío asociadas a la **Cuenta** de la Quote. El usuario elige una y, al hacer clic en **Aplicar**, se copian calle, ciudad, estado/provincia, código postal y país a los campos de envío del Quote (Ship To) y se guarda el lookup a la dirección seleccionada.
- **Ciudad:** La ciudad que se escribe en el Quote (Ship To City) se toma del **registro de Localidad** (`ATV_NTS_Localidades__c`) vinculado a la dirección (`ATV_NTS_Localidad__r.Name`). Si la dirección no tiene localidad, se usa el campo ciudad de la dirección.
- **UI:** El componente muestra el detalle de la dirección seleccionada con la etiqueta **"Localidad"** (en lugar de "Shipping City") cuando el valor viene del lookup a Localidad.
- **Stack:** Salesforce DX (SFDX), Apex (with sharing), LWC, API 64.0.

---

## Requisitos

- **Salesforce CLI** (`sf`) instalado y en PATH.
- **Node.js** (para scripts npm y herramientas de desarrollo).
- Acceso a un org con:
  - Objeto estándar **Quote**.
  - Objeto custom **ATV_NTS_Direccion_de_Envio__c** (direcciones por cuenta).
  - Objeto custom **ATV_NTS_Localidades__c** (catálogo de localidades).
  - Campo custom en Quote: **ATV_Selected_Shipping_Address__c** (lookup a `ATV_NTS_Direccion_de_Envio__c`).

---

## Estructura del proyecto

```
atv-quote-shipping/
├── config/
│   └── deploy-tests.txt          # Lista de tests para deploy a producción
├── force-app/main/default/
│   ├── classes/
│   │   ├── ATV_QuoteShippingAddressCtrl.cls      # Controller Apex
│   │   ├── ATV_QuoteShippingAddressCtrl.cls-meta.xml
│   │   ├── ATV_QuoteShippingAddressCtrlTest.cls  # Tests Apex
│   │   └── ATV_QuoteShippingAddressCtrlTest.cls-meta.xml
│   ├── lwc/
│   │   └── quoteShippingAddressPicker/
│   │       ├── quoteShippingAddressPicker.html
│   │       ├── quoteShippingAddressPicker.js
│   │       └── quoteShippingAddressPicker.js-meta.xml
│   └── objects/
│       ├── ATV_NTS_Direccion_de_Envio__c/       # Campos Localidad/Provincia
│       ├── ATV_NTS_Localidades__c/               # Objeto Localidades
│       └── Quote/
│           └── fields/
│               └── ATV_Selected_Shipping_Address__c.field-meta.xml
├── package.json
├── sfdx-project.json
└── README.md
```

---

## Configuración inicial

1. **Clonar / abrir el proyecto**
   ```bash
   cd atv-quote-shipping
   ```

2. **Instalar dependencias (opcional, para lint y tests LWC)**
   ```bash
   npm install
   ```

3. **Autenticación al org**
   - Producción (ej. Castle):
     ```bash
     sf org login web --alias castle-global-prod --instance-url https://login.salesforce.com
     ```
   - Sandbox:
     ```bash
     sf org login web --alias celigoatv --instance-url https://test.salesforce.com
     ```

4. **Definir org por defecto**
   ```bash
   sf config set target-org=castle-global-prod
   ```
   o el alias que uses.

5. **Verificar conexión**
   ```bash
   sf org display --target-org castle-global-prod
   ```

---

## Objetos y campos involucrados

### Quote (estándar)

| Campo | Tipo | Uso |
|-------|------|-----|
| AccountId | Lookup | Filtra direcciones por cuenta. |
| ShippingStreet | Text | Se actualiza al aplicar. |
| ShippingCity | Text | Se actualiza; valor desde **Localidad** cuando existe. |
| ShippingState | Text | Se actualiza al aplicar. |
| ShippingPostalCode | Text | Se actualiza al aplicar. |
| ShippingCountry | Text | Se actualiza al aplicar. |
| ATV_Selected_Shipping_Address__c | Lookup (custom) | Apunta a la dirección de envío elegida. |

### ATV_NTS_Direccion_de_Envio__c (custom)

Direcciones de envío por cuenta. Campos relevantes:

- **Account__c** – Cuenta.
- **NTS_fld_ShippingStreet__c**, **NTS_fld_ShippingCity__c**, **NTS_fld_ShippingState__c**, **ATV_fld_ShippingPostalCode__c**, **NTS_fld_ShippingCountry__c** – Dirección.
- **ATV_NTS_Localidad__c** – Lookup a `ATV_NTS_Localidades__c`. Su **Name** se usa como ciudad en el Quote cuando está informado.
- **ATV_NTS_Provincia__c** – Picklist (ej. Buenos Aires, Capital Federal).
- **Estado_o_Provincia__c** – Fallback para estado/provincia.

### ATV_NTS_Localidades__c (custom)

Catálogo de localidades (más de 10k registros). Se usa **Name** para rellenar **Ship To City** cuando la dirección tiene `ATV_NTS_Localidad__c` asignado.

---

## Flujo de uso

1. El usuario abre una **Quote** que ya tiene **Cuenta** asignada.
2. En la página de registro (sidebar) aparece el componente **Dirección de Envío**.
3. Si no hay cuenta, se muestra: *"Seteá primero la Cuenta en la Quote"*.
4. Si hay cuenta, se cargan las **direcciones disponibles** de esa cuenta (hasta 200).
5. El usuario elige una en el desplegable **"Direcciones disponibles de la cuenta"**.
6. Clic en **Aplicar**.
7. Se actualizan en el Quote:
   - **Ship To Street, City, State/Province, Zip/Postal Code, Country**
   - **Direccion de envío seleccionada** (lookup).
8. La **ciudad** del Quote se toma del nombre de la **Localidad** (`ATV_NTS_Localidad__r.Name`) cuando la dirección tiene localidad; si no, del campo ciudad de la dirección.

---

## Despliegue

### Sandbox

```bash
sf project deploy start --target-org celigoatv
```

(Si el org exige tests, podés usar `--test-level RunSpecifiedTests --tests ATV_QuoteShippingAddressCtrlTest`.)

### Producción (Castle)

Se usa solo la clase de test necesaria para cumplir cobertura:

```bash
npm run deploy:prod
```

Equivale a:

```bash
sf project deploy start --target-org castle-global-prod --test-level RunSpecifiedTests --tests ATV_QuoteShippingAddressCtrlTest
```

La lista de tests usados en producción está en `config/deploy-tests.txt`.

### Agregar el componente a la página de Quote

1. **Setup → Lightning App Builder**.
2. Editar la **Quote Record Page** (o la página que uses para Quote).
3. Arrastrar **Quote Shipping Address Picker** (o el nombre con el que figure) al sidebar.
4. Guardar y activar.

---

## Manual técnico

### Arquitectura

- **Frontend:** LWC `quoteShippingAddressPicker` en la página de registro de Quote.
- **Backend:** Clase Apex `ATV_QuoteShippingAddressCtrl` (with sharing).
- **Datos:** Direcciones en `ATV_NTS_Direccion_de_Envio__c` filtradas por `Account__c`; ciudad desde `ATV_NTS_Localidades__c` vía `ATV_NTS_Localidad__r.Name`.

### API Apex (ATV_QuoteShippingAddressCtrl)

#### getDirecciones(Id accountId)

- **Tipo:** `@AuraEnabled(cacheable=true)`
- **Parámetros:** `accountId` – Id de la cuenta de la Quote.
- **Retorno:** `List<DireccionDTO>`
- **Comportamiento:** Consulta hasta 200 direcciones de `ATV_NTS_Direccion_de_Envio__c` con `Account__c = accountId`. Incluye `ATV_NTS_Localidad__r.Name`. La propiedad `city` del DTO se arma desde la Localidad cuando existe; si no, desde `NTS_fld_ShippingCity__c`.

**DireccionDTO:**

| Propiedad | Tipo | Descripción |
|-----------|------|-------------|
| id | Id | Id del registro de dirección. |
| label | String | Etiqueta para el combobox (nombre, calle, ciudad, etc.). |
| street | String | Calle. |
| city | String | Ciudad (desde Localidad o campo ciudad). |
| localidadName | String | Nombre de la Localidad (`ATV_NTS_Localidad__r.Name`); null si no hay lookup. Se usa en la UI con etiqueta "Localidad". |
| state | String | Estado/Provincia. |
| postalCode | String | Código postal. |
| country | String | País. |
| localidadId | Id | Id de ATV_NTS_Localidades__c (si existe). |
| provinciaValue | String | Valor del picklist Provincia. |

#### updateQuoteShippingAddress(quoteId, street, city, state, postalCode, country, selectedAddressId)

- **Tipo:** `@AuraEnabled`
- **Uso:** Firma de 7 parámetros para compatibilidad (tests y LWC). Delega en `updateQuoteShippingWithLocalidad` con `localidadId` y `provinciaValue` en null.
- **Comportamiento:** Actualiza en el Quote: ShippingStreet, ShippingCity, ShippingState, ShippingPostalCode, ShippingCountry y `ATV_Selected_Shipping_Address__c`. Valida que la dirección pertenezca a la cuenta de la Quote.

#### updateQuoteShippingWithLocalidad(...)

- Método completo con 9 parámetros (incluye `localidadId` y `provinciaValue`). Usado internamente; el LWC actual solo usa la firma de 7 parámetros.

#### getLocalidades(String searchTerm)

- **Tipo:** `@AuraEnabled(cacheable=false)`
- **Uso:** Búsqueda por nombre en `ATV_NTS_Localidades__c` (SOQL dinámico, LIKE, límite 50). No lo usa el LWC actual del selector de dirección; queda disponible para otros usos.

#### getProvincias()

- **Tipo:** `@AuraEnabled(cacheable=true)`
- **Retorno:** Valores del picklist `ATV_NTS_Provincia__c` de Dirección de envío. Tampoco lo usa el LWC actual del selector.

### LWC quoteShippingAddressPicker

- **Contexto:** `lightning__RecordPage` en objeto **Quote** (`recordId` = Id de la Quote).
- **Datos:**
  - `getRecord` para `Quote.AccountId`.
  - `getDirecciones` con `accountId` reactivo para cargar el listado.
- **UI:**
  - Mensaje si no hay cuenta.
  - Mensaje si hay cuenta pero no hay direcciones.
  - Combobox con direcciones y botón **Aplicar**.
  - Detalle de la dirección seleccionada (Calle, **Localidad**, Estado o Provincia, Código postal, País) con etiqueta "Localidad" para el valor que viene del lookup.
  - Spinner durante la llamada a Apex.
- **Aplicar:** Llama a `updateQuoteShippingAddress` con los datos de la dirección seleccionada (street, city, state, postalCode, country, selectedAddressId). Luego `getRecordNotifyChange` y `refreshApex` para refrescar la vista.

### Seguridad y permisos

- Clase Apex: `with sharing`. Los datos visibles dependen de permisos del usuario sobre Quote, Account y `ATV_NTS_Direccion_de_Envio__c`.
- En el controller se valida que la dirección seleccionada pertenezca a la cuenta de la Quote antes de actualizar.
- El lookup `ATV_Selected_Shipping_Address__c` tiene lookup filter por `QuoteAccountId` (isOptional: true para evitar errores cuando QuoteAccountId es null).

### Tests Apex

- **Clase:** `ATV_QuoteShippingAddressCtrlTest`
- **Cobertura:** getDirecciones (null, con datos, fallback estado), updateQuoteShippingAddress (éxito, dirección inválida, strings en blanco para limpiar, DmlException), getLocalidades, getProvincias, updateQuoteShippingWithLocalidad (validación provincia sin dirección, con dirección y provincia).
- En deploy a producción se ejecuta solo esta clase: `RunSpecifiedTests --tests ATV_QuoteShippingAddressCtrlTest`.

---

## Scripts disponibles

| Comando | Descripción |
|---------|-------------|
| `npm run deploy:prod` | Deploy a producción (castle-global-prod) con tests especificados. |
| `npm run deploy:prod:shipping` | Deploy solo de la feature de envío (manifest separado). |
| `npm run lint` | Ejecuta ESLint en Aura/LWC. |
| `npm run test` | Tests unitarios LWC (Jest). |
| `npm run test:unit:coverage` | Tests LWC con cobertura. |
| `npm run prettier` | Formatea código con Prettier. |
| `npm run prettier:verify` | Verifica formato sin escribir. |

---

## Configuración en el org (Dirección de envío)

Para que en el org se vea **Localidad** en lugar de "Shipping City" y solo los campos deseados:

### Lista relacionada "Direcciones de envío (1)" (card en la página de Cuenta/Quote)

La tarjeta usa el **Compact Layout** del objeto. Para mostrar "Localidad" en vez de "Shipping City":

1. **Setup → Object Manager → Dirección de envío → Compact Layouts**.
2. Editar el layout que esté asignado como principal (o crear uno nuevo).
3. Incluir el campo **Localidad** (`ATV_NTS_Localidad__c`) y quitar **Shipping City** (`NTS_fld_ShippingCity__c`) si no lo querés en la card.
4. Si creaste un layout nuevo, en **Object Manager → Dirección de envío → Object settings** (o en el metadata del objeto) asignar ese compact layout como principal.

### Formulario New / Edit "Dirección de envío"

Los campos del formulario los define el **Page Layout**:

1. **Setup → Object Manager → Dirección de envío → Page Layouts**.
2. Editar el layout que use el perfil o record type correspondiente.
3. **Agregar** el campo **Localidad** a la sección que quieras.
4. **Quitar o reordenar** campos (por ejemplo "Shipping City") para dejar solo los que necesitás: ej. Dirección de envío, Account, Localidad, Shipping Street, Estado o Provincia, Shipping Postal Code, Shipping Country, etc.
5. Guardar.

Así la página "New Dirección de envío" y la edición muestran solo los campos configurados en ese layout.

---

## Solución de problemas

### "Seteá primero la Cuenta en la Quote"

- La Quote no tiene **Cuenta** asignada. Asignar cuenta y recargar; el componente cargará las direcciones de esa cuenta.

### No aparecen direcciones en el combo

- Verificar que existan registros de `ATV_NTS_Direccion_de_Envio__c` con `Account__c` = cuenta de la Quote.
- Revisar permisos del usuario sobre el objeto y campos.
- Revisar la pestaña Red/Consola del navegador por errores en `getDirecciones`.

### Ship To City queda vacío

- La dirección elegida debe tener **Localidad** (`ATV_NTS_Localidad__c`) asignada. Si no tiene, se usa el campo ciudad de la dirección (`NTS_fld_ShippingCity__c`). Comprobar en el registro de la dirección que exista el lookup a Localidad y que el registro de Localidad tenga **Name** informado.

### Error al aplicar (lookup / filtro)

- El lookup `ATV_Selected_Shipping_Address__c` tiene filtro por `QuoteAccountId`. Si falla por filtro, en metadata el filtro está como opcional (`isOptional: true`). Si persiste, revisar que la dirección pertenezca a la misma cuenta que la Quote.

### Deploy a producción falla por tests

- Ejecutar solo la clase requerida: `npm run deploy:prod` (usa `ATV_QuoteShippingAddressCtrlTest`).
- Si se agregan métodos o clases Apex, puede ser necesario incluir más tests en `config/deploy-tests.txt` y en el script `deploy:prod` del `package.json`.

### Puerto OAuth en uso

- En `sfdx-project.json` está configurado `oauthLocalPort: 1718`. Si usás otro puerto en `sf org login web`, podés cambiarlo ahí o usar la variable de entorno correspondiente.

---

## Resumen de archivos clave

| Archivo | Rol |
|---------|-----|
| `force-app/main/default/classes/ATV_QuoteShippingAddressCtrl.cls` | Lógica de negocio y API para direcciones y actualización del Quote. |
| `force-app/main/default/classes/ATV_QuoteShippingAddressCtrlTest.cls` | Tests Apex para controller y cobertura en deploy. |
| `force-app/main/default/lwc/quoteShippingAddressPicker/*` | Componente Lightning (HTML, JS, meta.xml). |
| `force-app/main/default/objects/Quote/fields/ATV_Selected_Shipping_Address__c.field-meta.xml` | Lookup en Quote a la dirección seleccionada. |
| `config/deploy-tests.txt` | Lista de tests usados en deploy a producción. |
| `package.json` (script `deploy:prod`) | Comando de deploy a producción con tests especificados. |
| `sfdx-project.json` | Configuración del proyecto DX y API version. |

---

*Documentación generada para el proyecto ATV Quote Shipping. Para dudas sobre el org o permisos, contactar al equipo de Salesforce/AT Vault.*
