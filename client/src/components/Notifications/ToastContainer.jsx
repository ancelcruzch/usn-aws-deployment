import React from "react";
import "./ToastContainer.css";
import { useNotifications } from "../../context/NotificationContext";
import { IoCheckmarkCircle, IoHeart, IoPersonAdd, IoInformationCircle } from "react-icons/io5";

const getIcon = (type) => {
  switch (type) {
    case "like":
      return <IoHeart className="toast-icon toast-like" />;
    case "follow":
      return <IoPersonAdd className="toast-icon toast-follow" />;
    case "success":
      return <IoCheckmarkCircle className="toast-icon toast-success" />;
    default:
      return <IoInformationCircle className="toast-icon toast-info" />;
  }
};

const ToastContainer = () => {
  const { toasts } = useNotifications();

  if (toasts.length === 0) return null;

  return (
    <div className="toast-container">
      {toasts.map((toast) => (
        <div key={toast.id} className={`toast-card toast-${toast.type}`}>
          {getIcon(toast.type)}
          <span className="toast-message">{toast.message}</span>
        </div>
      ))}
    </div>
  );
};

export default ToastContainer;
