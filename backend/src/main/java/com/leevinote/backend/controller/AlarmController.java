package com.leevinote.backend.controller;

import com.leevinote.backend.entity.Alarm;
import com.leevinote.backend.service.AlarmService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import java.util.List;

@RestController
@RequestMapping("/api/alarms")
@RequiredArgsConstructor
public class AlarmController {
    private final AlarmService alarmService;

    @GetMapping
    public ResponseEntity<List<Alarm>> getAlarms() {
        Long userId = 1L; // TODO: 从SecurityContext获取
        return ResponseEntity.ok(alarmService.getAlarmsByUser(userId));
    }

    @PostMapping
    public ResponseEntity<Alarm> createAlarm(@RequestBody Alarm alarm) {
        alarm.setUser(new com.leevinote.backend.entity.User() {{ setId(1L); }});
        return ResponseEntity.ok(alarmService.createAlarm(alarm));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<?> deleteAlarm(@PathVariable Long id) {
        alarmService.deleteAlarm(id);
        return ResponseEntity.ok("Alarm deleted");
    }
}
