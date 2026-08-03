package com.leevinote.backend.repository;

import com.leevinote.backend.entity.Alarm;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.List;
import java.util.Optional;

@Repository
public interface AlarmRepository extends JpaRepository<Alarm, Long> {
    List<Alarm> findByUserIdOrderByAlarmTimeAsc(Long userId);
    Optional<Alarm> findByIdAndUserId(Long id, Long userId);
}
