package com.leevinote.backend.entity;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.*;
import lombok.Data;
import lombok.EqualsAndHashCode;

@Data
@EqualsAndHashCode(callSuper = true)
@Entity
@Table(name = "music")
public class Music extends BaseEntity {
    @Column(nullable = false)
    private String title;

    private String artist;

    private String album;

    @Column(nullable = false)
    private String fileUrl;

    private Long duration;

    @JsonIgnore
    @ManyToOne
    @JoinColumn(name = "user_id", nullable = false)
    private User user;
}
