package com.leevinote.backend.service;

import com.leevinote.backend.entity.Note;
import com.leevinote.backend.repository.NoteRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import java.util.List;

@Service
@RequiredArgsConstructor
public class NoteService {
    private final NoteRepository noteRepository;

    public List<Note> getNotesByUser(Long userId) {
        return noteRepository.findByUserIdAndIsDeletedFalseOrderByCreatedAtDesc(userId);
    }

    public Page<Note> getNotesByUser(Long userId, Pageable pageable) {
        return noteRepository.findByUserIdAndIsDeletedFalse(userId, pageable);
    }

    public Note createNote(Note note) {
        return noteRepository.save(note);
    }

    public Note updateNote(Long userId, Long id, Note updated) {
        Note note = noteRepository.findByIdAndUserIdAndIsDeletedFalse(id, userId)
            .orElseThrow(() -> new RuntimeException("Note not found: " + id));
        note.setTitle(updated.getTitle());
        note.setContent(updated.getContent());
        note.setCategory(updated.getCategory());
        note.setFolderId(updated.getFolderId());
        return noteRepository.save(note);
    }

    public void deleteNote(Long userId, Long id) {
        Note note = noteRepository.findByIdAndUserIdAndIsDeletedFalse(id, userId)
            .orElseThrow(() -> new RuntimeException("Note not found: " + id));
        note.setIsDeleted(true);
        noteRepository.save(note);
    }
}
