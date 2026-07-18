package com.leevinote.backend.repository;

import com.leevinote.backend.entity.TransactionCategory;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.List;
import java.util.Optional;

@Repository
public interface TransactionCategoryRepository extends JpaRepository<TransactionCategory, Long> {
    List<TransactionCategory> findByUserIdAndTypeAndIsDeletedFalseOrderByCreatedAtAsc(Long userId, String type);

    List<TransactionCategory> findByUserIdAndIsDeletedFalseOrderByTypeAscCreatedAtAsc(Long userId);

    Optional<TransactionCategory> findByIdAndUserIdAndIsDeletedFalse(Long id, Long userId);
}
