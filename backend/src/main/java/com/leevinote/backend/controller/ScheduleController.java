package com.leevinote.backend.controller;

import com.leevinote.backend.entity.Schedule;
import com.leevinote.backend.service.ScheduleService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import java.util.List;
import java.util.Optional;

@RestController
@RequestMapping("/api/schedules")
@RequiredArgsConstructor
public class ScheduleController {
    private final ScheduleService scheduleService;

    @GetMapping
    public ResponseEntity<List<Schedule>> getSchedules() {
        Long userId = 1L; // TODO: 从SecurityContext获取
        return ResponseEntity.ok(scheduleService.getSchedulesByUser(userId));
    }

    @PostMapping
    public ResponseEntity<Schedule> createSchedule(@RequestBody Schedule schedule) {
        schedule.setUser(new com.leevinote.backend.entity.User() {{ setId(1L); }});
        return ResponseEntity.ok(scheduleService.createSchedule(schedule));
    }

    @GetMapping("/{id}")
    public ResponseEntity<Schedule> getSchedule(@PathVariable Long id) {
        Long userId = 1L; // TODO: 从SecurityContext获取
        Optional<Schedule> schedule = scheduleService.getScheduleByIdAndUser(id, userId);
        return schedule.map(ResponseEntity::ok).orElse(ResponseEntity.notFound().build());
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<?> deleteSchedule(@PathVariable Long id) {
        scheduleService.deleteSchedule(id);
        return ResponseEntity.ok("Schedule deleted");
    }
}
