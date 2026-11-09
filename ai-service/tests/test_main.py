"""Pruebas del microservicio de análisis de sentimiento y moderación."""

import pytest


def analyze(client, text, **extra):
    response = client.post("/analyze", json={"text": text, **extra})
    assert response.status_code == 200, response.text
    return response.json()


# --------------------------------------------------------------------------
# Endpoints de servicio
# --------------------------------------------------------------------------


def test_health_reports_up(client):
    response = client.get("/health")

    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "UP"
    assert body["service"] == "usn-ai-service"
    assert "stats" in body


def test_root_lists_endpoints(client):
    body = client.get("/").json()

    assert body["endpoints"] == {"health": "/health", "analyze": "/analyze", "stats": "/stats"}


# --------------------------------------------------------------------------
# Sentimiento y moderación
# --------------------------------------------------------------------------


def test_positive_text_is_approved(client):
    result = analyze(client, "Hoy fue un día excelente y feliz con mis amigos")

    assert result["sentiment"] == "POSITIVE"
    assert result["status"] == "APPROVED"
    assert result["sentiment_score"] == 1.0
    assert result["is_toxic"] is False
    assert result["confidence"] == 0.95


def test_neutral_text_without_sentiment_words(client):
    result = analyze(client, "Mañana publico el horario de la clase")

    assert result["sentiment"] == "NEUTRAL"
    assert result["status"] == "APPROVED"
    assert result["sentiment_score"] == 0.0
    # Sin palabras de sentimiento, la confianza es menor.
    assert result["confidence"] == 0.80


def test_mildly_negative_text_is_flagged(client):
    # 1 positiva y 2 negativas → score -0.33 (entre -0.6 y -0.2)
    result = analyze(client, "Bueno, pero fue un día triste y malo")

    assert result["sentiment"] == "NEGATIVE"
    assert result["status"] == "FLAGGED"
    assert result["sentiment_score"] == pytest.approx(-0.33, abs=0.01)


def test_strongly_negative_text_is_rejected(client):
    result = analyze(client, "Todo fue horrible, terrible y pésimo, un fracaso")

    assert result["sentiment"] == "NEGATIVE"
    assert result["status"] == "REJECTED"
    assert result["sentiment_score"] <= -0.6
    assert result["is_toxic"] is False


@pytest.mark.parametrize("text", ["Eres un idiota", "This is a SCAM", "qué estupidez"])
def test_toxic_text_is_rejected(client, text):
    result = analyze(client, text)

    assert result["is_toxic"] is True
    assert result["status"] == "REJECTED"
    assert "toxicidad" in result["moderation_reason"]


def test_toxicity_wins_over_positive_sentiment(client):
    result = analyze(client, "Excelente post, idiota")

    assert result["sentiment"] == "POSITIVE"
    assert result["status"] == "REJECTED"


def test_hashtags_are_extracted(client):
    result = analyze(client, "Genial evento #CloudComputing #UNSA en Arequipa")

    assert result["detected_tags"] == ["CloudComputing", "UNSA"]


def test_analysis_is_case_insensitive(client):
    assert analyze(client, "EXCELENTE")["sentiment"] == "POSITIVE"


# --------------------------------------------------------------------------
# Validación de entrada
# --------------------------------------------------------------------------


@pytest.mark.parametrize("text", ["", "   "])
def test_empty_text_returns_400(client, text):
    response = client.post("/analyze", json={"text": text})

    assert response.status_code == 400


def test_missing_text_returns_422(client):
    response = client.post("/analyze", json={"user_id": 1})

    assert response.status_code == 422


# --------------------------------------------------------------------------
# Estadísticas
# --------------------------------------------------------------------------


def test_stats_count_each_decision(client):
    analyze(client, "Qué día tan hermoso")  # APPROVED
    analyze(client, "Bueno, pero triste y malo")  # FLAGGED
    analyze(client, "Eres un idiota")  # REJECTED

    stats = client.get("/stats").json()

    assert stats == {"total_analyzed": 3, "approved": 1, "flagged": 1, "rejected": 1}
