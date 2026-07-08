package com.leevinote.backend.entity;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.*;
import lombok.Data;
import lombok.EqualsAndHashCode;

@Data
@EqualsAndHashCode(callSuper = true)
@Entity
@Table(name = "transaction_categories")
public class TransactionCategory extends BaseEntity {
    @Column(nullable = false, length = 16)
    private String type; // expense / income

    @Column(nullable = false)
    private String name;

    private String icon;

    private String color;

    @JsonIgnore
    @ManyToOne
    @JoinColumn(name = "user_id", nullable = false)
    private User user;

    @Column(name = "is_deleted", nullable = false)
    private Boolean isDeleted = false;
}
