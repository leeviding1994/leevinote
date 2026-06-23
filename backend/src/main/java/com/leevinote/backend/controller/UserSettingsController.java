package com.leevinote.backend.controller;

import com.leevinote.backend.entity.UserSettings;
import com.leevinote.backend.security.SecurityContextUtil;
import com.leevinote.backend.service.UserSettingsService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/user-settings")
@RequiredArgsConstructor
public class UserSettingsController {

    private final UserSettingsService userSettingsService;

    @GetMapping
    public ResponseEntity<UserSettings> getSettings() {
        Long userId = SecurityContextUtil.getCurrentUserId();
        if (userId == null) {
            return ResponseEntity.status(401).build();
        }
        return ResponseEntity.ok(userSettingsService.getOrCreateSettings(userId));
    }

    @PutMapping
    public ResponseEntity<UserSettings> updateSettings(@RequestBody UserSettings settings) {
        Long userId = SecurityContextUtil.getCurrentUserId();
        if (userId == null) {
            return ResponseEntity.status(401).build();
        }
        return ResponseEntity.ok(userSettingsService.updateSettings(userId, settings));
    }
}
