package com.leevinote.backend.controller;

import com.leevinote.backend.entity.Note;
import com.leevinote.backend.service.NoteService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;
import java.util.List;

@RestController
@RequestMapping("/api/notes")
@RequiredArgsConstructor
public class NoteController {
    private final NoteService noteService;

    @GetMapping
    public ResponseEntity<List<Note>> getNotes() {
        Long userId = getCurrentUserId();
        return ResponseEntity.ok(noteService.getNotesByUser(userId));
    }

    @PostMapping
    public ResponseEntity<Note> createNote(@RequestBody Note note) {
        note.setUser(new com.leevinote.backend.entity.User() {{ setId(getCurrentUserId()); }});
        return ResponseEntity.ok(noteService.createNote(note));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<?> deleteNote(@PathVariable Long id) {
        noteService.deleteNote(id);
        return ResponseEntity.ok("Note deleted");
    }

    private Long getCurrentUserId() {
        String username = SecurityContextHolder.getContext().getAuthentication().getName();
        return 1L; // TODO: 从数据库查询用户ID
    }
}
