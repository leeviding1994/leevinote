package com.leevinote.backend.controller;

import com.leevinote.backend.entity.Music;
import com.leevinote.backend.entity.User;
import com.leevinote.backend.security.SecurityContextUtil;
import com.leevinote.backend.service.MusicService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/music")
@RequiredArgsConstructor
public class MusicController {
    private final MusicService musicService;

    @GetMapping
    public ResponseEntity<List<Music>> getMusic() {
        Long userId = SecurityContextUtil.getCurrentUserId();
        if (userId == null) return ResponseEntity.status(401).build();
        return ResponseEntity.ok(musicService.getMusicByUser(userId));
    }

    @PostMapping
    public ResponseEntity<Music> createMusic(@RequestBody Music music) {
        Long userId = SecurityContextUtil.getCurrentUserId();
        if (userId == null) return ResponseEntity.status(401).build();
        User user = new User();
        user.setId(userId);
        music.setUser(user);
        return ResponseEntity.ok(musicService.createMusic(music));
    }

    @PutMapping("/{id}")
    public ResponseEntity<Music> updateMusic(@PathVariable Long id, @RequestBody Music music) {
        Long userId = SecurityContextUtil.getCurrentUserId();
        if (userId == null) return ResponseEntity.status(401).build();
        return musicService.updateMusic(id, userId, music)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<?> deleteMusic(@PathVariable Long id) {
        Long userId = SecurityContextUtil.getCurrentUserId();
        if (userId == null) return ResponseEntity.status(401).build();
        if (!musicService.deleteMusic(id, userId)) {
            return ResponseEntity.notFound().build();
        }
        return ResponseEntity.ok(Map.of("message", "Music deleted"));
    }
}
