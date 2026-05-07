package com.leevinote.backend.controller;

import com.leevinote.backend.entity.Video;
import com.leevinote.backend.service.VideoService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import java.util.List;

@RestController
@RequestMapping("/api/videos")
@RequiredArgsConstructor
public class VideoController {
    private final VideoService videoService;

    @GetMapping
    public ResponseEntity<List<Video>> getVideos() {
        Long userId = 1L; // TODO: 从SecurityContext获取
        return ResponseEntity.ok(videoService.getVideosByUser(userId));
    }

    @PostMapping
    public ResponseEntity<Video> createVideo(@RequestBody Video video) {
        video.setUser(new com.leevinote.backend.entity.User() {{ setId(1L); }});
        return ResponseEntity.ok(videoService.createVideo(video));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<?> deleteVideo(@PathVariable Long id) {
        videoService.deleteVideo(id);
        return ResponseEntity.ok("Video deleted");
    }
}
