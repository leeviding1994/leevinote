package com.leevinote.backend.service;

import com.leevinote.backend.dto.TransactionStatisticsDto;
import com.leevinote.backend.entity.Transaction;
import com.leevinote.backend.repository.TransactionRepository;
import com.leevinote.backend.repository.TransactionRepository.PeriodTotalProjection;
import com.leevinote.backend.repository.TransactionRepository.TypeTotalProjection;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class TransactionService {
    private final TransactionRepository transactionRepository;

    public List<Transaction> getTransactionsByUser(Long userId) {
        return transactionRepository.findByUserIdAndIsDeletedFalseOrderByTransactionDateDescCreatedAtDesc(userId);
    }

    public Page<Transaction> getTransactionsByUser(Long userId, Pageable pageable) {
        return transactionRepository.findByUserIdAndIsDeletedFalse(userId, pageable);
    }

    public List<Transaction> getTransactionsByUserAndDateRange(Long userId, LocalDate startDate, LocalDate endDate) {
        return transactionRepository.findByUserIdAndTransactionDateBetweenAndIsDeletedFalseOrderByTransactionDateDescCreatedAtDesc(
                userId, startDate, endDate);
    }

    public Page<Transaction> getTransactionsByUserAndDateRange(Long userId, LocalDate startDate, LocalDate endDate, Pageable pageable) {
        return transactionRepository.findByUserIdAndTransactionDateBetweenAndIsDeletedFalse(
                userId, startDate, endDate, pageable);
    }

    public Transaction createTransaction(Transaction transaction) {
        return transactionRepository.save(transaction);
    }

    public Transaction updateTransaction(Long userId, Long id, Transaction updated) {
        Transaction transaction = transactionRepository.findByIdAndUserIdAndIsDeletedFalse(id, userId)
            .orElseThrow(() -> new RuntimeException("Transaction not found: " + id));
        transaction.setType(updated.getType());
        transaction.setAmount(updated.getAmount());
        transaction.setTransactionDate(updated.getTransactionDate());
        transaction.setCategoryId(updated.getCategoryId());
        transaction.setNote(updated.getNote());
        return transactionRepository.save(transaction);
    }

    public void deleteTransaction(Long userId, Long id) {
        Transaction transaction = transactionRepository.findByIdAndUserIdAndIsDeletedFalse(id, userId)
            .orElseThrow(() -> new RuntimeException("Transaction not found: " + id));
        transaction.setIsDeleted(true);
        transactionRepository.save(transaction);
    }

    public TransactionStatisticsDto getStatistics(Long userId, LocalDate startDate, LocalDate endDate, String groupBy) {
        List<TypeTotalProjection> typeTotals = transactionRepository.sumByTypeBetween(userId, startDate, endDate);
        BigDecimal totalIncome = BigDecimal.ZERO;
        BigDecimal totalExpense = BigDecimal.ZERO;
        for (TypeTotalProjection t : typeTotals) {
            BigDecimal value = t.getTotal() != null ? t.getTotal() : BigDecimal.ZERO;
            if ("income".equalsIgnoreCase(t.getType())) {
                totalIncome = totalIncome.add(value);
            } else if ("expense".equalsIgnoreCase(t.getType())) {
                totalExpense = totalExpense.add(value);
            }
        }
        BigDecimal balance = totalIncome.subtract(totalExpense);

        List<PeriodTotalProjection> periodProjections;
        if ("month".equalsIgnoreCase(groupBy)) {
            periodProjections = transactionRepository.sumByMonth(userId, startDate, endDate);
        } else if ("year".equalsIgnoreCase(groupBy)) {
            periodProjections = transactionRepository.sumByYear(userId, startDate, endDate);
        } else {
            periodProjections = transactionRepository.sumByDay(userId, startDate, endDate);
        }

        Map<String, TransactionStatisticsDto.PeriodStatisticsDto> periodMap = new HashMap<>();
        for (PeriodTotalProjection p : periodProjections) {
            String period = p.getPeriod();
            BigDecimal value = p.getTotal() != null ? p.getTotal() : BigDecimal.ZERO;
            TransactionStatisticsDto.PeriodStatisticsDto dto = periodMap.computeIfAbsent(
                period,
                k -> new TransactionStatisticsDto.PeriodStatisticsDto(period, BigDecimal.ZERO, BigDecimal.ZERO, BigDecimal.ZERO)
            );
            if ("income".equalsIgnoreCase(p.getType())) {
                dto.setIncome(dto.getIncome().add(value));
            } else if ("expense".equalsIgnoreCase(p.getType())) {
                dto.setExpense(dto.getExpense().add(value));
            }
            dto.setBalance(dto.getIncome().subtract(dto.getExpense()));
        }

        List<TransactionStatisticsDto.PeriodStatisticsDto> periods = new ArrayList<>(periodMap.values());
        periods.sort((a, b) -> b.getPeriod().compareTo(a.getPeriod()));

        return new TransactionStatisticsDto(totalIncome, totalExpense, balance, periods);
    }
}
