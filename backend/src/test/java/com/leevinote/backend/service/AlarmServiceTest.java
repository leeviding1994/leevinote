package com.leevinote.backend.service;

import com.leevinote.backend.entity.Alarm;
import com.leevinote.backend.repository.AlarmRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class AlarmServiceTest {

    @Mock
    private AlarmRepository alarmRepository;

    @InjectMocks
    private AlarmService alarmService;

    @Test
    void deletesAlarmOwnedByCurrentUser() {
        Alarm alarm = new Alarm();
        when(alarmRepository.findByIdAndUserId(10L, 7L)).thenReturn(Optional.of(alarm));

        assertTrue(alarmService.deleteAlarm(10L, 7L));
        verify(alarmRepository).delete(alarm);
    }

    @Test
    void refusesToDeleteAlarmOwnedByAnotherUser() {
        when(alarmRepository.findByIdAndUserId(10L, 7L)).thenReturn(Optional.empty());

        assertFalse(alarmService.deleteAlarm(10L, 7L));
        verify(alarmRepository, never()).delete(org.mockito.ArgumentMatchers.any());
    }
}
