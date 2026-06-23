package com.leevinote.backend.service;

import com.leevinote.backend.entity.UserSettings;
import com.leevinote.backend.repository.UserSettingsRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

import java.util.Optional;

@Service
@RequiredArgsConstructor
public class UserSettingsService {

    private final UserSettingsRepository userSettingsRepository;

    public UserSettings getOrCreateSettings(Long userId) {
        Optional<UserSettings> optional = userSettingsRepository.findByUserId(userId);
        if (optional.isPresent()) {
            return optional.get();
        }
        UserSettings settings = new UserSettings();
        com.leevinote.backend.entity.User user = new com.leevinote.backend.entity.User();
        user.setId(userId);
        settings.setUser(user);
        return userSettingsRepository.save(settings);
    }

    public UserSettings updateSettings(Long userId, UserSettings newSettings) {
        UserSettings settings = getOrCreateSettings(userId);
        if (newSettings.getThemeMode() != null) {
            settings.setThemeMode(newSettings.getThemeMode());
        }
        if (newSettings.getThemeColor() != null) {
            settings.setThemeColor(newSettings.getThemeColor());
        }
        if (newSettings.getModuleOrder() != null) {
            settings.setModuleOrder(newSettings.getModuleOrder());
        }
        return userSettingsRepository.save(settings);
    }
}
