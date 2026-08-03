package com.leevinote.backend.entity;

import jakarta.persistence.*;
import lombok.Data;
import lombok.EqualsAndHashCode;

@Data
@EqualsAndHashCode(callSuper = true)
@Entity
@Table(name = "user_settings")
public class UserSettings extends BaseEntity {

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id", nullable = false, unique = true)
    private User user;

    @Column(name = "theme_mode")
    private String themeMode = "system";

    @Column(name = "theme_color")
    private String themeColor = "#2196F3";

    @Column(name = "module_order", length = 500)
    private String moduleOrder = "notes,alarms,music,videos,schedules,transactions,health,profile";

    @Column(name = "module_visibility", length = 1000)
    private String moduleVisibility =
            "notes:true,alarms:true,music:true,videos:true,schedules:true,transactions:true,health:true,profile:true";
}
