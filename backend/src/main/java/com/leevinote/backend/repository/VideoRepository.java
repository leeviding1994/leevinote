package com.leevinote.backend.repository;

import com.leevinote.backend.entity.Video;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.List;
import java.util.Optional;

@Repository
public interface VideoRepository extends JpaRepository<Video, Long> {
    List<Video> findByUserIdOrderByCreatedAtDesc(Long userId);
    Optional<Video> findByIdAndUserId(Long id, Long userId);
}
