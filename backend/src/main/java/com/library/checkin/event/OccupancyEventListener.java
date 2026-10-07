package com.library.checkin.event;

import com.library.checkin.dto.OccupancyChange;
import com.library.checkin.dto.OccupancyEvent;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

import java.time.OffsetDateTime;
import java.util.UUID;

@Slf4j
@Component
@RequiredArgsConstructor
public class OccupancyEventListener {

    private final SimpMessagingTemplate messagingTemplate;

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void onOccupancyChanged(OccupancyChangedEvent event) {
        OccupancyEvent message = new OccupancyEvent(
                UUID.randomUUID(),
                event.occurredAt() != null ? event.occurredAt() : OffsetDateTime.now(),
                event.occupancy().revision(),
                event.occupancy().count(),
                event.occupancy().maxCapacity(),
                event.occupancy().nearCapacity(),
                new OccupancyChange(event.sessionId(), event.action())
        );

        log.info("Broadcasting occupancy event to /topic/occupancy: count={}, revision={}", message.count(), message.revision());
        messagingTemplate.convertAndSend("/topic/occupancy", message);
    }
}
