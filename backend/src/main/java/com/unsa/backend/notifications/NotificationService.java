package com.unsa.backend.notifications;

import java.util.List;
import org.springframework.stereotype.Service;
import lombok.RequiredArgsConstructor;

@Service
@RequiredArgsConstructor
public class NotificationService {

    private final NotificationRepository notificationRepository;

    public List<NotificationModel> getUserNotifications(Long recipientId) {
        return notificationRepository.findByRecipientIdOrderByCreatedAtDesc(recipientId);
    }

    public NotificationModel createNotification(Long recipientId, Long senderId, String senderName, String type, String message) {
        if (recipientId == null || senderId == null) {
            return null;
        }
        // Do not notify yourself
        if (recipientId.equals(senderId)) {
            return null;
        }
        NotificationModel notification = NotificationModel.builder()
                .recipientId(recipientId)
                .senderId(senderId)
                .senderName(senderName)
                .type(type)
                .message(message)
                .isRead(false)
                .build();
        return notificationRepository.save(notification);
    }

    public void markAllAsRead(Long recipientId) {
        List<NotificationModel> notifs = notificationRepository.findByRecipientIdOrderByCreatedAtDesc(recipientId);
        for (NotificationModel n : notifs) {
            n.setRead(true);
        }
        notificationRepository.saveAll(notifs);
    }

    public void deleteNotification(Long id) {
        notificationRepository.deleteById(id);
    }
}
