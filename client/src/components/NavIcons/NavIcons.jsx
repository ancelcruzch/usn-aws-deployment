import React, { useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import "./Navicons.css";
import { AiFillHome } from 'react-icons/ai';
import { IoLogOut, IoNotificationsOutline, IoNotifications, IoChatbubbleEllipses } from "react-icons/io5";
import { useDispatch } from "react-redux";
import { logout } from "../../actions/AuthActions";
import { useNotifications } from "../../context/NotificationContext";
import NotificationDropdown from "../Notifications/NotificationDropdown";

const NavIcons = () => {
    const dispatch = useDispatch();
    const navigate = useNavigate();
    const { unreadCount } = useNotifications();
    const [notifOpen, setNotifOpen] = useState(false);

    const handleLogOut = () => {
        dispatch(logout());
        navigate("/auth");
    };

    return (
        <div className="navIcons">
            <Link to="../home" className="nav-btn-icon" title="Inicio">
                <AiFillHome className="unsa-icon" />
            </Link>

            {/* Chat button */}
            <Link to="../chat" className="nav-btn-icon" title="Chat en vivo">
                <IoChatbubbleEllipses className="unsa-icon" />
            </Link>

            {/* Notification Bell */}
            <div className="nav-notif-wrapper">
                <button 
                    className={`nav-btn-icon ${notifOpen ? "nav-btn-active" : ""}`}
                    onClick={() => setNotifOpen((prev) => !prev)}
                    title="Notificaciones"
                >
                    {unreadCount > 0 ? (
                        <IoNotifications className="unsa-icon" />
                    ) : (
                        <IoNotificationsOutline className="unsa-icon" />
                    )}
                    {unreadCount > 0 && (
                        <span className="nav-badge">{unreadCount > 9 ? "9+" : unreadCount}</span>
                    )}
                </button>

                <NotificationDropdown 
                    isOpen={notifOpen} 
                    onClose={() => setNotifOpen(false)} 
                />
            </div>
            
            {/* Logout button */}
            <div className="div_logout" onClick={handleLogOut} title="Cerrar sesión">
                <span className="logout_span">Exit</span>
                <IoLogOut className="unsa-icon" />
            </div>
        </div>
    );
};

export default NavIcons;