package com.leevinote.backend.service;

import com.leevinote.backend.entity.Alarm;
import com.leevinote.backend.repository.AlarmRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import java.util.List;

@Service
@RequiredArgsConstructor
public class AlarmService {
    private final AlarmRepository alarmRepository;

    public List<Alarm> getAlarmsByUser(Long userId) {
        return alarmRepository.findByUserIdOrderByAlarmTimeAsc(userId);
    }

    public Alarm createAlarm(Alarm alarm) {
        return alarmRepository.save(alarm);
    }

    public void deleteAlarm(Long id) {
        alarmRepository.deleteById(id);
    }
}
