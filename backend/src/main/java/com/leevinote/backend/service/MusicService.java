package com.leevinote.backend.service;

import com.leevinote.backend.entity.Music;
import com.leevinote.backend.repository.MusicRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import java.util.List;

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

    public void deleteMusic(Long id) {
        musicRepository.deleteById(id);
    }
}
