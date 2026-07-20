package com.dentalcare.service;

import com.dentalcare.dto.EstimateLineDto;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.util.List;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

/**
 * Bug: nel dettaglio di un preventivo, subtotale e totale non si aggiornavano dopo
 * addLine/deleteLine. Causa: subtotal_amount/discount_amount/taxable_amount/vat_amount/
 * total_amount su "estimates" (e line_subtotal/line_taxable/line_vat_amount/line_total su
 * estimate_lines) sono colonne memorizzate pensate per essere allineate da un trigger
 * Postgres (recalc_estimate_totals), non garantito su ogni schema tenant — EstimateService
 * si limitava a leggerle così com'erano, senza mai ricalcolarle.
 * <p>
 * Questi test coprono il ricalcolo puro in Java (recalcLineTotals/sumTotals), ora usato sia
 * da findById (lettura) sia da recalcAndPersistHeaderTotals (scrittura, dentro la stessa
 * transazione di addLine/deleteLine), che sostituisce la dipendenza dal trigger DB.
 */
class EstimateServiceTest {

    @Test
    void recalcLine_nessunoSconto_ricalcolaDaValoriMemorizzatiAZero() {
        // riga come letta dal DB con line_subtotal/line_taxable/line_vat_amount/line_total
        // ancora a 0 (mai calcolati da un trigger) — esattamente lo scenario del bug
        EstimateLineDto stale = line(new BigDecimal("2"), new BigDecimal("50.00"), BigDecimal.ZERO, new BigDecimal("22.00"));

        EstimateLineDto recalculated = EstimateService.recalcLineTotals(List.of(stale)).get(0);

        assertThat(recalculated.lineSubtotal()).isEqualByComparingTo("100.00");
        assertThat(recalculated.lineTaxable()).isEqualByComparingTo("100.00");
        assertThat(recalculated.lineVatAmount()).isEqualByComparingTo("22.00");
        assertThat(recalculated.lineTotal()).isEqualByComparingTo("122.00");
    }

    @Test
    void recalcLine_conSconto_riduceImponibileEIva() {
        EstimateLineDto stale = line(BigDecimal.ONE, new BigDecimal("100.00"), new BigDecimal("10.00"), new BigDecimal("22.00"));

        EstimateLineDto recalculated = EstimateService.recalcLineTotals(List.of(stale)).get(0);

        assertThat(recalculated.lineSubtotal()).isEqualByComparingTo("100.00");
        assertThat(recalculated.lineTaxable()).isEqualByComparingTo("90.00");
        assertThat(recalculated.lineVatAmount()).isEqualByComparingTo("19.80");
        assertThat(recalculated.lineTotal()).isEqualByComparingTo("109.80");
    }

    @Test
    void recalcLine_scontoMaggioreDelLordo_imponibileClampatoAZeroSubtotaleNo() {
        EstimateLineDto stale = line(BigDecimal.ONE, new BigDecimal("50.00"), new BigDecimal("80.00"), new BigDecimal("22.00"));

        EstimateLineDto recalculated = EstimateService.recalcLineTotals(List.of(stale)).get(0);

        assertThat(recalculated.lineSubtotal()).isEqualByComparingTo("50.00"); // lordo: non clampato dallo sconto
        assertThat(recalculated.lineTaxable()).isEqualByComparingTo("0.00");
        assertThat(recalculated.lineVatAmount()).isEqualByComparingTo("0.00");
        assertThat(recalculated.lineTotal()).isEqualByComparingTo("0.00");
    }

    @Test
    void recalcLine_ivaZero_totaleUgualeAImponibile() {
        EstimateLineDto stale = line(BigDecimal.ONE, new BigDecimal("75.50"), BigDecimal.ZERO, BigDecimal.ZERO);

        EstimateLineDto recalculated = EstimateService.recalcLineTotals(List.of(stale)).get(0);

        assertThat(recalculated.lineTaxable()).isEqualByComparingTo("75.50");
        assertThat(recalculated.lineVatAmount()).isEqualByComparingTo("0.00");
        assertThat(recalculated.lineTotal()).isEqualByComparingTo("75.50");
    }

    @Test
    void sumTotals_sommaPiuRigheEUsaLoScontoGrezzoDiRiga() {
        List<EstimateLineDto> lines = EstimateService.recalcLineTotals(List.of(
                line(new BigDecimal("2"), new BigDecimal("50.00"), BigDecimal.ZERO, new BigDecimal("22.00")),
                line(BigDecimal.ONE, new BigDecimal("100.00"), new BigDecimal("10.00"), new BigDecimal("22.00"))
        ));

        EstimateService.EstimateTotals totals = EstimateService.sumTotals(lines);

        assertThat(totals.subtotalAmount()).isEqualByComparingTo("200.00");
        assertThat(totals.discountAmount()).isEqualByComparingTo("10.00");
        assertThat(totals.taxableAmount()).isEqualByComparingTo("190.00");
        assertThat(totals.vatAmount()).isEqualByComparingTo("41.80");
        assertThat(totals.totalAmount()).isEqualByComparingTo("231.80");
    }

    @Test
    void sumTotals_nessunaRiga_tuttiITotaliSonoZero() {
        EstimateService.EstimateTotals totals = EstimateService.sumTotals(List.of());

        assertThat(totals.subtotalAmount()).isEqualByComparingTo("0.00");
        assertThat(totals.discountAmount()).isEqualByComparingTo("0.00");
        assertThat(totals.taxableAmount()).isEqualByComparingTo("0.00");
        assertThat(totals.vatAmount()).isEqualByComparingTo("0.00");
        assertThat(totals.totalAmount()).isEqualByComparingTo("0.00");
    }

    @Test
    void sumTotals_rimozioneDiUnaRiga_ricalcolaSullaRigaRimanente() {
        // simula addLine di 2 righe seguito da deleteLine della prima: il totale deve
        // riflettere solo la riga rimasta, non restare congelato al valore precedente
        List<EstimateLineDto> dopoAggiunta = EstimateService.recalcLineTotals(List.of(
                line(BigDecimal.ONE, new BigDecimal("40.00"), BigDecimal.ZERO, new BigDecimal("22.00")),
                line(BigDecimal.ONE, new BigDecimal("60.00"), BigDecimal.ZERO, new BigDecimal("22.00"))
        ));
        assertThat(EstimateService.sumTotals(dopoAggiunta).totalAmount()).isEqualByComparingTo("122.00");

        List<EstimateLineDto> dopoRimozionePrimaRiga = EstimateService.recalcLineTotals(List.of(dopoAggiunta.get(1)));

        assertThat(EstimateService.sumTotals(dopoRimozionePrimaRiga).totalAmount()).isEqualByComparingTo("73.20");
    }

    /** Riga con quantity/unitPrice/discountAmount/vatRate valorizzati e i 4 campi calcolati
     *  a 0, come letta da una riga DB il cui line_subtotal/line_taxable/line_vat_amount/
     *  line_total non sono mai stati calcolati (bug riprodotto). */
    private static EstimateLineDto line(BigDecimal quantity, BigDecimal unitPrice, BigDecimal discountAmount, BigDecimal vatRate) {
        return new EstimateLineDto(
                UUID.randomUUID(), 10, UUID.randomUUID(), "Prestazione", null,
                "Prestazione", null,
                quantity, unitPrice, discountAmount, vatRate,
                BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO);
    }
}
