import { LightningElement, wire, api } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import { getRecordNotifyChange } from 'lightning/uiRecordApi';
import getDirecciones from '@salesforce/apex/ATV_QuoteShippingAddressCtrl.getDirecciones';
import updateQuoteShippingAddress from '@salesforce/apex/ATV_QuoteShippingAddressCtrl.updateQuoteShippingAddress';

const QUOTE_FIELDS = ['Quote.AccountId'];

export default class QuoteShippingAddressPicker extends LightningElement {
    @api recordId; // Id de la Quote

    accountId;
    direcciones = [];
    selectedDireccionId;
    isLoading = false;
    wiredDireccionesResult;

    // Obtener AccountId de la Quote
    @wire(getRecord, { recordId: '$recordId', fields: QUOTE_FIELDS })
    wiredQuote({ error, data }) {
        if (data) {
            this.accountId = data.fields.AccountId?.value;
            if (!this.accountId) {
                this.direcciones = [];
            }
        } else if (error) {
            console.error('Error obteniendo Quote:', error);
            this.showToast('Error', 'No se pudo obtener la información de la Quote', 'error');
        }
    }

    // Obtener direcciones de envío relacionadas a la cuenta
    @wire(getDirecciones, { accountId: '$accountId' })
    wiredDirecciones(result) {
        this.wiredDireccionesResult = result;
        if (result.data) {
            this.direcciones = result.data.map((dir) => ({
                label: dir.label,
                value: dir.id,
                street: dir.street,
                city: dir.city,
                localidadName: dir.localidadName,
                state: dir.state,
                postalCode: dir.postalCode,
                country: dir.country
            }));
        } else if (result.error) {
            console.error('Error obteniendo direcciones:', result.error);
            this.direcciones = [];
            if (this.accountId) {
                const errorMessage =
                    result.error?.body?.message ||
                    result.error?.message ||
                    'No se pudieron cargar las direcciones';
                this.showToast('Error', errorMessage, 'error');
            }
        }
    }

    // Cambio en el combo de direcciones
    handleDireccionChange(event) {
        this.selectedDireccionId = event.detail.value;
    }

    // Aplicar la dirección seleccionada a los campos de envío del Quote
    async handleApply() {
        if (!this.selectedDireccionId) {
            this.showToast('Advertencia', 'Seleccioná una dirección antes de aplicar', 'warning');
            return;
        }

        if (!this.accountId) {
            this.showToast('Advertencia', 'Seteá primero la Cuenta en la Quote', 'warning');
            return;
        }

        const direccionSeleccionada = this.direcciones.find(
            (dir) => dir.value === this.selectedDireccionId
        );

        if (!direccionSeleccionada) {
            this.showToast('Error', 'Dirección seleccionada no encontrada', 'error');
            return;
        }

        this.isLoading = true;

        try {
            await updateQuoteShippingAddress({
                quoteId: this.recordId,
                street: direccionSeleccionada.street || null,
                city: direccionSeleccionada.city || null,
                state: direccionSeleccionada.state || null,
                postalCode: direccionSeleccionada.postalCode || null,
                country: direccionSeleccionada.country || null,
                selectedAddressId: this.selectedDireccionId
            });

            getRecordNotifyChange([{ recordId: this.recordId }]);
            await refreshApex(this.wiredDireccionesResult);

            this.showToast(
                'Éxito',
                'Dirección de envío aplicada correctamente en la Quote',
                'success'
            );

            this.selectedDireccionId = null;
            const combo = this.template.querySelector('lightning-combobox');
            if (combo) {
                combo.value = null;
            }
        } catch (error) {
            console.error('Error aplicando dirección:', error);
            console.error('Error completo:', JSON.stringify(error, null, 2));

            let errorMessage = 'No se pudo aplicar la dirección';

            if (error.body) {
                if (error.body.message) {
                    errorMessage = error.body.message;
                } else if (Array.isArray(error.body)) {
                    errorMessage = error.body.map((e) => e.message || e).join(', ');
                } else if (error.body.pageErrors && error.body.pageErrors.length > 0) {
                    errorMessage = error.body.pageErrors[0].message;
                } else if (error.body.fieldErrors) {
                    const fieldErrors = Object.values(error.body.fieldErrors).flat();
                    errorMessage = fieldErrors.map((e) => e.message).join(', ');
                }
            } else if (error.message) {
                errorMessage = error.message;
            }

            this.showToast('Error', errorMessage, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    showToast(title, message, variant) {
        const evt = new ShowToastEvent({
            title,
            message,
            variant
        });
        this.dispatchEvent(evt);
    }

    get direccionOptions() {
        return this.direcciones.map((dir) => ({
            label: dir.label,
            value: dir.value
        }));
    }

    /** Dirección seleccionada para mostrar el detalle con etiqueta "Localidad" */
    get selectedDireccion() {
        if (!this.selectedDireccionId || !this.direcciones.length) return null;
        const dir = this.direcciones.find((d) => d.value === this.selectedDireccionId);
        if (!dir) return null;
        return {
            ...dir,
            localidadDisplay: dir.localidadName || dir.city
        };
    }

    get hasDirecciones() {
        return this.direcciones && this.direcciones.length > 0;
    }

    get hasAccountId() {
        return !!this.accountId;
    }

    get isButtonDisabled() {
        return this.isLoading || !this.selectedDireccionId;
    }
}

