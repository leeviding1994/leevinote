package com.leevinote.backend.entity;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.*;
import lombok.Data;
import lombok.EqualsAndHashCode;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

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

    @ElementCollection(fetch = FetchType.EAGER)
    @CollectionTable(name = "alarm_week_days", joinColumns = @JoinColumn(name = "alarm_id"))
    @Column(name = "week_day")
    private List<Integer> weekDays = new ArrayList<>();

    @JsonIgnore
    @ManyToOne
    @JoinColumn(name = "user_id", nullable = false)
    private User user;
}
