import React, { useRef, useEffect } from "react";
import "./NotificationDropdown.css";
import { useNotifications } from "../../context/NotificationContext";
import { 
  IoNotifications, 
  IoHeart, 
  IoPersonAdd, 
  IoSparkles, 
  IoTrashOutline,
  IoCheckmarkDone 
} from "react-icons/io5";

const getNotificationIcon = (type) => {
  switch (type) {
    case "like":
      return <div className="notif-badge-icon badge-like"><IoHeart /></div>;
    case "follow":
      return <div className="notif-badge-icon badge-follow"><IoPersonAdd /></div>;
    case "welcome":
      return <div className="notif-badge-icon badge-welcome"><IoSparkles /></div>;
    default:
      return <div className="notif-badge-icon badge-default"><IoNotifications /></div>;
  }
};

const NotificationDropdown = ({ isOpen, onClose }) => {
  const dropdownRef = useRef(null);
  const { 
    notifications, 
    unreadCount, 
    markAllAsRead, 
    removeNotification, 
    clearAllNotifications 
  } = useNotifications();

  // Close when clicking outside
  useEffect(() => {
    const handleClickOutside = (event) => {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target)) {
        onClose();
      }
    };
    if (isOpen) {
      document.addEventListener("mousedown", handleClickOutside);
    }
    return () => {
      document.removeEventListener("mousedown", handleClickOutside);
    };
  }, [isOpen, onClose]);

  if (!isOpen) return null;

  return (
    <div className="notification-dropdown" ref={dropdownRef}>
      <div className="notif-header">
        <div className="notif-title-row">
          <h4>Notificaciones</h4>
          {unreadCount > 0 && <span className="notif-pill">{unreadCount} nuevas</span>}
        </div>
        <div className="notif-actions">
          {unreadCount > 0 && (
            <button className="notif-action-btn" onClick={markAllAsRead} title="Marcar como leídas">
              <IoCheckmarkDone /> Marcar leídas
            </button>
          )}
          {notifications.length > 0 && (
            <button className="notif-action-btn notif-clear-btn" onClick={clearAllNotifications} title="Limpiar todas">
              <IoTrashOutline />
            </button>
          )}
        </div>
      </div>

      <div className="notif-list">
        {notifications.length === 0 ? (
          <div className="notif-empty">
            <IoNotifications className="notif-empty-icon" />
            <p>No tienes notificaciones por el momento</p>
          </div>
        ) : (
          notifications.map((notif) => (
            <div 
              key={notif.id} 
              className={`notif-item ${!notif.read ? "notif-unread" : ""}`}
            >
              {getNotificationIcon(notif.type)}
              <div className="notif-content">
                <span className="notif-item-title">{notif.title}</span>
                <p className="notif-item-desc">{notif.desc}</p>
                <span className="notif-time">{notif.time}</span>
              </div>
              <button 
                className="notif-item-remove"
                onClick={() => removeNotification(notif.id)}
                title="Eliminar notificación"
              >
                ×
              </button>
            </div>
          ))
        )}
      </div>
    </div>
  );
};

export default NotificationDropdown;
