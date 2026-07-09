package com.leevinote.backend.service;

import com.leevinote.backend.entity.TransactionCategory;
import com.leevinote.backend.repository.TransactionCategoryRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import java.util.List;

@Service
@RequiredArgsConstructor
public class TransactionCategoryService {
    private final TransactionCategoryRepository categoryRepository;

    public List<TransactionCategory> getCategoriesByUser(Long userId) {
        return categoryRepository.findByUserIdAndIsDeletedFalseOrderByTypeAscCreatedAtAsc(userId);
    }

    public List<TransactionCategory> getCategoriesByUserAndType(Long userId, String type) {
        return categoryRepository.findByUserIdAndTypeAndIsDeletedFalseOrderByCreatedAtAsc(userId, type);
    }

    public TransactionCategory createCategory(TransactionCategory category) {
        return categoryRepository.save(category);
    }

    public TransactionCategory updateCategory(Long id, TransactionCategory updated) {
        TransactionCategory category = categoryRepository.findById(id)
            .orElseThrow(() -> new RuntimeException("Transaction category not found: " + id));
        if (updated.getUser() != null && !updated.getUser().getId().equals(category.getUser().getId())) {
            throw new RuntimeException("Transaction category does not belong to current user");
        }
        category.setType(updated.getType());
        category.setName(updated.getName());
        category.setIcon(updated.getIcon());
        category.setColor(updated.getColor());
        return categoryRepository.save(category);
    }

    public void deleteCategory(Long userId, Long id) {
        TransactionCategory category = categoryRepository.findById(id)
            .orElseThrow(() -> new RuntimeException("Transaction category not found: " + id));
        if (!category.getUser().getId().equals(userId)) {
            throw new RuntimeException("Transaction category does not belong to current user");
        }
        category.setIsDeleted(true);
        categoryRepository.save(category);
    }
}
