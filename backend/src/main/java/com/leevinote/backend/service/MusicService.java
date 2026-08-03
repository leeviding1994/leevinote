package com.leevinote.backend.service;

import com.leevinote.backend.entity.Music;
import com.leevinote.backend.repository.MusicRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import java.util.List;
import java.util.Optional;

@Service
@RequiredArgsConstructor
public class MusicService {
    private final MusicRepository musicRepository;

    public List<Music> getMusicByUser(Long userId) {
        return musicRepository.findByUserIdOrderByCreatedAtDesc(userId);
    }

    public Music createMusic(Music music) {
        return musicRepository.save(music);
    }

    public Optional<Music> updateMusic(Long id, Long userId, Music updated) {
        return musicRepository.findByIdAndUserId(id, userId)
                .map(music -> {
                    music.setTitle(updated.getTitle());
                    music.setArtist(updated.getArtist());
                    music.setAlbum(updated.getAlbum());
                    music.setFileUrl(updated.getFileUrl());
                    music.setDuration(updated.getDuration());
                    return musicRepository.save(music);
                });
    }

    public boolean deleteMusic(Long id, Long userId) {
        return musicRepository.findByIdAndUserId(id, userId)
                .map(music -> {
                    musicRepository.delete(music);
                    return true;
                })
                .orElse(false);
    }
}
