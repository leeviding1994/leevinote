package com.leevinote.backend.controller;

import com.leevinote.backend.entity.Schedule;
import com.leevinote.backend.security.SecurityContextUtil;
import com.leevinote.backend.service.ScheduleService;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import java.util.Map;
import java.util.Optional;

@RestController
@RequestMapping("/schedules")
@RequiredArgsConstructor
public class ScheduleController {
    private final ScheduleService scheduleService;

    @GetMapping
    public ResponseEntity<Page<Schedule>> getSchedules(
            @PageableDefault(size = 50, sort = "startTime", direction = Sort.Direction.ASC) Pageable pageable) {
        Long userId = SecurityContextUtil.getCurrentUserId();
        if (userId == null) return ResponseEntity.status(401).build();
        return ResponseEntity.ok(scheduleService.getSchedulesByUser(userId, pageable));
    }

    @PostMapping
    public ResponseEntity<Schedule> createSchedule(@RequestBody Schedule schedule) {
        Long userId = SecurityContextUtil.getCurrentUserId();
        if (userId == null) return ResponseEntity.status(401).build();
        com.leevinote.backend.entity.User user = new com.leevinote.backend.entity.User();
        user.setId(userId);
        schedule.setUser(user);
        return ResponseEntity.ok(scheduleService.createSchedule(schedule));
    }

    @GetMapping("/{id}")
    public ResponseEntity<Schedule> getSchedule(@PathVariable Long id) {
        Long userId = SecurityContextUtil.getCurrentUserId();
        if (userId == null) return ResponseEntity.status(401).build();
        Optional<Schedule> schedule = scheduleService.getScheduleByIdAndUser(id, userId);
        return schedule.map(ResponseEntity::ok).orElse(ResponseEntity.notFound().build());
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<?> deleteSchedule(@PathVariable Long id) {
        Long userId = SecurityContextUtil.getCurrentUserId();
        if (userId == null) return ResponseEntity.status(401).build();
        Optional<Schedule> schedule = scheduleService.getScheduleByIdAndUser(id, userId);
        if (schedule.isEmpty()) return ResponseEntity.notFound().build();
        scheduleService.deleteSchedule(id);
        return ResponseEntity.ok(Map.of("message", "Schedule deleted"));
    }

    @PutMapping("/{id}")
    public ResponseEntity<Schedule> updateSchedule(@PathVariable Long id, @RequestBody Schedule schedule) {
        Long userId = SecurityContextUtil.getCurrentUserId();
        if (userId == null) return ResponseEntity.status(401).build();
        Optional<Schedule> result = scheduleService.updateSchedule(id, userId, schedule);
        return result.map(ResponseEntity::ok).orElse(ResponseEntity.notFound().build());
    }

    @PatchMapping("/{id}/completed")
    public ResponseEntity<Schedule> toggleCompleted(@PathVariable Long id) {
        Long userId = SecurityContextUtil.getCurrentUserId();
        if (userId == null) return ResponseEntity.status(401).build();
        Optional<Schedule> result = scheduleService.toggleCompleted(id, userId);
        return result.map(ResponseEntity::ok).orElse(ResponseEntity.notFound().build());
    }
}
