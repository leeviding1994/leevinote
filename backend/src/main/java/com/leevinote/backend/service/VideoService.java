package com.leevinote.backend.service;

import com.leevinote.backend.entity.Video;
import com.leevinote.backend.repository.VideoRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import java.util.List;

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

    public boolean deleteVideo(Long id, Long userId) {
        return videoRepository.findByIdAndUserId(id, userId)
                .map(video -> {
                    videoRepository.delete(video);
                    return true;
                })
                .orElse(false);
    }
}
