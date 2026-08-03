package com.leevinote.backend.service;

import com.leevinote.backend.entity.Video;
import com.leevinote.backend.repository.VideoRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import java.util.List;
import java.util.Optional;

@Service
@RequiredArgsConstructor
public class VideoService {
    private final VideoRepository videoRepository;

    public List<Video> getVideosByUser(Long userId) {
        return videoRepository.findByUserIdOrderByCreatedAtDesc(userId);
    }

    public Video createVideo(Video video) {
        return videoRepository.save(video);
    }

    public Optional<Video> updateVideo(Long id, Long userId, Video updated) {
        return videoRepository.findByIdAndUserId(id, userId)
                .map(video -> {
                    video.setTitle(updated.getTitle());
                    video.setDescription(updated.getDescription());
                    video.setFileUrl(updated.getFileUrl());
                    video.setDuration(updated.getDuration());
                    return videoRepository.save(video);
                });
    }

    public boolean deleteVideo(Long id, Long userId) {
        return videoRepository.findByIdAndUserId(id, userId)
                .map(video -> {
                    videoRepository.delete(video);
                    return true;
                })
                .orElse(false);
    }
}
