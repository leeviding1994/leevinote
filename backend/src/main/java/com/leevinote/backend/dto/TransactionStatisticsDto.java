package com.leevinote.backend.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;
import java.math.BigDecimal;
import java.util.List;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class TransactionStatisticsDto {
    private BigDecimal totalIncome;
    private BigDecimal totalExpense;
    private BigDecimal balance;
    private List<PeriodStatisticsDto> periods;

    @Data
    @NoArgsConstructor
    @AllArgsConstructor
    public static class PeriodStatisticsDto {
        private String period;
        private BigDecimal income;
        private BigDecimal expense;
        private BigDecimal balance;
    }
}
