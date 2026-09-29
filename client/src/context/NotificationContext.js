import React, { createContext, useContext, useState, useEffect, useRef, useCallback } from "react";
import { useSelector } from "react-redux";
import { getNotifications, markNotificationsRead, deleteNotification as deleteNotifApi } from "../api/NotificationRequests";
import { format } from "timeago.js";

const NotificationContext = createContext();

export const NotificationProvider = ({ children }) => {
  const user = useSelector((state) => state.authReducer.authData);
  const [notifications, setNotifications] = useState([]);
  const [toasts, setToasts] = useState([]);
  const isFirstLoad = useRef(true);

  const showToast = useCallback((message, type = "success") => {
    const id = Date.now() + Math.random();
    setToasts((prev) => [...prev, { id, message, type }]);

    setTimeout(() => {
      setToasts((prev) => prev.filter((t) => t.id !== id));
    }, 4500);
  }, []);

  const fetchNotifications = useCallback(async () => {
    if (!user || !user.id) return;
    try {
      const response = await getNotifications(user.id);
      if (response && Array.isArray(response.data)) {
        const mapped = response.data.map((item) => ({
          id: item.id,
          type: item.type ? item.type.toLowerCase() : "info",
          title: item.senderName ? item.senderName : "Notificación",
          desc: item.message,
          time: item.createdAt ? format(item.createdAt) : "Ahora",
          read: item.read !== undefined ? item.read : item.isRead,
        }));

        setNotifications((prev) => {
          if (!isFirstLoad.current) {
            const prevIds = new Set(prev.map((p) => p.id));
            const brandNew = mapped.filter((m) => !prevIds.has(m.id) && !m.read);
            brandNew.forEach((n) => {
              showToast(`${n.title} ${n.desc}`, n.type);
            });
          } else {
            isFirstLoad.current = false;
          }
          return mapped;
        });
      }
    } catch (e) {
      // Backend polling error or no notifications yet
    }
  }, [user, showToast]);

  // Initial fetch and polling every 6 seconds for real-time updates
  useEffect(() => {
    isFirstLoad.current = true;
    fetchNotifications();

    const interval = setInterval(() => {
      fetchNotifications();
    }, 6000);

    return () => clearInterval(interval);
  }, [fetchNotifications]);

  const unreadCount = notifications.filter((n) => !n.read).length;

  const markAllAsRead = async () => {
    setNotifications((prev) => prev.map((n) => ({ ...n, read: true })));
    if (user && user.id) {
      try {
        await markNotificationsRead(user.id);
      } catch (e) {
        console.error("Error marking notifications as read", e);
      }
    }
  };

  const removeNotification = async (id) => {
    setNotifications((prev) => prev.filter((n) => n.id !== id));
    try {
      await deleteNotifApi(id);
    } catch (e) {
      console.error("Error deleting notification", e);
    }
  };

  const clearAllNotifications = () => {
    notifications.forEach((n) => {
      deleteNotifApi(n.id).catch(() => {});
    });
    setNotifications([]);
  };

  const addNotification = ({ type = "info", title, desc }) => {
    showToast(title, type);
  };

  return (
    <NotificationContext.Provider
      value={{
        notifications,
        unreadCount,
        toasts,
        addNotification,
        showToast,
        markAllAsRead,
        removeNotification,
        clearAllNotifications,
        refreshNotifications: fetchNotifications,
      }}
    >
      {children}
    </NotificationContext.Provider>
  );
};

export const useNotifications = () => {
  const context = useContext(NotificationContext);
  if (!context) {
    throw new Error("useNotifications must be used within a NotificationProvider");
  }
  return context;
};
