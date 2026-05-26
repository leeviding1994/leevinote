package com.leevinote.backend.controller;

import com.leevinote.backend.entity.Note;
import com.leevinote.backend.entity.User;
import com.leevinote.backend.repository.UserRepository;
import com.leevinote.backend.service.NoteService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/notes")
@RequiredArgsConstructor
public class NoteController {
    private final NoteService noteService;
    private final UserRepository userRepository;

    @GetMapping
    public ResponseEntity<List<Note>> getNotes() {
        Long userId = getCurrentUserId();
        return ResponseEntity.ok(noteService.getNotesByUser(userId));
    }

    @PostMapping
    public ResponseEntity<Note> createNote(@RequestBody Note note) {
        User user = new User();
        user.setId(getCurrentUserId());
        note.setUser(user);
        return ResponseEntity.ok(noteService.createNote(note));
    }

    @PutMapping("/{id}")
    public ResponseEntity<Note> updateNote(@PathVariable Long id, @RequestBody Note note) {
        return ResponseEntity.ok(noteService.updateNote(id, note));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<?> deleteNote(@PathVariable Long id) {
        noteService.deleteNote(id);
        return ResponseEntity.ok(Map.of("message", "Note deleted"));
    }

    private Long getCurrentUserId() {
        String username = SecurityContextHolder.getContext().getAuthentication().getName();
        return userRepository.findByUsername(username)
            .orElseThrow(() -> new RuntimeException("User not found: " + username))
            .getId();
    }
}
