package com.leevinote.backend.service;

import com.leevinote.backend.entity.Schedule;
import com.leevinote.backend.repository.ScheduleRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import java.util.List;
import java.util.Optional;

@Service
@RequiredArgsConstructor
public class ScheduleService {
    private final ScheduleRepository scheduleRepository;

    public List<Schedule> getSchedulesByUser(Long userId) {
        return scheduleRepository.findByUserIdOrderByStartTimeAsc(userId);
    }

    public Schedule createSchedule(Schedule schedule) {
        return scheduleRepository.save(schedule);
    }

    public Optional<Schedule> getScheduleByIdAndUser(Long id, Long userId) {
        return scheduleRepository.findByIdAndUserId(id, userId);
    }

    public void deleteSchedule(Long id) {
        scheduleRepository.deleteById(id);
    }
}
