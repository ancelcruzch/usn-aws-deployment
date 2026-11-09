import React, { useState, useRef } from "react";
import "./PostShare.css";
import {
  UilScenery,
  UilPlayCircle,
  UilLocationPoint,
  UilSchedule,
  UilTimes,
} from "@iconscout/react-unicons";
import { useDispatch, useSelector } from "react-redux";
import { uploadImage, uploadPost } from "../../actions/UploadAction";
import { useNotifications } from "../../context/NotificationContext";
import PropTypes from "prop-types";
import axios from "axios";

const OptionButton = ({ icon, color, onClick, children }) => {
  return (
    <button
      className="option"
      style={{ color, cursor: "pointer" }}
      onClick={onClick}
    >
      {icon}
      {children}
    </button>
  );
};

OptionButton.propTypes = {
  icon: PropTypes.element,
  color: PropTypes.string,
  onClick: PropTypes.func,
  children: PropTypes.node,
};

const PostShare = () => {
  const dispatch = useDispatch();
  const { showToast } = useNotifications();
  const user = useSelector((state) => state.authReducer.authData);
  const loading = useSelector((state) => state.postReducer.uploading);
  const [image, setImage] = useState(null);
  const [aiStatus, setAiStatus] = useState(null);
  const desc = useRef();
  const serverPublic = process.env.REACT_APP_PUBLIC_FOLDER;
  const imageRef = useRef();

  // Verificar si user está definido
  if (!user) {
    return <div>Loading...</div>;
  }

  // handle Image Change
  const onImageChange = (event) => {
    if (event.target.files?.[0]) {
      setImage(event.target.files[0]);
    }
  };

  // Analizar texto en vivo con la IA
  const handleTextChange = async (e) => {
    const text = e.target.value.trim();
    if (!text || text.length < 3) {
      setAiStatus(null);
      return;
    }
    try {
      const aiUrl = process.env.REACT_APP_AI_URL || "http://localhost:8000";
      const { data } = await axios.post(`${aiUrl}/analyze`, {
        text,
        user_id: user.id,
      });
      setAiStatus(data);
    } catch {
      // AI service silencioso si no responde
    }
  };

  // handle post upload
  const handleUpload = async (e) => {
    e.preventDefault();
    const textContent = desc.current.value ? desc.current.value.trim() : "";

    // 🤖 Verificación en tiempo real con el Microservicio de IA
    if (textContent) {
      try {
        const aiUrl = process.env.REACT_APP_AI_URL || "http://localhost:8000";
        const { data: aiResult } = await axios.post(`${aiUrl}/analyze`, {
          text: textContent,
          user_id: user.id,
        });
        setAiStatus(aiResult);

        // Si la IA RECHAZA la publicación por toxicidad u odio:
        if (aiResult.status === "REJECTED") {
          showToast(`🚫 Bloqueado por IA: ${aiResult.moderation_reason}`, "error");
          return; // SE DETIENE LA PUBLICACIÓN
        }

        if (aiResult.status === "FLAGGED") {
          showToast(`⚠️ Advertencia de IA: Sentimiento negativo detectado`, "warning");
        } else {
          showToast(`✨ IA: Sentimiento ${aiResult.sentiment} (${aiResult.sentiment_score > 0 ? "+" : ""}${aiResult.sentiment_score})`, "success");
        }
      } catch (err) {
        console.warn("AI service no disponible:", err);
      }
    }

    const newPost = {
      userId: user.id,
      desc: desc.current.value,
    };
    const formData = new FormData();
    try {
      if (image) {
        const fileName = Date.now() + image.name;
        formData.append("name", fileName);
        formData.append("file", image);
        dispatch(uploadImage(formData))
          .then((response) => {
            newPost.image = response;
            dispatch(uploadPost(newPost));
            showToast("¡Publicación compartida con éxito!", "success");
            resetShare();
          })
          .catch((error) => {
            console.error("Error:", error);
          });
      } else {
        dispatch(uploadPost(newPost));
        showToast("¡Publicación compartida con éxito!", "success");
        resetShare();
      }
    } catch (error) {
      console.error("Error:", error);
    }
  };

  // Reset Post Share
  const resetShare = () => {
    setImage(null);
    setAiStatus(null);
    if (desc.current) desc.current.value = "";
  };
  return (
    <div className="PostShare">
      <img
        src={
          user.profilePicture
            ? serverPublic + user.profilePicture
            : serverPublic + "defaultProfile.png"
        }
        alt="Profile"
      />
      <div>
        <input
          type="text"
          placeholder="¿Qué estás pensando?"
          required
          ref={desc}
          onChange={handleTextChange}
        />
        {aiStatus && (
          <div style={{
            display: "flex",
            alignItems: "center",
            gap: "8px",
            padding: "6px 12px",
            borderRadius: "8px",
            fontSize: "12px",
            fontWeight: "600",
            margin: "6px 0",
            background: aiStatus.status === "REJECTED" ? "rgba(239, 68, 68, 0.15)" : aiStatus.status === "FLAGGED" ? "rgba(245, 158, 11, 0.15)" : "rgba(16, 185, 129, 0.15)",
            color: aiStatus.status === "REJECTED" ? "#b91c1c" : aiStatus.status === "FLAGGED" ? "#b45309" : "#047857",
            border: `1px solid ${aiStatus.status === "REJECTED" ? "#f87171" : aiStatus.status === "FLAGGED" ? "#fbbf24" : "#6ee7b7"}`
          }}>
            <span>🤖 IA Moderación:</span>
            <span>
              {aiStatus.status === "REJECTED"
                ? `🚫 Rechazado (${aiStatus.moderation_reason})`
                : aiStatus.status === "FLAGGED"
                ? `⚠️ Advertencia (Sentimiento negativo)`
                : `✨ Aprobado • Sentimiento ${aiStatus.sentiment} (${aiStatus.sentiment_score > 0 ? "+" : ""}${aiStatus.sentiment_score})`}
            </span>
          </div>
        )}
        <div className="postOptions">
          <OptionButton
            icon={<UilScenery />}
            color="var(--photo)"
            onClick={() => imageRef.current.click()}
          >
            Photo
          </OptionButton>

          <OptionButton icon={<UilPlayCircle />} color="var(--video)">
            Video
          </OptionButton>

          <OptionButton icon={<UilLocationPoint />} color="var(--location)">
            Location
          </OptionButton>

          <OptionButton icon={<UilSchedule />} color="var(--shedule)">
            Schedule
          </OptionButton>
          <button
            className="button ps-button"
            onClick={handleUpload}
            disabled={loading}
          >
            {loading ? "uploading" : "Share"}
          </button>

          <div style={{ display: "none" }}>
            <input type="file" ref={imageRef} onChange={onImageChange} />
          </div>
        </div>

        {image && (
          <div className="previewImage">
            <UilTimes onClick={() => setImage(null)} />
            <img src={URL.createObjectURL(image)} alt="preview" />
          </div>
        )}
      </div>
    </div>
  );
};

export default PostShare;