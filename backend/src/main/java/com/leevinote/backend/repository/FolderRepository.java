package com.leevinote.backend.repository;

import com.leevinote.backend.entity.Folder;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.List;
import java.util.Optional;

@Repository
public interface FolderRepository extends JpaRepository<Folder, Long> {
    List<Folder> findByUserIdOrderByCreatedAtAsc(Long userId);
    Optional<Folder> findByIdAndUserId(Long id, Long userId);
}
