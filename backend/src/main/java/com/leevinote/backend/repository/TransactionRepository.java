package com.leevinote.backend.repository;

import com.leevinote.backend.entity.Transaction;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import java.time.LocalDate;
import java.util.List;
import java.util.Optional;

@Repository
public interface TransactionRepository extends JpaRepository<Transaction, Long> {
    List<Transaction> findByUserIdAndIsDeletedFalseOrderByTransactionDateDescCreatedAtDesc(Long userId);
    Page<Transaction> findByUserIdAndIsDeletedFalse(Long userId, Pageable pageable);
    Optional<Transaction> findByIdAndUserIdAndIsDeletedFalse(Long id, Long userId);

    List<Transaction> findByUserIdAndTransactionDateBetweenAndIsDeletedFalseOrderByTransactionDateDescCreatedAtDesc(
            Long userId, LocalDate startDate, LocalDate endDate);
    Page<Transaction> findByUserIdAndTransactionDateBetweenAndIsDeletedFalse(
            Long userId, LocalDate startDate, LocalDate endDate, Pageable pageable);

    @Query("""
        SELECT t.type as type, SUM(t.amount) as total
        FROM Transaction t
        WHERE t.user.id = :userId AND t.isDeleted = false
          AND t.transactionDate BETWEEN :startDate AND :endDate
        GROUP BY t.type
        """)
    List<TypeTotalProjection> sumByTypeBetween(
            @Param("userId") Long userId,
            @Param("startDate") LocalDate startDate,
            @Param("endDate") LocalDate endDate);

    @Query(value = """
        SELECT to_char(transaction_date, 'YYYY-MM-DD') as period,
               type as type,
               SUM(amount) as total
        FROM transactions
        WHERE user_id = :userId AND is_deleted = false
          AND transaction_date BETWEEN :startDate AND :endDate
        GROUP BY period, type
        ORDER BY period DESC
        """, nativeQuery = true)
    List<PeriodTotalProjection> sumByDay(
            @Param("userId") Long userId,
            @Param("startDate") LocalDate startDate,
            @Param("endDate") LocalDate endDate);

    @Query(value = """
        SELECT to_char(transaction_date, 'YYYY-MM') as period,
               type as type,
               SUM(amount) as total
        FROM transactions
        WHERE user_id = :userId AND is_deleted = false
          AND transaction_date BETWEEN :startDate AND :endDate
        GROUP BY period, type
        ORDER BY period DESC
        """, nativeQuery = true)
    List<PeriodTotalProjection> sumByMonth(
            @Param("userId") Long userId,
            @Param("startDate") LocalDate startDate,
            @Param("endDate") LocalDate endDate);

    @Query(value = """
        SELECT to_char(transaction_date, 'YYYY') as period,
               type as type,
               SUM(amount) as total
        FROM transactions
        WHERE user_id = :userId AND is_deleted = false
          AND transaction_date BETWEEN :startDate AND :endDate
        GROUP BY period, type
        ORDER BY period DESC
        """, nativeQuery = true)
    List<PeriodTotalProjection> sumByYear(
            @Param("userId") Long userId,
            @Param("startDate") LocalDate startDate,
            @Param("endDate") LocalDate endDate);

    interface TypeTotalProjection {
        String getType();
        java.math.BigDecimal getTotal();
    }

    interface PeriodTotalProjection {
        String getPeriod();
        String getType();
        java.math.BigDecimal getTotal();
    }
}
