import { LightningElement, wire, api } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import { getRecordNotifyChange } from 'lightning/uiRecordApi';
import getDirecciones from '@salesforce/apex/ATV_QuoteBillingAddressCtrl.getDirecciones';
import updateQuoteBillingAddress from '@salesforce/apex/ATV_QuoteBillingAddressCtrl.updateQuoteBillingAddress';

const QUOTE_FIELDS = ['Quote.AccountId'];

export default class QuoteBillingAddressPicker extends LightningElement {
    @api recordId;

    accountId;
    direcciones = [];
    selectedDireccionId;
    isLoading = false;
    wiredDireccionesResult;

    @wire(getRecord, { recordId: '$recordId', fields: QUOTE_FIELDS })
    wiredQuote({ error, data }) {
        if (data) {
            this.accountId = data.fields.AccountId?.value;
            if (!this.accountId) this.direcciones = [];
        } else if (error) {
            this.showToast('Error', 'No se pudo obtener la informacion de la Quote', 'error');
        }
    }

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
            this.direcciones = [];
            if (this.accountId) {
                const errorMessage = result.error?.body?.message || result.error?.message || 'No se pudieron cargar las direcciones';
                this.showToast('Error', errorMessage, 'error');
            }
        }
    }

    handleDireccionChange(event) {
        this.selectedDireccionId = event.detail.value;
    }

    async handleApply() {
        if (!this.selectedDireccionId) {
            this.showToast('Advertencia', 'Selecciona una direccion antes de aplicar', 'warning');
            return;
        }
        if (!this.accountId) {
            this.showToast('Advertencia', 'Setea primero la Cuenta en la Quote', 'warning');
            return;
        }

        const direccionSeleccionada = this.direcciones.find((dir) => dir.value === this.selectedDireccionId);
        if (!direccionSeleccionada) {
            this.showToast('Error', 'Direccion seleccionada no encontrada', 'error');
            return;
        }

        this.isLoading = true;
        try {
            await updateQuoteBillingAddress({
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
            this.showToast('Exito', 'Direccion de facturacion aplicada correctamente en la Quote', 'success');
            this.selectedDireccionId = null;
        } catch (error) {
            const errorMessage = error?.body?.message || error?.message || 'No se pudo aplicar la direccion';
            this.showToast('Error', errorMessage, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    get direccionOptions() {
        return this.direcciones.map((dir) => ({ label: dir.label, value: dir.value }));
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
