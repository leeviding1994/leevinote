package com.leevinote.backend.service;

import com.leevinote.backend.entity.Note;
import com.leevinote.backend.repository.NoteRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import java.util.List;

@Service
@RequiredArgsConstructor
public class NoteService {
    private final NoteRepository noteRepository;

    public List<Note> getNotesByUser(Long userId) {
        return noteRepository.findByUserIdOrderByCreatedAtDesc(userId);
    }

    public Note createNote(Note note) {
        return noteRepository.save(note);
    }

    public Note updateNote(Long id, Note updated) {
        Note note = noteRepository.findById(id)
            .orElseThrow(() -> new RuntimeException("Note not found: " + id));
        note.setTitle(updated.getTitle());
        note.setContent(updated.getContent());
        note.setCategory(updated.getCategory());
        return noteRepository.save(note);
    }

    public void deleteNote(Long id) {
        noteRepository.deleteById(id);
    }
}
