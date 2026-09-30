import axios from "axios";

const API = axios.create({ baseURL: process.env.REACT_APP_API_URL || "http://localhost:5000" });

API.interceptors.request.use((req) => {
    if (localStorage.getItem('profile')) {
      req.headers.Authorization = `Bearer ${JSON.parse(localStorage.getItem('profile')).token}`;
    }
    req.credentials = 'include'; 
    return req;
});

export const getNotifications = (userId) => API.get(`/notifications/${userId}`);
export const markNotificationsRead = (userId) => API.put(`/notifications/${userId}/read`);
export const deleteNotification = (id) => API.delete(`/notifications/${id}`);
