from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from typing import List, Optional
from datetime import datetime
import re

app = FastAPI(
    title="USN AI Content Moderation & Sentiment Service",
    description="Microservicio de Inteligencia Artificial para análisis de sentimiento y moderación de contenido en la red social.",
    version="1.0.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Diccionarios léxicos para análisis de sentimiento en español e inglés
POSITIVE_WORDS = {
    "bueno", "excelente", "genial", "increible", "amor", "feliz", "alegria", "maravilloso",
    "exito", "perfecto", "hermoso", "lindo", "fantastico", "brillante", "amigos", "fiesta",
    "good", "great", "awesome", "love", "happy", "joy", "wonderful", "perfect", "beautiful"
}

NEGATIVE_WORDS = {
    "malo", "pesimo", "horrible", "triste", "odio", "dolor", "fracaso", "feo", "decepcion",
    "terrible", "peor", "asco", "enojo", "rabia", "molesto",
    "bad", "terrible", "awful", "sad", "hate", "pain", "failure", "ugly", "angry"
}

TOXIC_WORDS = {
    "idiota", "estupido", "imbecil", "maldito", "inutil", "basura", "muerete", "racista",
    "estupidez", "mierda", "estafa", "odio", "matar",
    "stupid", "idiot", "kill", "scam", "trash"
}

stats = {
    "total_analyzed": 0,
    "approved": 0,
    "flagged": 0,
    "rejected": 0
}

class PostAnalysisRequest(BaseModel):
    text: str = Field(..., example="¡Excelente día para compartir con la comunidad de Universe!")
    user_id: Optional[int] = Field(None, example=1)
    post_id: Optional[int] = Field(None, example=101)

class PostAnalysisResponse(BaseModel):
    status: str  # APPROVED, FLAGGED, REJECTED
    sentiment: str  # POSITIVE, NEUTRAL, NEGATIVE
    sentiment_score: float  # -1.0 a +1.0
    is_toxic: bool
    confidence: float
    detected_tags: List[str]
    moderation_reason: Optional[str] = None
    analyzed_at: str

@app.get("/health")
def health_check():
    """Endpoint de salud para Liveness y Readiness Probes de Kubernetes."""
    return {
        "status": "UP",
        "service": "usn-ai-service",
        "timestamp": datetime.utcnow().isoformat(),
        "stats": stats
    }

@app.get("/")
def root():
    return {
        "message": "Universe Social Network — AI Moderation & Sentiment Service is UP",
        "version": "1.0.0",
        "endpoints": {
            "health": "/health",
            "analyze": "/analyze",
            "stats": "/stats"
        }
    }

@app.post("/analyze", response_model=PostAnalysisResponse)
def analyze_content(request: PostAnalysisRequest):
    """Analiza una publicación para determinar sentimiento y moderación de contenido."""
    if not request.text or len(request.text.strip()) == 0:
        raise HTTPException(status_code=400, detail="El texto a analizar no puede estar vacío.")

    raw_text = request.text.lower()
    words = re.findall(r'\b\w+\b', raw_text)
    
    pos_count = sum(1 for w in words if w in POSITIVE_WORDS)
    neg_count = sum(1 for w in words if w in NEGATIVE_WORDS)
    toxic_matches = [w for w in words if w in TOXIC_WORDS]

    total_sentiment_words = pos_count + neg_count
    if total_sentiment_words > 0:
        score = (pos_count - neg_count) / total_sentiment_words
    else:
        score = 0.0

    # Clasificación de Sentimiento
    if score > 0.2:
        sentiment = "POSITIVE"
    elif score < -0.2:
        sentiment = "NEGATIVE"
    else:
        sentiment = "NEUTRAL"

    # Extracción de etiquetas (#hashtags)
    tags = re.findall(r'#(\w+)', request.text)

    # Moderación y Decisión
    is_toxic = len(toxic_matches) > 0
    if is_toxic:
        status = "REJECTED"
        reason = f"Se detectaron términos de toxicidad u odio: {', '.join(toxic_matches)}"
    elif score < -0.6:
        status = "REJECTED"
        reason = "El contenido contiene una carga de sentimiento altamente negativo o destructivo."
    elif score < -0.2:
        status = "FLAGGED"
        reason = "Contenido con sentimiento negativo detectado."
    else:
        status = "APPROVED"
        reason = "Contenido verificado y aprobado por el modelo de IA."

    # Actualizar estadísticas en memoria
    stats["total_analyzed"] += 1
    if status == "APPROVED":
        stats["approved"] += 1
    elif status == "FLAGGED":
        stats["flagged"] += 1
    else:
        stats["rejected"] += 1

    return PostAnalysisResponse(
        status=status,
        sentiment=sentiment,
        sentiment_score=round(score, 2),
        is_toxic=is_toxic,
        confidence=0.95 if total_sentiment_words > 0 else 0.80,
        detected_tags=tags,
        moderation_reason=reason,
        analyzed_at=datetime.utcnow().isoformat()
    )

@app.get("/stats")
def get_stats():
    """Retorna métricas globales de análisis para monitoreo."""
    return stats
