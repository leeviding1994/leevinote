package com.leevinote.backend.controller;

import com.leevinote.backend.entity.TransactionCategory;
import com.leevinote.backend.entity.User;
import com.leevinote.backend.repository.UserRepository;
import com.leevinote.backend.service.TransactionCategoryService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/transaction-categories")
@RequiredArgsConstructor
public class TransactionCategoryController {
    private final TransactionCategoryService categoryService;
    private final UserRepository userRepository;

    @GetMapping
    public ResponseEntity<List<TransactionCategory>> getCategories(
            @RequestParam(required = false) String type) {
        Long userId = getCurrentUserId();
        if (type != null && !type.isBlank()) {
            return ResponseEntity.ok(categoryService.getCategoriesByUserAndType(userId, type));
        }
        return ResponseEntity.ok(categoryService.getCategoriesByUser(userId));
    }

    @PostMapping
    public ResponseEntity<TransactionCategory> createCategory(@RequestBody TransactionCategory category) {
        User user = new User();
        user.setId(getCurrentUserId());
        category.setUser(user);
        return ResponseEntity.ok(categoryService.createCategory(category));
    }

    @PutMapping("/{id}")
    public ResponseEntity<TransactionCategory> updateCategory(@PathVariable Long id, @RequestBody TransactionCategory category) {
        Long userId = getCurrentUserId();
        User user = new User();
        user.setId(userId);
        category.setUser(user);
        return ResponseEntity.ok(categoryService.updateCategory(id, category));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<?> deleteCategory(@PathVariable Long id) {
        Long userId = getCurrentUserId();
        categoryService.deleteCategory(userId, id);
        return ResponseEntity.ok(Map.of("message", "Transaction category deleted"));
    }

    private Long getCurrentUserId() {
        String username = SecurityContextHolder.getContext().getAuthentication().getName();
        return userRepository.findByUsername(username)
            .orElseThrow(() -> new RuntimeException("User not found: " + username))
            .getId();
    }
}
