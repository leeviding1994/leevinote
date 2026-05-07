package com.leevinote.backend.entity;

import jakarta.persistence.*;
import lombok.Data;
import lombok.EqualsAndHashCode;
import java.time.LocalDateTime;

@Data
@EqualsAndHashCode(callSuper = true)
@Entity
@Table(name = "alarms")
public class Alarm extends BaseEntity {
    @Column(nullable = false)
    private String title;

    private String description;

    @Column(nullable = false)
    private LocalDateTime alarmTime;

    private Boolean enabled = true;

    private String repeatPattern;

    @ManyToOne
    @JoinColumn(name = "user_id", nullable = false)
    private User user;
}
