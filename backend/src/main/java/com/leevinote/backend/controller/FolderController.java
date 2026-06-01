package com.leevinote.backend.controller;

import com.leevinote.backend.entity.Folder;
import com.leevinote.backend.repository.UserRepository;
import com.leevinote.backend.service.FolderService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/folders")
@RequiredArgsConstructor
public class FolderController {
    private final FolderService folderService;
    private final UserRepository userRepository;

    @GetMapping
    public ResponseEntity<List<Folder>> getFolders() {
        Long userId = getCurrentUserId();
        return ResponseEntity.ok(folderService.getFoldersByUser(userId));
    }

    @PostMapping
    public ResponseEntity<Folder> createFolder(@RequestBody Folder folder) {
        folder.setUserId(getCurrentUserId());
        return ResponseEntity.ok(folderService.createFolder(folder));
    }

    @PutMapping("/{id}")
    public ResponseEntity<Folder> updateFolder(@PathVariable Long id, @RequestBody Folder folder) {
        return ResponseEntity.ok(folderService.updateFolder(id, folder));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<?> deleteFolder(@PathVariable Long id) {
        folderService.deleteFolder(id);
        return ResponseEntity.ok(Map.of("message", "Folder deleted"));
    }

    private Long getCurrentUserId() {
        String username = SecurityContextHolder.getContext().getAuthentication().getName();
        return userRepository.findByUsername(username)
            .orElseThrow(() -> new RuntimeException("User not found: " + username))
            .getId();
    }
}