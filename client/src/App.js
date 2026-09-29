import "./App.css";
import { Routes, Route, Navigate } from "react-router-dom";
import Home from "./pages/Home";
import Auth from "./pages/Auth/Auth";
import Profile from "./pages/Profile/Profile";
import { useSelector } from "react-redux";
import { NotificationProvider } from "./context/NotificationContext";
import ToastContainer from "./components/Notifications/ToastContainer";

function App() {
  const user = useSelector((state) => state.authReducer.authData);
  return (
    <NotificationProvider>
      <div className="App">
        <div className="blur" style={{ top: "70%", right: "-2rem" }}></div>
        <div className="blur" style={{ top: "20%", left: "-6rem" }}></div>
        <ToastContainer />
        <Routes>
          <Route
            path="/"
            element={user ? <Navigate to="home" /> : <Navigate to="auth" />}
          />
          <Route
            path="/home"
            element={user ? <Home /> : <Navigate to="../auth" />}
          />
          <Route
            path="/auth"
            element={user ? <Navigate to="../home" /> : <Auth />}
          />
          <Route
            path="/profile/:id"
            element={user ? <Profile /> : <Navigate to="../auth" />}
          />
          <Route
            path="*"
            element={
              <main style={{ padding: "1rem" }}>
                <p>There's nothing here!</p>
              </main>
            }
          />
        </Routes>
      </div>
    </NotificationProvider>
  );
}

export default App;
