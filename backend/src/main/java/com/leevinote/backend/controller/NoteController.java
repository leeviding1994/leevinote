package com.leevinote.backend.controller;

import com.leevinote.backend.entity.Note;
import com.leevinote.backend.entity.User;
import com.leevinote.backend.repository.UserRepository;
import com.leevinote.backend.service.NoteService;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.web.PageableDefault;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;
import java.util.Map;

@RestController
@RequestMapping("/notes")
@RequiredArgsConstructor
public class NoteController {
    private final NoteService noteService;
    private final UserRepository userRepository;

    @GetMapping
    public ResponseEntity<Page<Note>> getNotes(
            @PageableDefault(size = 50, sort = "createdAt", direction = Sort.Direction.DESC) Pageable pageable) {
        Long userId = getCurrentUserId();
        return ResponseEntity.ok(noteService.getNotesByUser(userId, pageable));
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
        return ResponseEntity.ok(noteService.updateNote(getCurrentUserId(), id, note));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<?> deleteNote(@PathVariable Long id) {
        noteService.deleteNote(getCurrentUserId(), id);
        return ResponseEntity.ok(Map.of("message", "Note deleted"));
    }

    private Long getCurrentUserId() {
        String username = SecurityContextHolder.getContext().getAuthentication().getName();
        return userRepository.findByUsername(username)
            .orElseThrow(() -> new RuntimeException("User not found: " + username))
            .getId();
    }
}
