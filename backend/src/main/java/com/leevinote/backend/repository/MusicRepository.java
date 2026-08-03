package com.leevinote.backend.repository;

import com.leevinote.backend.entity.Music;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.List;
import java.util.Optional;

@Repository
public interface MusicRepository extends JpaRepository<Music, Long> {
    List<Music> findByUserIdOrderByCreatedAtDesc(Long userId);
    Optional<Music> findByIdAndUserId(Long id, Long userId);
}
