const express = require("express");
const http = require("http");
const { Server } = require("socket.io");
const cors = require("cors");

const app = express();
app.use(cors());
app.use(express.json());

const server = http.createServer(app);

const io = new Server(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"],
  },
});

// Health check endpoint for Kubernetes Liveness and Readiness Probes
app.get("/health", (req, res) => {
  res.status(200).json({
    status: "UP",
    service: "socket-server",
    timestamp: new Date().toISOString(),
    activeUsers: activeUsers.length,
  });
});

app.get("/", (req, res) => {
  res.send("Universe Social Network - Socket Service is UP and running");
});

let activeUsers = [];

io.on("connection", (socket) => {
  console.log(`[Socket] Client connected: ${socket.id}`);

  // Register user and broadcast online list
  socket.on("new-user-add", (newUserId) => {
    if (!newUserId) return;
    const existingIndex = activeUsers.findIndex((u) => u.userId === newUserId);
    if (existingIndex !== -1) {
      activeUsers[existingIndex].socketId = socket.id;
    } else {
      activeUsers.push({ userId: newUserId, socketId: socket.id });
    }
    console.log(`[Socket] User registered: ${newUserId}. Total online: ${activeUsers.length}`);
    io.emit("get-users", activeUsers);
  });

  // Handle real-time chat messages
  socket.on("send-message", (data) => {
    const { receiverId } = data;
    const user = activeUsers.find((u) => u.userId === receiverId);
    console.log(`[Socket] Routing message to receiver: ${receiverId}`);
    if (user) {
      io.to(user.socketId).emit("recieve-message", data);
    }
  });

  // Handle real-time notifications
  socket.on("send-notification", (data) => {
    const { receiverId } = data;
    const user = activeUsers.find((u) => u.userId === receiverId);
    console.log(`[Socket] Routing notification to receiver: ${receiverId}`);
    if (user) {
      io.to(user.socketId).emit("recieve-notification", data);
    }
  });

  // Disconnection cleanup
  socket.on("disconnect", () => {
    activeUsers = activeUsers.filter((u) => u.socketId !== socket.id);
    console.log(`[Socket] Disconnected: ${socket.id}. Remaining: ${activeUsers.length}`);
    io.emit("get-users", activeUsers);
  });
});

const PORT = process.env.PORT || 8800;
server.listen(PORT, "0.0.0.0", () => {
  console.log(`🚀 Socket Service running on port ${PORT}`);
});
