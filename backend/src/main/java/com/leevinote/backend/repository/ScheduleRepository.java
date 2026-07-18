package com.leevinote.backend.repository;

import com.leevinote.backend.entity.Schedule;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.List;
import java.util.Optional;

@Repository
public interface ScheduleRepository extends JpaRepository<Schedule, Long> {
    List<Schedule> findByUserIdOrderByStartTimeAsc(Long userId);
    Page<Schedule> findByUserId(Long userId, Pageable pageable);
    Optional<Schedule> findByIdAndUserId(Long id, Long userId);
}
