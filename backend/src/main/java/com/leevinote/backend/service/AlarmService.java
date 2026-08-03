package com.leevinote.backend.service;

import com.leevinote.backend.entity.Alarm;
import com.leevinote.backend.repository.AlarmRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import java.util.List;
import java.util.Optional;

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

    public Optional<Alarm> updateAlarm(Long id, Long userId, Alarm updated) {
        return alarmRepository.findByIdAndUserId(id, userId)
                .map(alarm -> {
                    alarm.setTitle(updated.getTitle());
                    alarm.setDescription(updated.getDescription());
                    alarm.setAlarmTime(updated.getAlarmTime());
                    alarm.setEnabled(updated.getEnabled());
                    alarm.setRepeatPattern(updated.getRepeatPattern());
                    alarm.setWeekDays(updated.getWeekDays());
                    return alarmRepository.save(alarm);
                });
    }

    public boolean deleteAlarm(Long id, Long userId) {
        return alarmRepository.findByIdAndUserId(id, userId)
                .map(alarm -> {
                    alarmRepository.delete(alarm);
                    return true;
                })
                .orElse(false);
    }
}
