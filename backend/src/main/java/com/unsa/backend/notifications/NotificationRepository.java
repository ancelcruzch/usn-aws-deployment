package com.unsa.backend.notifications;

import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface NotificationRepository extends JpaRepository<NotificationModel, Long> {
    List<NotificationModel> findByRecipientIdOrderByCreatedAtDesc(Long recipientId);
}
