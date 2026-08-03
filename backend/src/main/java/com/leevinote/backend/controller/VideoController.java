package com.leevinote.backend.controller;

import com.leevinote.backend.entity.Video;
import com.leevinote.backend.entity.User;
import com.leevinote.backend.security.SecurityContextUtil;
import com.leevinote.backend.service.VideoService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/videos")
@RequiredArgsConstructor
public class VideoController {
    private final VideoService videoService;

    @GetMapping
    public ResponseEntity<List<Video>> getVideos() {
        Long userId = SecurityContextUtil.getCurrentUserId();
        if (userId == null) return ResponseEntity.status(401).build();
        return ResponseEntity.ok(videoService.getVideosByUser(userId));
    }

    @PostMapping
    public ResponseEntity<Video> createVideo(@RequestBody Video video) {
        Long userId = SecurityContextUtil.getCurrentUserId();
        if (userId == null) return ResponseEntity.status(401).build();
        User user = new User();
        user.setId(userId);
        video.setUser(user);
        return ResponseEntity.ok(videoService.createVideo(video));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<?> deleteVideo(@PathVariable Long id) {
        Long userId = SecurityContextUtil.getCurrentUserId();
        if (userId == null) return ResponseEntity.status(401).build();
        if (!videoService.deleteVideo(id, userId)) {
            return ResponseEntity.notFound().build();
        }
        return ResponseEntity.ok(Map.of("message", "Video deleted"));
    }
}
