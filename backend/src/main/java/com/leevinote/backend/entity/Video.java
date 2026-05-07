package com.leevinote.backend.entity;

import jakarta.persistence.*;
import lombok.Data;
import lombok.EqualsAndHashCode;

@Data
@EqualsAndHashCode(callSuper = true)
@Entity
@Table(name = "videos")
public class Video extends BaseEntity {
    @Column(nullable = false)
    private String title;

    private String description;

    @Column(nullable = false)
    private String fileUrl;

    private Long duration;

    @ManyToOne
    @JoinColumn(name = "user_id", nullable = false)
    private User user;
}
