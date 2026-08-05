package com.dentalcare.service;

import com.dentalcare.service.PendingActionService.Pending;
import org.junit.jupiter.api.Test;

import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

class PendingActionServiceTest {

    private final UUID scopeA = UUID.fromString("00000000-0000-0000-0000-0000000000aa");
    private final UUID scopeB = UUID.fromString("00000000-0000-0000-0000-0000000000bb");

    private String register(PendingActionService svc, UUID scope, String summary) throws InterruptedException {
        // piccolo ritardo: garantisce expiresAt distinti → ordine "più recente" deterministico
        Thread.sleep(2);
        return svc.register("TEST", scope, summary, () -> "eseguito: " + summary);
    }

    @Test
    void consumeLatest_singlePending_returnsItAndLeavesNone() throws InterruptedException {
        PendingActionService svc = new PendingActionService();
        register(svc, scopeA, "unica");

        Optional<Pending> latest = svc.consumeLatestForScope(scopeA);

        assertThat(latest).isPresent();
        assertThat(latest.get().summary()).isEqualTo("unica");
        assertThat(svc.countForScope(scopeA)).isZero();
    }

    @Test
    void consumeLatest_manyPending_consumesOnlyMostRecentAndLeavesTheRest() throws InterruptedException {
        PendingActionService svc = new PendingActionService();
        register(svc, scopeA, "prima");
        register(svc, scopeA, "seconda");
        register(svc, scopeA, "terza");   // la più recente

        Optional<Pending> latest = svc.consumeLatestForScope(scopeA);

        assertThat(latest).isPresent();
        assertThat(latest.get().summary()).isEqualTo("terza");
        assertThat(svc.countForScope(scopeA)).isEqualTo(2);  // "prima" e "seconda" restano
    }

    @Test
    void consumeLatest_isScopedPerProvider() throws InterruptedException {
        PendingActionService svc = new PendingActionService();
        register(svc, scopeA, "di A");
        register(svc, scopeB, "di B");

        Optional<Pending> latestA = svc.consumeLatestForScope(scopeA);

        assertThat(latestA).isPresent();
        assertThat(latestA.get().summary()).isEqualTo("di A");
        assertThat(svc.countForScope(scopeB)).isEqualTo(1);   // B non toccato
    }

    @Test
    void consumeLatest_emptyScope_returnsEmpty() {
        PendingActionService svc = new PendingActionService();
        assertThat(svc.consumeLatestForScope(scopeA)).isEmpty();
    }

    @Test
    void explicitCode_consumesExactlyThatOne() throws InterruptedException {
        PendingActionService svc = new PendingActionService();
        String code = register(svc, scopeA, "per codice");
        register(svc, scopeA, "altra");

        Pending byCode = svc.consume(code);

        assertThat(byCode).isNotNull();
        assertThat(byCode.summary()).isEqualTo("per codice");
        assertThat(svc.countForScope(scopeA)).isEqualTo(1);
    }
}
