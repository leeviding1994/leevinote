package com.leevinote.backend.controller;

import com.leevinote.backend.entity.Music;
import com.leevinote.backend.service.MusicService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import java.util.List;

@RestController
@RequestMapping("/music")
@RequiredArgsConstructor
public class MusicController {
    private final MusicService musicService;

    @GetMapping
    public ResponseEntity<List<Music>> getMusic() {
        Long userId = 1L; // TODO: 从SecurityContext获取
        return ResponseEntity.ok(musicService.getMusicByUser(userId));
    }

    @PostMapping
    public ResponseEntity<Music> createMusic(@RequestBody Music music) {
        com.leevinote.backend.entity.User user = new com.leevinote.backend.entity.User();
        user.setId(1L);
        music.setUser(user);
        return ResponseEntity.ok(musicService.createMusic(music));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<?> deleteMusic(@PathVariable Long id) {
        musicService.deleteMusic(id);
        return ResponseEntity.ok("Music deleted");
    }
}
