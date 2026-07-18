package com.leevinote.backend.service;

import com.leevinote.backend.entity.Schedule;
import com.leevinote.backend.repository.ScheduleRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
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

    public Page<Schedule> getSchedulesByUser(Long userId, Pageable pageable) {
        return scheduleRepository.findByUserId(userId, pageable);
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

    public Optional<Schedule> updateSchedule(Long id, Long userId, Schedule updatedSchedule) {
        Optional<Schedule> optional = scheduleRepository.findByIdAndUserId(id, userId);
        if (optional.isPresent()) {
            Schedule schedule = optional.get();
            schedule.setTitle(updatedSchedule.getTitle());
            schedule.setDescription(updatedSchedule.getDescription());
            schedule.setStartTime(updatedSchedule.getStartTime());
            schedule.setEndTime(updatedSchedule.getEndTime());
            schedule.setLocation(updatedSchedule.getLocation());
            if (updatedSchedule.getCompleted() != null) {
                schedule.setCompleted(updatedSchedule.getCompleted());
            }
            return Optional.of(scheduleRepository.save(schedule));
        }
        return Optional.empty();
    }

    public Optional<Schedule> toggleCompleted(Long id, Long userId) {
        Optional<Schedule> optional = scheduleRepository.findByIdAndUserId(id, userId);
        if (optional.isPresent()) {
            Schedule schedule = optional.get();
            schedule.setCompleted(Boolean.TRUE.equals(schedule.getCompleted()) ? false : true);
            return Optional.of(scheduleRepository.save(schedule));
        }
        return Optional.empty();
    }
}
