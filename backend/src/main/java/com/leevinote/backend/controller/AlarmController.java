package com.leevinote.backend.controller;

import com.leevinote.backend.entity.Alarm;
import com.leevinote.backend.entity.User;
import com.leevinote.backend.security.SecurityContextUtil;
import com.leevinote.backend.service.AlarmService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/alarms")
@RequiredArgsConstructor
public class AlarmController {
    private final AlarmService alarmService;

    @GetMapping
    public ResponseEntity<List<Alarm>> getAlarms() {
        Long userId = SecurityContextUtil.getCurrentUserId();
        if (userId == null) return ResponseEntity.status(401).build();
        return ResponseEntity.ok(alarmService.getAlarmsByUser(userId));
    }

    @PostMapping
    public ResponseEntity<Alarm> createAlarm(@RequestBody Alarm alarm) {
        Long userId = SecurityContextUtil.getCurrentUserId();
        if (userId == null) return ResponseEntity.status(401).build();
        User user = new User();
        user.setId(userId);
        alarm.setUser(user);
        return ResponseEntity.ok(alarmService.createAlarm(alarm));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<?> deleteAlarm(@PathVariable Long id) {
        Long userId = SecurityContextUtil.getCurrentUserId();
        if (userId == null) return ResponseEntity.status(401).build();
        if (!alarmService.deleteAlarm(id, userId)) {
            return ResponseEntity.notFound().build();
        }
        return ResponseEntity.ok(Map.of("message", "Alarm deleted"));
    }
}
