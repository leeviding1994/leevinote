package com.leevinote.backend.repository;

import com.leevinote.backend.entity.Note;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.List;
import java.util.Optional;

@Repository
public interface NoteRepository extends JpaRepository<Note, Long> {
    List<Note> findByUserIdAndIsDeletedFalseOrderByCreatedAtDesc(Long userId);
    Page<Note> findByUserIdAndIsDeletedFalse(Long userId, Pageable pageable);
    Optional<Note> findByIdAndUserIdAndIsDeletedFalse(Long id, Long userId);
}
